import SwiftUI
import Combine
import UserNotifications
import BackgroundTasks

@main
struct SignalApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .accentColor(Palette.primary)
                .environmentObject(appState)
                .onAppear {
                    AppStorage.syncToAppGroup()
                    PendingAnalysisManager.shared.drainPending(appState: appState)
                    #if DEBUG
                    print("[PendingAnalysis] Queue count on appear: \(PendingAnalysisManager.shared.pendingQueueCount())")
                    #endif
                    BackgroundTaskManager.shared.register(appState: appState)
                    BackgroundTaskManager.shared.scheduleAppRefresh()
                    BackgroundTaskManager.shared.scheduleProcessing()
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                    Task { _ = await NotificationManager.shared.ensureAuthorization() }
                    appState.refreshLearningGoalProgress()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        if let uuid = NotificationDelegate.consumePendingRecallContentId() {
                            appState.pendingRecallContentId = uuid
                        }
                        if let eventId = NotificationDelegate.consumePendingPrepEventId() {
                            appState.pendingPrepEventId = eventId
                        }
                        PendingAnalysisManager.shared.drainPending(appState: appState)
                        #if DEBUG
                        print("[PendingAnalysis] Queue count on active: \(PendingAnalysisManager.shared.pendingQueueCount())")
                        #endif
                        appState.refreshLearningGoalProgress()
                        BackgroundTaskManager.shared.scheduleAppRefresh(earliestBegin: 15 * 60)
                        BackgroundTaskManager.shared.scheduleProcessing()
                    } else if newPhase == .background {
                        BackgroundTaskManager.shared.scheduleAppRefresh(earliestBegin: 15 * 60)
                        BackgroundTaskManager.shared.scheduleProcessing()
                    }
                }
        }
    }
}

