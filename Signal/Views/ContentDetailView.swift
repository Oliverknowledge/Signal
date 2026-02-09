import SwiftUI

struct ContentDetailView: View {
    let content: LearningContent
    @State private var showingAgentReasoning = false
    @State private var showingFeedback = false
    @ObservedObject private var contentStore = ContentStore.shared

    private var resolvedContent: LearningContent {
        contentStore.contents.first(where: { $0.id == content.id }) ?? content
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.primaryBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Analysis Status
                    analysisSection
                    
                    // Concepts Detected
                    if !content.concepts.isEmpty {
                        conceptsSection
                    }
                    
                    // Agent Reasoning
                    if !content.agentReasoning.isEmpty {
                        agentReasoningSection
                    }
                    
                    // Actions
                    actionsSection
                }
                .padding(Theme.Spacing.md)
            }
        }
        .onAppear { logEvaluationIfNeeded() }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFeedback) {
            FeedbackView(content: content)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: content.source == .youtube ? "play.rectangle.fill" : "doc.text.fill")
                    .font(.title)
                    .foregroundColor(Theme.Colors.primaryAccent)
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(content.source.rawValue)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Text(timeAgo(from: content.dateShared))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                
                Spacer()
            }
            
            Text(content.title)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text(content.url)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.contentSurface)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Analysis")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)
            
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("Status")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    StatusBadge(status: content.analysisStatus)
                }

                if content.analysisStatus == .belowThreshold {
                    Divider()
                        .background(Theme.Colors.secondaryBackground)
                    Text(ignoredSummaryText(relevance: content.relevanceScore, learningValue: content.learningValue))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                if content.analysisStatus == .completed {
                    Divider()
                        .background(Theme.Colors.secondaryBackground)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Relevance Score")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textMuted)
                            Text("\(Int(content.relevanceScore * 100))%")
                                .font(Theme.Typography.title3)
                                .foregroundColor(scoreColor(content.relevanceScore))
                        }
                        
                        Spacer()
                        
                        ScoreCircle(score: content.relevanceScore, size: 60)
                    }
                    
                    Divider()
                        .background(Theme.Colors.secondaryBackground)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Learning Value")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textMuted)
                            Text("\(Int(content.learningValue * 100))%")
                                .font(Theme.Typography.title3)
                                .foregroundColor(scoreColor(content.learningValue))
                        }
                        
                        Spacer()
                        
                        ScoreCircle(score: content.learningValue, size: 60)
                    }
                    
                    Divider()
                        .background(Theme.Colors.secondaryBackground)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.Colors.success)
                        Text(policyExplanation())
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.contentSurface)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
    
    private var conceptsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Concepts Detected")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)
            
            ForEach(content.concepts) { concept in
                ConceptDetailCard(concept: concept)
            }
        }
    }
    
    private var agentReasoningSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Agent Reasoning")
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    showingAgentReasoning.toggle()
                } label: {
                    Text(showingAgentReasoning ? "Hide" : "Show")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
            }
            
            if showingAgentReasoning {
                ForEach(content.agentReasoning) { step in
                    ReasoningStepCard(step: step)
                }
            }
        }
    }
    
