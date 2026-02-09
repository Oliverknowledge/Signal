import SwiftUI
import Combine
import Foundation

// MARK: - Recall Session (guided flow, one question at a time)

struct RecallSessionView: View {
    let content: LearningContent
    @StateObject private var viewModel: RecallSessionViewModel
    @Environment(\.dismiss) private var dismiss

    init(content: LearningContent) {
        self.content = content
        _viewModel = StateObject(wrappedValue: RecallSessionViewModel(content: content))
    }

    var body: some View {
        ZStack {
            Theme.Colors.primaryBackground.ignoresSafeArea()

            if viewModel.questions.isEmpty {
                emptyRecallView
            } else if viewModel.phase == .context {
                contextStep
            } else if viewModel.phase == .question {
                questionStep
            } else if viewModel.phase == .feedback {
                feedbackStep
            } else {
                summaryStep
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Recall")
        .onDisappear {
            viewModel.handleViewDisappear()
        }
    }

    private var emptyRecallView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("No recall questions for this content.")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            SignalButton(title: "Done", style: .primary) {
                dismiss()
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step 1: Context
    private var contextStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text(sessionEstimateText)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)

            Text("Let's see what you remember")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: content.source == .youtube ? "play.rectangle.fill" : "doc.text.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Theme.Colors.primaryAccent)
                Text(content.title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.contentSurface)
            .cornerRadius(Theme.CornerRadius.md)

            Spacer()

            SignalButton(title: "Start", style: .primary) {
                viewModel.startQuestions()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Step 2: Question (one at a time)
    private var questionStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            progressIndicator
            Text(sessionEstimateText)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)

            if let q = viewModel.currentQuestion {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text(q.question)
                        .font(Theme.Typography.title3)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if q.type == .open {
                        openEndedInput
                    } else {
                        mcqOptions(question: q)
                    }
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.contentSurface)
                .cornerRadius(Theme.CornerRadius.md)
            }

            Spacer()

            submitButton
        }
        .padding(Theme.Spacing.md)
        .overlay {
            if viewModel.isGradingOpenEnded {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: Theme.Spacing.sm) {
                        ProgressView()
                            .tint(Theme.Colors.primaryAccent)
                        Text("Grading…")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Theme.Colors.contentSurface)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(radius: 8)
                }
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.totalQuestions)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
            Spacer()
        }
    }

    private var sessionEstimateText: String {
        let questionCount = max(viewModel.totalQuestions, 0)
        let minutes = max(1, Int(ceil(Double(questionCount) / 3.0)))
        let questionLabel = questionCount == 1 ? "question" : "questions"
        return "~\(minutes) min • \(questionCount) \(questionLabel)"
    }

    private var openEndedInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Short answer (1–3 sentences)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
            TextField("Type your answer...", text: $viewModel.openAnswer, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.md)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Your answer is sent for grading; avoid personal info.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
            if !viewModel.openAnswer.isEmpty && viewModel.openAnswer.count < 5 {
                Text("A bit more (at least 5 characters)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
    }

    private func mcqOptions(question: RecallQuestion) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array((question.options ?? []).enumerated()), id: \.offset) { index, option in
                Button {
                    viewModel.selectMCQOption(index: index)
                } label: {
                    HStack {
                        Text(option)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if viewModel.selectedMCQIndex == index {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.primaryAccent)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        viewModel.selectedMCQIndex == index
                            ? Theme.Colors.primaryAccent.opacity(0.1)
                            : Theme.Colors.secondaryBackground
                    )
                    .cornerRadius(Theme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(
                                viewModel.selectedMCQIndex == index ? Theme.Colors.primaryAccent : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var submitButton: some View {
        let canSubmit: Bool = {
            guard let q = viewModel.currentQuestion else { return false }
            if q.type == .open {
                return viewModel.openAnswer.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
            }
            return viewModel.selectedMCQIndex != nil
        }()
        return SignalButton(title: viewModel.isGradingOpenEnded ? "Grading…" : "Submit answer", style: .primary) {
            viewModel.submitAnswer()
        }
        .disabled(viewModel.isGradingOpenEnded || !canSubmit)
        .opacity((canSubmit && !viewModel.isGradingOpenEnded) ? 1 : 0.5)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: - Step 3: Feedback after each question
    private var feedbackStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "lightbulb.fill")
                .font(.system(size: 50))
                .foregroundColor(Theme.Colors.primaryAccent)

            if let isCorrect = viewModel.lastAnswerCorrect {
                Text(isCorrect ? "Correct" : "Not quite")
                    .font(Theme.Typography.headline)
                    .foregroundColor(isCorrect ? .green : .red)
            }
            
            if let score = viewModel.lastAnswerScore {
                Text("Grader estimate: \(viewModel.scoreOutOfTenText(score))/10")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
            
            if viewModel.lastAnswerCorrect == nil, viewModel.currentQuestion?.type == .open {
                Text("We couldn't grade this answer - keep going.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Text("Nice — here's the key idea")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)

            if let ref = viewModel.currentFeedbackText {
                Text(ref)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if !viewModel.lastCouldHaveSaid.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("What to add next time")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textPrimary)
                    ForEach(Array(viewModel.lastCouldHaveSaid.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
            }

            Spacer()

            SignalButton(title: "Next", style: .primary) {
                viewModel.advanceAfterFeedback()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Step 4: Session summary
    private var summaryStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("Completed")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.textPrimary)

            Text("You reviewed \(viewModel.totalAnswered) concepts")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Score: \(viewModel.totalCorrectCount)/\(max(viewModel.totalAnswered, 1))")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)

            Text("This strengthens memory through recall.")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Text("Do you want to see this again later?")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.md)

            HStack(spacing: Theme.Spacing.md) {
                SignalButton(title: "Remind me later", style: .primary) {
                    viewModel.scheduleAgainLater()
                    dismiss()
                }
                SignalButton(title: "Stop reminding (still saved)", style: .secondary) {
                    viewModel.reduceFrequency()
                    dismiss()
                }
            }
            .padding(.horizontal, Theme.Spacing.md)

            Spacer()
        }
        .padding(Theme.Spacing.md)
    }
}

// MARK: - ViewModel

enum RecallPhase {
    case context
    case question
    case feedback
    case summary
}

final class RecallSessionViewModel: ObservableObject {
    let content: LearningContent
    let questions: [RecallQuestion]
    private let traceId: UUID

    @Published var phase: RecallPhase = .context
    @Published var currentQuestionIndex: Int = 0
    @Published var openAnswer: String = ""
    @Published var selectedMCQIndex: Int?
    @Published var mcqCorrectCount: Int = 0
    @Published var openCorrectCount: Int = 0
    @Published var totalAnswered: Int = 0
    @Published var isGradingOpenEnded: Bool = false
    @Published private(set) var currentFeedbackTextStorage: String?

    @Published var lastAnswerCorrect: Bool? = nil
    @Published var lastAnswerRationale: String? = nil
    @Published var lastAnswerScore: Double? = nil
    @Published var lastCouldHaveSaid: [String] = []

    private var abandonmentRecorded = false
    private var completionFinalized = false

    var totalCorrectCount: Int { mcqCorrectCount + openCorrectCount }

    var totalQuestions: Int { questions.count }
    var currentQuestion: RecallQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    /// Shown after submitting an answer (key idea or reference).
    var currentFeedbackText: String? { currentFeedbackTextStorage }

    init(content: LearningContent) {
        self.content = content
        self.questions = content.recallQuestions ?? []
        self.traceId = content.traceId ?? UUID()
    }

    func startQuestions() {
        guard !questions.isEmpty else { return }
        phase = .question
        currentQuestionIndex = 0
        resetAnswerState()
    }

    func selectMCQOption(index: Int) {
        selectedMCQIndex = index
    }

    func submitAnswer() {
        guard let q = currentQuestion else { return }

        if q.type == .mcq {
            let idx = selectedMCQIndex
            let correctIdx = q.correctIndex
            let isCorrect = (idx != nil && correctIdx != nil && idx == correctIdx)
            if isCorrect {
                mcqCorrectCount += 1
            }
            lastAnswerCorrect = isCorrect
            lastAnswerRationale = nil
            lastCouldHaveSaid = []
            totalAnswered += 1
            currentFeedbackTextStorage = feedbackText(for: q)
            phase = .feedback
        } else {
            // Open-ended: grade via GradeRecallService
            let answer = openAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard answer.count >= 5 else { return }
            isGradingOpenEnded = true
            Task {
                if let (correct, score, reasoning, keyPoints, couldHaveSaid) = await GradeRecallService.shared.grade(
                    traceId: traceId,
                    contentId: content.id,
                    contentTitle: content.title,
                    question: q.question,
                    userAnswer: answer
                ) {
                    if correct {
                        await MainActor.run { openCorrectCount += 1 }
                    }
                    await MainActor.run {
                        lastAnswerCorrect = correct
                        lastAnswerRationale = reasoning
                        lastAnswerScore = score
                        lastCouldHaveSaid = couldHaveSaid.isEmpty ? keyPoints : couldHaveSaid
                    }
                } else {
                    await MainActor.run {
                        lastAnswerCorrect = nil
                        lastAnswerRationale = nil
                        lastAnswerScore = nil
                        lastCouldHaveSaid = []
                    }
                }
                await MainActor.run {
                    totalAnswered += 1
                    currentFeedbackTextStorage = feedbackText(for: q)
                    phase = .feedback
                    isGradingOpenEnded = false
                }
            }
        }
    }

    private func feedbackText(for q: RecallQuestion) -> String {
        if let rationale = lastAnswerRationale, !rationale.isEmpty {
            return rationale
        }
        if q.type == .mcq, let opts = q.options, let correctIdx = q.correctIndex, correctIdx < opts.count {
            return "Key idea: \(opts[correctIdx])"
        }
        return "Reflecting on this strengthens your understanding."
    }

    func advanceAfterFeedback() {
        lastAnswerCorrect = nil
        lastAnswerRationale = nil
        lastAnswerScore = nil
        lastCouldHaveSaid = []
        currentQuestionIndex += 1
        if currentQuestionIndex >= questions.count {
            phase = .summary
        } else {
            phase = .question
            resetAnswerState()
        }
    }

    private func resetAnswerState() {
        openAnswer = ""
        selectedMCQIndex = nil
        currentFeedbackTextStorage = nil
        lastAnswerCorrect = nil
        lastAnswerRationale = nil
        lastAnswerScore = nil
        lastCouldHaveSaid = []
    }

    private func submitRecallMetrics() {
        RecallSubmissionService.shared.submit(
            traceId: traceId,
            contentId: content.id,
            recallCorrect: totalCorrectCount,
            recallTotal: totalAnswered
        )
    }

    func scheduleAgainLater() {
        finalizeCompletionIfNeeded()
        guard !RecallSessionStore.shared.isMuted(contentId: content.id) else { return }
        RecallSessionStore.shared.scheduleAgain(contentId: content.id)
        let fireDate = tomorrowSameTime(from: Date())
        ScheduledRecallStore.shared.add(contentId: content.id, contentTitle: content.title, fireDate: fireDate)
        let delay = max(1, fireDate.timeIntervalSinceNow)
        Task {
            await NotificationManager.shared.scheduleRecallReminder(
                contentTitle: content.title,
                contentId: content.id,
                delay: delay
            )
        }
    }

    func reduceFrequency() {
        finalizeCompletionIfNeeded()
        RecallSessionStore.shared.recordReduceFrequency(contentId: content.id)
        ScheduledRecallStore.shared.remove(contentId: content.id)
        NotificationManager.shared.cancelRecallNotifications(contentId: content.id)
    }

    func handleViewDisappear() {
        if phase == .summary {
            finalizeCompletionIfNeeded()
            return
        }
        recordAbandonmentIfNeeded()
    }

    func scoreOutOfTenText(_ score: Double) -> String {
        let outOfTen = Int((max(0, min(1, score)) * 10).rounded())
        return "\(outOfTen)"
    }

    private func tomorrowSameTime(from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(24 * 3600)
    }

    private func finalizeCompletionIfNeeded() {
        guard !completionFinalized else { return }
        completionFinalized = true
        submitRecallMetrics()
        ContentStore.shared.recordRecallOutcome(contentId: content.id, correct: totalCorrectCount, total: totalAnswered)
        let mcqTotal = questions.filter { $0.type == .mcq }.count
        RecallSessionStore.shared.recordCompletion(
            contentId: content.id,
            recallCorrect: totalCorrectCount,
            total: totalAnswered,
            mcqCorrect: mcqCorrectCount,
            mcqTotal: mcqTotal
        )
        ScheduledRecallStore.shared.remove(contentId: content.id)
    }

    private func recordAbandonmentIfNeeded() {
        guard phase != .summary, phase != .context, !abandonmentRecorded else { return }
        guard !RecallSessionStore.shared.isMuted(contentId: content.id) else { return }
        abandonmentRecorded = true
        RecallSessionStore.shared.recordAbandonment(contentId: content.id, atIndex: currentQuestionIndex)
        let delay: TimeInterval = 2 * 3600
        let fireDate = Date().addingTimeInterval(delay)
        ScheduledRecallStore.shared.add(contentId: content.id, contentTitle: content.title, fireDate: fireDate)
    }
}

// MARK: - Store for learning behavior rules

extension Notification.Name {
    static let recallMetricsDidChange = Notification.Name("signal.recallMetricsDidChange")
}

struct WeeklySessionPoint: Identifiable {
    let date: Date
    let dayLabel: String
    let sessions: Int

    var id: String {
        let day = Calendar.current.startOfDay(for: date)
        return String(Int(day.timeIntervalSince1970))
    }
}

struct WeeklyRecallSummary {
    let points: [WeeklySessionPoint]
    let averageSessionsPerDay: Double
    let totalSessions: Int
    let mcqCorrect: Int
    let mcqTotal: Int
    let mcqAccuracy: Double
}

private struct RecallSessionHistoryEntry: Codable {
    let id: String
    let contentId: String
    let timestamp: Date
    let recallCorrect: Int
    let recallTotal: Int
    let mcqCorrect: Int
    let mcqTotal: Int
}

final class RecallSessionStore: ObservableObject {
    static let shared = RecallSessionStore()
    private let abandonKey = "signal.recall.abandoned"
    private let completedKey = "signal.recall.completed"
    private let reduceFreqKey = "signal.recall.reduceFreq"
    private let scheduleAgainKey = "signal.recall.scheduleAgain"
    private let mutedKey = "signal.recall.muted"
    private let sessionHistoryKey = "signal.recall.sessionHistory"
    private let sessionHistoryMaxAgeDays = 120

    private init() {}

    func recordAbandonment(contentId: UUID, atIndex: Int) {
        var dict = (UserDefaults.standard.dictionary(forKey: abandonKey) as? [String: Int]) ?? [:]
        dict[contentId.uuidString] = atIndex
        UserDefaults.standard.set(dict, forKey: abandonKey)
        objectWillChange.send()
    }

    func recordCompletion(contentId: UUID, recallCorrect: Int, total: Int, mcqCorrect: Int = 0, mcqTotal: Int = 0) {
        var dict = (UserDefaults.standard.dictionary(forKey: completedKey) as? [String: [Int]]) ?? [:]
        dict[contentId.uuidString] = [recallCorrect, total]
        UserDefaults.standard.set(dict, forKey: completedKey)

        var history = loadSessionHistory()
        history.append(
            RecallSessionHistoryEntry(
                id: UUID().uuidString,
                contentId: contentId.uuidString,
                timestamp: Date(),
                recallCorrect: max(0, recallCorrect),
                recallTotal: max(0, total),
                mcqCorrect: max(0, mcqCorrect),
                mcqTotal: max(0, mcqTotal)
            )
        )
        history = pruneOldHistory(history)
        saveSessionHistory(history)

        StreakStore.shared.recordActivity()
        NotificationCenter.default.post(name: .recallMetricsDidChange, object: nil)
        objectWillChange.send()
    }

    func scheduleAgain(contentId: UUID) {
        var set = (UserDefaults.standard.array(forKey: scheduleAgainKey) as? [String]) ?? []
        if !set.contains(contentId.uuidString) { set.append(contentId.uuidString) }
        UserDefaults.standard.set(set, forKey: scheduleAgainKey)
        objectWillChange.send()
    }

    func recordReduceFrequency(contentId: UUID) {
        var set = (UserDefaults.standard.array(forKey: reduceFreqKey) as? [String]) ?? []
        if !set.contains(contentId.uuidString) { set.append(contentId.uuidString) }
        UserDefaults.standard.set(set, forKey: reduceFreqKey)
        objectWillChange.send()
    }

    func mute(contentId: UUID) {
        var set = (UserDefaults.standard.array(forKey: mutedKey) as? [String]) ?? []
        if !set.contains(contentId.uuidString) { set.append(contentId.uuidString) }
        UserDefaults.standard.set(set, forKey: mutedKey)
        objectWillChange.send()
    }

    func unmute(contentId: UUID) {
        var set = (UserDefaults.standard.array(forKey: mutedKey) as? [String]) ?? []
        set.removeAll { $0 == contentId.uuidString }
        UserDefaults.standard.set(set, forKey: mutedKey)
        objectWillChange.send()
    }

    func hasPendingRecall(contentId: UUID) -> Bool {
        guard !isMuted(contentId: contentId) else { return false }
        return (ContentStore.shared.all().first { $0.id == contentId })?.recallQuestions != nil
    }

    func recallOutcome(contentId: UUID) -> (correct: Int, total: Int)? {
        guard let arr = (UserDefaults.standard.dictionary(forKey: completedKey) as? [String: [Int]])?[contentId.uuidString], arr.count >= 2 else { return nil }
        return (arr[0], arr[1])
    }

    func isCompleted(contentId: UUID) -> Bool {
        (UserDefaults.standard.dictionary(forKey: completedKey) as? [String: [Int]])?[contentId.uuidString] != nil
    }

    func hasReducedFrequency(contentId: UUID) -> Bool {
        (UserDefaults.standard.array(forKey: reduceFreqKey) as? [String])?.contains(contentId.uuidString) ?? false
    }

    func isMuted(contentId: UUID) -> Bool {
        if (UserDefaults.standard.array(forKey: mutedKey) as? [String])?.contains(contentId.uuidString) == true {
            return true
        }
        return ContentStore.shared.isMuted(contentId: contentId)
    }

    /// Aggregate recall stats for Insights (total sessions, total correct, total questions).
    func recallAggregate() -> (sessions: Int, correct: Int, total: Int) {
        let history = loadSessionHistory()
        if !history.isEmpty {
            let sessions = history.count
            let correct = history.reduce(0) { $0 + max(0, $1.recallCorrect) }
            let total = history.reduce(0) { $0 + max(0, $1.recallTotal) }
            return (sessions, correct, total)
        }

        guard let dict = UserDefaults.standard.dictionary(forKey: completedKey) as? [String: [Int]] else {
            return (0, 0, 0)
        }
        var sessions = 0
        var correct = 0
        var total = 0
        for (_, arr) in dict where arr.count >= 2 {
            sessions += 1
            correct += arr[0]
            total += arr[1]
        }
        return (sessions, correct, total)
    }

    func weeklySummary(referenceDate: Date = Date()) -> WeeklyRecallSummary {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: referenceDate)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) else {
            return WeeklyRecallSummary(
                points: [],
                averageSessionsPerDay: 0,
                totalSessions: 0,
                mcqCorrect: 0,
                mcqTotal: 0,
                mcqAccuracy: 0
            )
        }

        var dayCounts: [Date: Int] = [:]
        for offset in 0...6 {
            if let day = calendar.date(byAdding: .day, value: offset, to: weekStart) {
                dayCounts[calendar.startOfDay(for: day)] = 0
            }
        }

        var totalSessions = 0
        var mcqCorrect = 0
        var mcqTotal = 0

        for entry in loadSessionHistory() {
            let day = calendar.startOfDay(for: entry.timestamp)
            guard day >= weekStart && day <= todayStart else { continue }
            dayCounts[day, default: 0] += 1
            totalSessions += 1
            mcqCorrect += max(0, entry.mcqCorrect)
            mcqTotal += max(0, entry.mcqTotal)
        }

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale.current
        dayFormatter.setLocalizedDateFormatFromTemplate("EEE")

        let points: [WeeklySessionPoint] = (0...6).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let normalizedDay = calendar.startOfDay(for: day)
            let label = String(dayFormatter.string(from: normalizedDay).prefix(3))
            return WeeklySessionPoint(
                date: normalizedDay,
                dayLabel: label,
                sessions: dayCounts[normalizedDay, default: 0]
            )
        }

        let averagePerDay = Double(totalSessions) / 7.0
        let mcqAccuracy = mcqTotal > 0 ? Double(mcqCorrect) / Double(mcqTotal) : 0

        return WeeklyRecallSummary(
            points: points,
            averageSessionsPerDay: averagePerDay,
            totalSessions: totalSessions,
            mcqCorrect: mcqCorrect,
            mcqTotal: mcqTotal,
            mcqAccuracy: mcqAccuracy
        )
    }

    private func loadSessionHistory() -> [RecallSessionHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: sessionHistoryKey) else { return [] }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([RecallSessionHistoryEntry].self, from: data) {
            return decoded
        }
        return []
    }

    private func saveSessionHistory(_ history: [RecallSessionHistoryEntry]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(history) {
            UserDefaults.standard.set(data, forKey: sessionHistoryKey)
        }
    }

    private func pruneOldHistory(_ history: [RecallSessionHistoryEntry]) -> [RecallSessionHistoryEntry] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -sessionHistoryMaxAgeDays, to: Date()) else {
            return history
        }
        return history.filter { $0.timestamp >= cutoff }
    }
}

#Preview {
    NavigationView {
        RecallSessionView(content: LearningContent(
            url: "https://youtube.com/watch?v=abc",
            title: "Understanding Smart Pointers",
            source: .youtube,
            analysisStatus: .completed,
            recallQuestions: [
                RecallQuestion(question: "What is the main benefit of smart pointers?", type: .mcq, options: ["Faster", "Automatic memory management", "Smaller binary", "Syntax"], correctIndex: 1),
                RecallQuestion(question: "Explain one pitfall of raw pointers.", type: .open)
            ]
        ))
    }
}