class AppState: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var learningMode: LearningMode = .generalLearning
    @Published var learningGoals: [LearningGoal] = [] {
        didSet { AppStorage.learningGoals = learningGoals }
    }
    @Published var prepEvents: [PrepEvent] = [] {
        didSet {
            AppStorage.prepEvents = prepEvents
            Task { await NotificationManager.shared.reschedulePrepEventNotifications(events: prepEvents) }
        }
    }
    /// Set when user taps a recall notification; main tab presents recall sheet and clears when dismissed.
    @Published var pendingRecallContentId: UUID?
    /// Set when user taps a prep event notification; main tab presents event sheet and clears when dismissed.
    @Published var pendingPrepEventId: UUID?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        learningMode = LearningMode.fromStored(AppStorage.learningModeRaw)
        learningGoals = AppStorage.learningGoals
        prepEvents = AppStorage.prepEvents
        Task { await NotificationManager.shared.reschedulePrepEventNotifications(events: prepEvents) }
        bindProgressUpdates()

        if learningGoals.isEmpty, let fallback = fallbackGoalTitle() {
            learningGoals = [LearningGoal(title: fallback, targetDate: Date())]
        }
        refreshLearningGoalProgress()
    }

    func addGoal(_ goal: LearningGoal) {
        learningGoals.append(goal)
        refreshLearningGoalProgress()
    }

    func updateGoal(_ goal: LearningGoal) {
        guard let idx = learningGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        learningGoals[idx] = goal
        refreshLearningGoalProgress()
    }

    @discardableResult
    func removeGoal(id: UUID) -> LearningGoal? {
        guard let idx = learningGoals.firstIndex(where: { $0.id == id }) else { return nil }
        return learningGoals.remove(at: idx)
    }

    func replaceGoals(_ goals: [LearningGoal]) {
        learningGoals = goals
        refreshLearningGoalProgress()
    }

    func addPrepEvent(_ event: PrepEvent) {
        if AppStorage.goalCalendarSyncEnabled {
            Task { @MainActor in
                let synced = await CalendarManager.shared.syncPrepEventIfAuthorized(event)
                prepEvents.append(synced)
            }
        } else {
            prepEvents.append(event)
        }
    }

    func updatePrepEvent(_ event: PrepEvent) {
        guard let idx = prepEvents.firstIndex(where: { $0.id == event.id }) else { return }
        if AppStorage.goalCalendarSyncEnabled {
            Task { @MainActor in
                let synced = await CalendarManager.shared.syncPrepEventIfAuthorized(event)
                prepEvents[idx] = synced
            }
        } else {
            prepEvents[idx] = event
        }
    }

    @discardableResult
    func removePrepEvent(id: UUID) -> PrepEvent? {
        guard let idx = prepEvents.firstIndex(where: { $0.id == id }) else { return nil }
        let event = prepEvents.remove(at: idx)
        if AppStorage.goalCalendarSyncEnabled {
            Task { @MainActor in
                await CalendarManager.shared.removePrepEventIfAuthorized(event)
            }
        }
        return event
    }

    func replacePrepEvents(_ events: [PrepEvent]) {
        prepEvents = events
    }

    private func fallbackGoalTitle() -> String? {
        if let title = AppStorage.selectedGoalTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        if let description = AppStorage.selectedGoalDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return description.components(separatedBy: ".").first ?? description
        }
        return nil
    }

    func refreshLearningGoalProgress(referenceDate: Date = Date()) {
        guard !learningGoals.isEmpty else { return }
        let summary = RecallSessionStore.shared.weeklySummary(referenceDate: referenceDate)
        var hasChange = false

        let refreshed = learningGoals.map { goal -> LearningGoal in
            var updated = goal
            let computed = measuredProgress(for: goal, summary: summary, referenceDate: referenceDate)
            let monotonic = max(goal.progress, computed)
            if abs(monotonic - goal.progress) > 0.001 {
                updated.progress = monotonic
                hasChange = true
            }
            return updated
        }

        if hasChange {
            learningGoals = refreshed
        }
    }

    private func bindProgressUpdates() {
        NotificationCenter.default.publisher(for: .recallMetricsDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLearningGoalProgress()
            }
            .store(in: &cancellables)
    }

    private func measuredProgress(
        for goal: LearningGoal,
        summary: WeeklyRecallSummary,
        referenceDate: Date
    ) -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: goal.targetDate)
        let now = calendar.startOfDay(for: referenceDate)
        let elapsedDays = max(0, calendar.dateComponents([.day], from: start, to: now).day ?? 0)

        let timeScore = min(Double(elapsedDays) / 84.0, 1.0) * 0.2
        let sessionScore = min(summary.averageSessionsPerDay / 1.0, 1.0) * 0.45
        let mcqStandard: Double = 0.8
        let accuracyScore = min(summary.mcqAccuracy / mcqStandard, 1.0) * 0.35

        return min(1.0, max(0.0, timeScore + sessionScore + accuracyScore))
    }
}

enum LearningMode: String, CaseIterable {
    case interviewPrep = "Interview Prep"
    case assessmentExamPrep = "Assessment / Exam Prep"
    case generalLearning = "General Learning"
    
    var description: String {
        switch self {
        case .interviewPrep:
            return "Open-ended explanations under pressure"
        case .assessmentExamPrep:
            return "MCQ-heavy recall with clear right/wrong checks"
        case .generalLearning:
            return "Balanced, lower-pressure practice"
        }
    }

    var apiValue: String {
        switch self {
        case .interviewPrep:
            return "interview_prep"
        case .assessmentExamPrep:
            return "assessment_exam_prep"
        case .generalLearning:
            return "general_learning"
        }
    }

    static func fromStored(_ raw: String?) -> LearningMode {
        guard let raw else { return .generalLearning }
        if let direct = LearningMode(rawValue: raw) {
            return direct
        }

        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")

        switch normalized {
        case "interview_prep", "interview":
            return .interviewPrep
        case "assessment_exam_prep", "assessment_prep", "assessment", "exam_prep", "exam":
            return .assessmentExamPrep
        case "general_learning", "general", "casual":
            return .generalLearning
        case "deep_focus", "deepfocus":
            // Legacy mode maps to the closest current behavior.
            return .interviewPrep
        default:
            return .generalLearning
        }
    }
}