private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let questions = resolvedContent.recallQuestions, !questions.isEmpty {
                NavigationLink(destination: RecallSessionView(content: resolvedContent)) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(Theme.Typography.callout)
                        Text("Review")
                            .font(Theme.Typography.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.primaryAccent)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .buttonStyle(.plain)
            }

            SignalButton(title: "Was this useful?", style: .secondary) {
                showingFeedback = true
            }

            SignalButton(title: "Open Source", style: .ghost) {
                // Open URL
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 {
            return Theme.Colors.success
        } else if score >= 0.6 {
            return Theme.Colors.evaluationMedium
        } else {
            return Theme.Colors.evaluationLow
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }
    
    private func logEvaluationIfNeeded() {
        // Only log analyses with a concrete decision; never include raw content.
        guard content.analysisStatus == .completed || content.analysisStatus == .belowThreshold else { return }

        // Avoid duplicate logs for the same content; if a trace already exists, skip.
        if ObservabilityStore.shared.lastTraceID(for: content.id) != nil {
            return
        }

        let traceID = UUID()
        let contentType = (content.source == .youtube) ? "video" : "article"
        let conceptCount = content.concepts.count
        let relevance = content.relevanceScore
        let learningValue = content.learningValue
        let decision: String = (content.analysisStatus == .completed) ? "triggered" : "ignored"
        let ignoreReason = (decision == "ignored") ? (content.ignoreReason ?? IgnoreReason.fromScores(relevance: relevance, learningValue: learningValue)) : nil
        let careerStage = AppStorage.careerStage
        let decisionConfidence = DecisionConfidence.fromScores(
            relevance: relevance,
            learningValue: learningValue,
            conceptCount: conceptCount,
            interventionPolicy: AppStorage.interventionPolicy
        )

        // Map content to trace for future feedback correlation (local only).
        ObservabilityStore.shared.map(contentID: content.id, to: traceID, decision: decision, contentType: contentType)

        let event = ObservabilityEvent(
            traceID: traceID,
            eventType: "content_evaluation",
            contentType: contentType,
            conceptCount: conceptCount,
            relevanceScore: relevance,
            learningValueScore: learningValue,
            decision: decision,
            systemDecision: decision,
            interventionPolicy: AppStorage.interventionPolicy,
            careerStage: careerStage,
            ignoreReason: ignoreReason,
            decisionConfidence: decisionConfidence,
            userFeedback: nil,
            timestamp: Date()
        )

        ObservabilityClient.shared.log(event)
    }

    private func policyExplanation() -> String {
        let policy = AppStorage.interventionPolicy
        if policy == "aggressive" {
            return "Aggressive policy: broader learning moments trigger recall to keep momentum."
        }
        return "Focused policy: only high-confidence learning moments trigger recall."
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

struct ConceptDetailCard: View {
    let concept: Concept
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(concept.name)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textOnLight)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(concept.difficulty.rawValue)
                    .font(Theme.Typography.caption)
                    .foregroundColor(difficultyColor)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(difficultyColor.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
            }
            
            Text(concept.categoryPathLabel)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
            
            if concept.masteryLevel > 0 {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text("Current Mastery")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                        Spacer()
                        Text("\(Int(concept.masteryLevel * 100))%")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textOnLight)
                            .fontWeight(.semibold)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Theme.Colors.secondaryBackground.opacity(0.3))
                            
                            Rectangle()
                                .fill(Theme.Colors.mastery)
                                .frame(width: geometry.size.width * concept.masteryLevel)
                        }
                    }
                    .frame(height: 4)
                    .cornerRadius(2)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.contentSurface)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var difficultyColor: Color {
        switch concept.difficulty {
        case .beginner: return Theme.Colors.success
        case .intermediate: return Theme.Colors.evaluationMedium
        case .advanced: return Theme.Colors.primaryAccent
        case .expert: return Theme.Colors.evaluationLow
        }
    }
}

struct ReasoningStepCard: View {
    let step: ReasoningStep
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Circle()
                        .fill(Theme.Colors.primaryAccent)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(step.stepNumber)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.white)
                        )
                    
                    Text(step.action)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textOnLight)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Divider()
                        .background(Theme.Colors.secondaryBackground)
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Reasoning")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(step.reasoning)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textOnLight)
                    }
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Output")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(step.output)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textOnLight)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.contentSurface)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

#Preview {
    NavigationView {
        ContentDetailView(content: LearningContent(
            url: "https://youtube.com/watch?v=abc123",
            title: "Understanding C++ Smart Pointers",
            source: .youtube,
            analysisStatus: .completed,
            concepts: [
                Concept(name: "Smart Pointers", category: "C++", subcategory: "Memory Management", difficulty: .intermediate, masteryLevel: 0.75, confidenceScore: 0.8)
            ],
            relevanceScore: 0.92,
            learningValue: 0.88,
            agentReasoning: [
                ReasoningStep(stepNumber: 1, action: "Scrape Content", reasoning: "Extracting transcript", output: "Success")
            ]
        ))
    }
}
