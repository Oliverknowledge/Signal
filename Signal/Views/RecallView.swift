import SwiftUI

/// Recall hub: content with pending recall questions, scheduled sessions, and quick access to do recall.
struct RecallView: View {
    @EnvironmentObject var captureCoordinator: GlobalCaptureCoordinator
    @ObservedObject private var contentStore = ContentStore.shared
    @ObservedObject private var scheduledStore = ScheduledRecallStore.shared
    @ObservedObject private var recallStore = RecallSessionStore.shared
    
    private var contentWithRecall: [LearningContent] {
        contentStore.contents.filter { content in
            guard let qs = content.recallQuestions, !qs.isEmpty else { return false }
            if recallStore.isMuted(contentId: content.id) { return false }
            if recallStore.isCompleted(contentId: content.id) { return false }
            return !recallStore.hasReducedFrequency(contentId: content.id)
        }
    }

    private var completedRecallContent: [LearningContent] {
        contentStore.contents.filter { content in
            guard let qs = content.recallQuestions, !qs.isEmpty else { return false }
            if recallStore.isMuted(contentId: content.id) { return false }
            return recallStore.isCompleted(contentId: content.id)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        headerSection
                        
                        if !contentWithRecall.isEmpty {
                            readyToRecallSection
                        }
                        
                        if !completedRecallContent.isEmpty {
                            strengthenSection
                        }
                        
                        if contentWithRecall.isEmpty && completedRecallContent.isEmpty {
                            emptyState
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Recall")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    GlobalCaptureToolbarButton()
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Practice active recall")
                .font(Theme.Typography.title2)
                .foregroundColor(Palette.textPrimary)
            
            Text("Strengthen memory by testing yourself on content you've learned.")
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var readyToRecallSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Ready to recall")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)
            
            ForEach(contentWithRecall) { content in
                NavigationLink(destination: RecallSessionView(content: content)) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(Palette.primary)
                            .frame(width: 44, height: 44)
                            .background(Palette.primary.opacity(0.1))
                            .cornerRadius(Theme.CornerRadius.sm)
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(reviewTitle(for: content))
                                .font(Theme.Typography.callout)
                                .foregroundColor(Palette.textPrimary)
                                .lineLimit(2)
                            Text("\(content.recallQuestions?.count ?? 0) question\(content.recallQuestions?.count == 1 ? "" : "s") • \(primaryTopic(for: content))")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Palette.textSecondary)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Palette.card)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
        }
    }
    
    private var strengthenSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Ready to strengthen")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)
            
            ForEach(completedRecallContent) { content in
                NavigationLink(destination: RecallSessionView(content: content)) {
                    strengthenRow(content: content, scheduledDate: nextScheduledByContentId[content.id])
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scheduledRecallItems: [ScheduledRecallItem] {
        scheduledStore.upcoming(limit: 20).filter { item in
            !recallStore.isMuted(contentId: item.contentId)
        }
    }

    private var nextScheduledByContentId: [UUID: Date] {
        var dict: [UUID: Date] = [:]
        for item in scheduledRecallItems {
            if let existing = dict[item.contentId] {
                if item.fireDate < existing { dict[item.contentId] = item.fireDate }
            } else {
                dict[item.contentId] = item.fireDate
            }
        }
        return dict
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

    private func strengthenRow(content: LearningContent, scheduledDate: Date?) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 44, height: 44)
                .background(Color.green.opacity(0.12))
                .cornerRadius(Theme.CornerRadius.sm)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(reviewTitle(for: content))
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(2)
                Text("Next: \(nextScheduleLabel(for: scheduledDate)) • Topic: \(primaryTopic(for: content))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Palette.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private func nextScheduleLabel(for date: Date?) -> String {
        guard let date else { return "Not scheduled" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundColor(Palette.textSecondary)
            
            Text("No recall sessions yet")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)
            
            Text("When you analyze content that aligns with your goals, Signal will generate recall questions. Complete those to see them here.")
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
    }
}

struct ScheduledRecallRow: View {
    let item: ScheduledRecallItem
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundColor(Palette.primary)
                .frame(width: 40, height: 40)
                .background(Palette.primary.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.contentTitle)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(2)
                Text(formatDate(item.fireDate))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    RecallView()
        .environmentObject(GlobalCaptureCoordinator())
}
