import SwiftUI

struct HomeView: View {
    @State private var showingPractice = false
    @State private var showingPrepEventsList = false
    @State private var selectedPrepEvent: PrepEvent? = nil

    @EnvironmentObject var appState: AppState
    @ObservedObject private var store = ContentStore.shared
    @ObservedObject private var streakStore = StreakStore.shared
    @ObservedObject private var recallStore = RecallSessionStore.shared

    private enum ActionContext {
        case eventFocused(PrepEvent)
        case readiness
    }

    private var allConcepts: [Concept] {
        var merged: [String: Concept] = [:]

        for concept in store.contents.flatMap(\.concepts) {
            let key = concept.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }

            if var existing = merged[key] {
                existing.totalRecallAttempts += concept.totalRecallAttempts
                existing.successfulRecalls += concept.successfulRecalls
                existing.lastRecallDate = [existing.lastRecallDate, concept.lastRecallDate]
                    .compactMap { $0 }
                    .max()

                if existing.totalRecallAttempts > 0 {
                    existing.masteryLevel = Double(existing.successfulRecalls) / Double(existing.totalRecallAttempts)
                } else {
                    existing.masteryLevel = max(existing.masteryLevel, concept.masteryLevel)
                }
                merged[key] = existing
            } else {
                merged[key] = concept
            }
        }

