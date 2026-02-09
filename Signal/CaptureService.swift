import Foundation
import SwiftUI
import CryptoKit

struct CaptureResult {
    let content: LearningContent
    let decision: Decision
    let traceId: UUID
}

final class CaptureService {
    static let shared = CaptureService()
    private let api = SignalAPIClient()

    private init() {}

    private func performSubmit(urlString: String, goalId: String, goalDescription: String, userHash: String, source: ContentSource) async throws -> CaptureResult {
        let known = AppStorage.knownConcepts()
        let weak = AppStorage.weakConcepts()
        let careerStage = AppStorage.careerStage
        let interventionPolicy = AppStorage.interventionPolicy
        let libraryDigest = buildLibraryDigest()
        
        let request = AnalyzeRequest(
            contentUrl: urlString,
            userIdHash: userHash,
            goalId: goalId,
            goalDescription: goalDescription,
            careerStage: careerStage,
            interventionPolicy: interventionPolicy,
            learningMode: normalizedLearningMode(),
            knownConcepts: known,
            weakConcepts: weak,
            libraryDigest: libraryDigest
        )

        let response = try await api.analyzeContent(request: request)

        // Map response to LearningContent
        let content = mapToLearningContent(url: urlString, source: source, response: response)

        // Observability mapping + event
        let trace = UUID(uuidString: response.traceId) ?? UUID()
        let decision = response.decision
        let decisionStr = decision.rawValue
        let contentType = (source == .youtube) ? "video" : "article"
        let decisionConfidence = DecisionConfidence.fromScores(
            relevance: response.relevanceScore,
            learningValue: response.learningValueScore,
            conceptCount: response.concepts.count,
            interventionPolicy: AppStorage.interventionPolicy
        )
        ObservabilityStore.shared.map(contentID: content.id, to: trace, decision: decisionStr, contentType: contentType)
        
        var contentWithTrace = content
        contentWithTrace.traceId = trace
        
        print("[Capture] Mapped content \(contentWithTrace.id) to trace \(trace)")

        // Persist content
        ContentStore.shared.add(contentWithTrace)

        // Save a suggested follow-up review time for the Review Schedule screen.
        if decision == .triggered, (contentWithTrace.recallQuestions ?? []).isEmpty == false {
            let delay = NotificationManager.preferredRecallDelay()
            let fireDate = Date().addingTimeInterval(delay)
            ScheduledRecallStore.shared.add(contentId: contentWithTrace.id, contentTitle: contentWithTrace.title, fireDate: fireDate)
        }

        if decision == .triggered, let upcomingEvent = nearestUpcomingPrepEvent() {
            await NotificationManager.shared.schedulePrepReadyNotification(
                contentTitle: contentWithTrace.title,
                contentId: contentWithTrace.id,
                event: upcomingEvent
            )
        }

        let event = ObservabilityEvent(
            traceID: trace,
            eventType: "content_evaluation",
            contentType: contentType,
            conceptCount: response.concepts.count,
            relevanceScore: response.relevanceScore,
            learningValueScore: response.learningValueScore,
            decision: decisionStr,
            systemDecision: decisionStr,
            interventionPolicy: interventionPolicy,
            careerStage: careerStage,
            ignoreReason: contentWithTrace.ignoreReason,
            decisionConfidence: decisionConfidence,
            userFeedback: nil,
            timestamp: Date()
        )
        ObservabilityClient.shared.log(event)

        return CaptureResult(content: contentWithTrace, decision: decision, traceId: trace)
    }

    // Public entry point
    func submit(urlString: String, appState: AppState) async throws -> CaptureResult {
        let source: ContentSource = urlString.contains("youtube.com") || urlString.contains("youtu.be") ? .youtube : .webpage
        let (goalId, goalDescription): (String, String) = {
            if let id = AppStorage.selectedGoalId, let desc = AppStorage.selectedGoalDescription {
                return (id, desc)
            } else {
                return self.goalContext(from: appState)
            }
        }()
        let userHash = self.hashUser("demo-user@signal.app")
        return try await performSubmit(urlString: urlString, goalId: goalId, goalDescription: goalDescription, userHash: userHash, source: source)
    }

    func submit(urlString: String, userHash: String = "demo-user@signal.app", goalId: String = "default-goal", goalDescription: String = "General learning") async throws -> CaptureResult {
        let source: ContentSource = urlString.contains("youtube.com") || urlString.contains("youtu.be") ? .youtube : .webpage
        let hash = self.hashUser(userHash)
        return try await performSubmit(urlString: urlString, goalId: goalId, goalDescription: goalDescription, userHash: hash, source: source)
    }

    // MARK: - Helpers
    private func mapToLearningContent(url: String, source: ContentSource, response: AnalyzeResponse) -> LearningContent {
        let title = inferTitle(from: url)
        let concepts: [Concept] = response.concepts.map(ConceptClassifier.makeConcept)
        let status: AnalysisStatus = (response.decision == .triggered) ? .completed : .belowThreshold
        let ignoreReason: IgnoreReason? = (response.decision == .ignored)
            ? IgnoreReason.fromScores(relevance: response.relevanceScore, learningValue: response.learningValueScore)
            : nil
        let recallQuestions: [RecallQuestion]? = (response.decision == .triggered && !response.recallQuestions.isEmpty)
            ? response.recallQuestions
            : nil
        return LearningContent(
            url: url,
            title: title,
            source: source,
            dateShared: Date(),
            analysisStatus: status,
            concepts: concepts,
            relevanceScore: response.relevanceScore,
            learningValue: response.learningValueScore,
            agentReasoning: [],
            ignoreReason: ignoreReason,
            recallQuestions: recallQuestions
        )
    }

    private func inferTitle(from url: String) -> String {
        if url.contains("youtube.com") || url.contains("youtu.be") { return "YouTube Video" }
        return URL(string: url)?.host ?? "Shared Link"
    }

    private func goalContext(from appState: AppState) -> (String, String) {
        if let goal = appState.learningGoals.first {
            return (goal.id.uuidString, goal.title)
        }
        return ("default-goal", "General learning")
    }

    private func hashUser(_ raw: String) -> String {
        let data = Data(raw.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func buildLibraryDigest() -> [LibraryDigestItem]? {
        let items = ContentStore.shared
            .all()
            .filter { !$0.concepts.isEmpty }
            .sorted { $0.dateShared > $1.dateShared }
            .prefix(100)
            .compactMap { content -> LibraryDigestItem? in
                let concepts = Array(content.concepts.map { $0.name }.prefix(12))
                guard !concepts.isEmpty else { return nil }
                let title = truncate(content.title, max: 80)
                let createdAt = Int(content.dateShared.timeIntervalSince1970)
                return LibraryDigestItem(contentId: content.id.uuidString, title: title, concepts: concepts, createdAt: createdAt)
            }
        return items.isEmpty ? nil : Array(items)
    }

    private func truncate(_ value: String, max: Int) -> String {
        guard value.count > max else { return value }
        return String(value.prefix(max))
    }

    private func nearestUpcomingPrepEvent() -> PrepEvent? {
        let today = Calendar.current.startOfDay(for: Date())
        return AppStorage.prepEvents
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
            .first
    }

    private func normalizedLearningMode() -> String {
        LearningMode.fromStored(AppStorage.learningModeRaw).apiValue
    }
}
