import SwiftUI
import Combine

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @EnvironmentObject var captureCoordinator: GlobalCaptureCoordinator
    @ObservedObject private var contentStore = ContentStore.shared

    private var linkedContent: [LearningContent] {
        contentStore.contents.sorted { $0.dateShared > $1.dateShared }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Key Metrics
                        keyMetrics

                        // Learning Insights
                        learningInsights

                        // Content Reviews
                        contentReviews
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    GlobalCaptureToolbarButton()
                }
            }
            .onAppear { viewModel.loadFromStores() }
        }
    }

    private var keyMetrics: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Key Metrics")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)
            
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    MetricCard(title: "Triggered", value: "\(viewModel.interventionsTriggered)")
                    MetricCard(title: "Ignored", value: "\(viewModel.belowThreshold)")
                }
                
                HStack {
                    MetricCard(title: "Recall Accuracy", value: "\(Int(viewModel.successRate * 100))%")
                    MetricCard(title: "Current Streak", value: "\(viewModel.currentStreak)d")
                }
            }
        }
    }
    
    private var learningInsights: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Key Insights")
            .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)
            
            if viewModel.insights.isEmpty {
                Text("No insights yet. Analyze content to see trends.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textPrimary)
                    .padding(Theme.Spacing.md)
                    .background(Palette.card)
                    .cornerRadius(Theme.CornerRadius.md)
            } else {
                ForEach(viewModel.insights, id: \.self) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }

    private var contentReviews: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Content Reviews")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)

            if linkedContent.isEmpty {
                Text("No linked content yet.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textPrimary)
                    .padding(Theme.Spacing.md)
                    .background(Palette.card)
                    .cornerRadius(Theme.CornerRadius.md)
            } else {
                ForEach(linkedContent) { content in
                    NavigationLink(destination: ContentDetailView(content: content)) {
                        ContentReviewRow(content: content)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
}

struct MetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Palette.textSecondary)
            
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(value)
                    .font(Theme.Typography.title2)
                    .foregroundColor(Palette.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

struct InsightCard: View {
    let insight: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Palette.primary)
            
            Text(insight)
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

private struct ContentReviewRow: View {
    let content: LearningContent

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: content.source == .youtube ? "play.rectangle.fill" : "doc.text.fill")
                    .font(.title3)
                    .foregroundColor(Palette.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(content.source.rawValue)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                    Text(timeAgo(from: content.dateShared))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Palette.textSecondary)
            }

            Text(displayTitle)
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)
                .lineLimit(2)

            Text(content.url)
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private var displayTitle: String {
        let raw = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw.caseInsensitiveCompare("Shared Link") == .orderedSame {
            return content.source == .youtube ? "YouTube Video" : "Web Article"
        }
        return raw
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m ago"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))h ago"
        } else {
            return "\(Int(seconds / 86400))d ago"
        }
    }
}

class InsightsViewModel: ObservableObject {
    @Published var successRate: Double = 0.0
    @Published var currentStreak: Int = 0

    @Published var interventionsTriggered: Int = 0
    @Published var totalContentAnalyzed: Int = 0
    @Published var falsePositives: Int = 0
    @Published var belowThreshold: Int = 0

    @Published var insights: [String] = []

    init() {
        loadFromStores()
    }

    func loadFromStores() {
        let stats = ObservabilityStore.shared.stats()
        let contentCounts = contentDecisionCounts()

        totalContentAnalyzed = contentCounts.total
        interventionsTriggered = contentCounts.triggered
        falsePositives = stats.falsePositives
        belowThreshold = contentCounts.ignored

        let recall = RecallSessionStore.shared.recallAggregate()
        currentStreak = StreakStore.shared.currentStreak
        if recall.total > 0 {
            successRate = Double(recall.correct) / Double(recall.total)
        }

        var lines: [String] = []
        if interventionsTriggered > 0 {
            lines.append("Signal triggered \(interventionsTriggered) recall session\(interventionsTriggered == 1 ? "" : "s") from content that aligned with your goal.")
        }
        if recall.sessions > 0 && recall.total > 0 {
            let pct = Int((Double(recall.correct) / Double(recall.total)) * 100)
            lines.append("You completed \(recall.sessions) recall session\(recall.sessions == 1 ? "" : "s") with \(pct)% correct on MCQs.")
        }
        if falsePositives > 0 {
            lines.append("You marked \(falsePositives) intervention\(falsePositives == 1 ? "" : "s") as not useful — we use this to improve relevance.")
        }
        insights = lines.isEmpty ? [] : lines
    }

    private func contentDecisionCounts() -> (total: Int, triggered: Int, ignored: Int) {
        let contents = ContentStore.shared.all()
        let triggered = contents.filter { $0.analysisStatus == .completed }.count
        let ignored = contents.filter { $0.analysisStatus == .belowThreshold }.count
        return (contents.count, triggered, ignored)
    }
}

#Preview {
    InsightsView()
        .environmentObject(GlobalCaptureCoordinator())
}