        return Array(merged.values)
    }

    private var futurePrepEvents: [PrepEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return appState.prepEvents
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
    }

    private var nextPrepEvent: PrepEvent? {
        futurePrepEvents.first
    }

    private var actionContext: ActionContext {
        if let event = nextPrepEvent {
            return .eventFocused(event)
        }
        return .readiness
    }

    private var recallCandidates: [LearningContent] {
        store.contents.filter { content in
            guard let qs = content.recallQuestions, !qs.isEmpty else { return false }
            if recallStore.isMuted(contentId: content.id) { return false }
            if recallStore.isCompleted(contentId: content.id) { return false }
            return !recallStore.hasReducedFrequency(contentId: content.id)
        }
    }

    private var prioritizedRecallContent: [LearningContent] {
        switch actionContext {
        case .eventFocused(let event):
            return recallCandidates.sorted { lhs, rhs in
                let leftScore = eventAlignmentScore(content: lhs, event: event)
                let rightScore = eventAlignmentScore(content: rhs, event: event)
                if leftScore != rightScore { return leftScore > rightScore }
                return lhs.dateShared > rhs.dateShared
            }
        case .readiness:
            return recallCandidates.sorted { $0.dateShared > $1.dateShared }
        }
    }

    private var nextUpItems: [LearningContent] {
        Array(prioritizedRecallContent.prefix(5))
    }

    private var totalConcepts: Int {
        allConcepts.count
    }

    private var averageMastery: Double {
        let conceptsWithMastery = allConcepts.filter { $0.totalRecallAttempts > 0 || $0.masteryLevel > 0 }
        guard !conceptsWithMastery.isEmpty else { return 0 }
        let weighted = conceptsWithMastery.reduce((score: 0.0, weight: 0.0)) { partial, concept in
            let weight = concept.difficulty.masteryWeight
            return (
                score: partial.score + (concept.masteryLevel * weight),
                weight: partial.weight + weight
            )
        }
        guard weighted.weight > 0 else { return 0 }
        return weighted.score / weighted.weight
    }

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        orientationLayer
                        progressLayer
                        actionLayer
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(Palette.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    GlobalCaptureToolbarButton()
                }
            }
        }
        .sheet(item: $selectedPrepEvent) { event in
            EventPrepView(event: event)
        }
        .sheet(isPresented: $showingPractice) {
            RecallView()
        }
        .sheet(isPresented: $showingPrepEventsList) {
            PrepEventsView()
        }
    }

    private var orientationLayer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .center) {
                Text(nextPrepEvent == nil ? "Goal-driven readiness" : "Nearest upcoming event")
                    .font(nextPrepEvent == nil ? Theme.Typography.title3 : Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)

                Spacer()

                Button {
                    showingPrepEventsList = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("Upcoming")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Palette.primary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Palette.primary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let event = nextPrepEvent {
                Text(event.countdownLabel())
                    .font(Theme.Typography.title2)
                    .foregroundColor(Palette.textPrimary)

                if let subtitle = eventSecondaryLine(for: event) {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                        .lineLimit(1)
                }

                Text(microPlanLine())
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)

                PrimaryButton(title: "Start preparation") {
                    selectedPrepEvent = event
                }
            } else {
                Text(goalSupportCopy())
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(3)

                Text(microPlanLine())
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)

                PrimaryButton(title: "Practice / Review") {
                    showingPractice = true
                }

                Button("Add event") {
                    showingPrepEventsList = true
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Palette.primary)
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private var actionLayer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Next up")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)

            if nextUpItems.isEmpty {
                Text("No recall actions right now.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.card)
                .cornerRadius(Theme.CornerRadius.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(nextUpItems.enumerated()), id: \.element.id) { index, item in
                        nextUpRow(for: item)
                        if index < nextUpItems.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Palette.card)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
    }

    @ViewBuilder
    private func nextUpRow(for content: LearningContent) -> some View {
        NavigationLink(destination: RecallSessionView(content: content)) {
            nextUpRowLayout(
                icon: "brain.head.profile",
                title: reviewTitle(for: content),
                subtitle: "Recall • \(primaryTopic(for: content))"
            )
        }
        .buttonStyle(.plain)
    }

    private func nextUpRowLayout(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Palette.primary)
                .frame(width: 32, height: 32)
                .background(Palette.primary.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Palette.textSecondary)
        }
        .padding(Theme.Spacing.md)
    }

    private var progressLayer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Progress")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)

            HStack(spacing: Theme.Spacing.sm) {
                NavigationLink(destination: ConceptExplorerView()) {
                    HomeStatCard(
                        title: "Concepts",
                        value: "\(totalConcepts)",
                        icon: "lightbulb.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ConceptExplorerView()) {
                    HomeStatCard(
                        title: "Mastery",
                        value: "\(Int(averageMastery * 100))%",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                .buttonStyle(.plain)

                HomeStatCard(
                    title: "Streak",
                    value: "\(streakStore.currentStreak)d",
                    icon: "flame.fill"
                )
            }
        }
    }

    private func microPlanLine() -> String {
        let recallCount = nextUpItems.count
        if recallCount == 0 {
            return nextPrepEvent == nil ? "Today: one quick readiness check." : "Today: start preparation."
        }
        return "Today: \(recallCount) recall\(recallCount == 1 ? "" : "s")"
    }

    private func eventAlignmentScore(content: LearningContent, event: PrepEvent) -> Int {
        let keywords = prepKeywords(for: event)
        guard !keywords.isEmpty else { return 0 }
        let normalized = "\(content.title) \(content.concepts.map(\.name).joined(separator: " "))".lowercased()
        return keywords.reduce(0) { partial, keyword in
            partial + (normalized.contains(keyword) ? 1 : 0)
        }
    }

    private func prepKeywords(for event: PrepEvent) -> [String] {
        [
            event.metadata.company,
            event.metadata.role,
            event.metadata.examType,
            event.metadata.domain
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
    }

    private func eventSecondaryLine(for event: PrepEvent) -> String? {
        var parts: [String] = []
        if let company = event.metadata.company, !company.isEmpty {
            parts.append(company)
        }
        if let role = event.metadata.role, !role.isEmpty {
            parts.append(role)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func goalSupportCopy() -> String {
        if let description = AppStorage.selectedGoalDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return "\(description) Use recall and review to maintain readiness while you wait."
        }
        return "Use recall and review to maintain readiness."
    }

    private func primaryTopic(for content: LearningContent) -> String {
        let topics = content.concepts
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return topics.first ?? "General"
    }

    private func reviewTitle(for content: LearningContent) -> String {
        let topic = primaryTopic(for: content)
        if topic.caseInsensitiveCompare("General") != .orderedSame {
            return topic
        }

        let raw = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.caseInsensitiveCompare("YouTube Video") == .orderedSame ||
            raw.caseInsensitiveCompare("Shared Link") == .orderedSame ||
            isDomainLike(raw) {
            return "Review"
        }
        return raw
    }

    private func isDomainLike(_ value: String) -> Bool {
        let candidate = value.lowercased().replacingOccurrences(of: "www.", with: "")
        let pattern = "^[a-z0-9-]+(\\.[a-z0-9-]+)+$"
        return candidate.range(of: pattern, options: .regularExpression) != nil
    }
}

private struct HomeStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Palette.primary)

            Text(value)
                .font(Theme.Typography.title2)
                .foregroundColor(Palette.textPrimary)
                .fontWeight(.semibold)

            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

struct ContentCard: View {
    let content: LearningContent

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: content.source == .youtube ? "play.rectangle.fill" : "doc.text.fill")
                    .foregroundColor(Palette.primary)

                Text(content.source.rawValue)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Palette.textSecondary)

                Spacer()

                StatusBadge(status: content.analysisStatus)
            }

            Text(content.title)
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textPrimary)
                .lineLimit(2)

            if content.analysisStatus == .belowThreshold {
                Text(ignoredSummaryText(relevance: content.relevanceScore, learningValue: content.learningValue))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(2)
            }

            if content.analysisStatus == .completed {
                HStack {
                    ScoreIndicator(label: "Relevance", score: content.relevanceScore)
                    Spacer()
                    ScoreIndicator(label: "Learning Value", score: content.learningValue)
                }
            }

            if !content.concepts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(content.concepts.prefix(3)) { concept in
                            ConceptTag(name: concept.name)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private func ignoredSummaryText(relevance: Double, learningValue: Double) -> String {
        guard relevance > 0, learningValue > 0 else {
            return "Ignored - saved to review later"
        }
        let relevancePercent = Int((relevance * 100).rounded())
        let learningPercent = Int((learningValue * 100).rounded())
        return "Ignored: \(relevancePercent)% relevance / \(learningPercent)% learning depth (\(policyTitle())) - Saved anyway."
    }

    private func policyTitle() -> String {
        let policy = AppStorage.interventionPolicy.lowercased()
        return (policy == "aggressive") ? "Aggressive" : "Focused"
    }
}

struct StatusBadge: View {
    let status: AnalysisStatus

    var body: some View {
        Text(status.rawValue)
            .font(Theme.Typography.caption)
            .foregroundColor(statusColor)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(statusColor.opacity(0.1))
            .cornerRadius(Theme.CornerRadius.sm)
    }

    private var statusColor: Color {
        Palette.primary
    }
}

struct ScoreIndicator: View {
    let label: String
    let score: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Palette.textSecondary)

            Text("\(Int(score * 100))%")
                .font(Theme.Typography.callout)
                .foregroundColor(scoreColor)
                .fontWeight(.semibold)
        }
    }

    private var scoreColor: Color {
        Palette.primary
    }
}

struct ConceptTag: View {
    let name: String

    var body: some View {
        Text(name)
            .font(Theme.Typography.caption)
            .foregroundColor(Palette.textPrimary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Palette.primary.opacity(0.1))
            .cornerRadius(Theme.CornerRadius.sm)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
