// Observability.swift
// Implements anonymized, non-blocking observability for Signal
// NOTE: This layer only sends aggregate metrics and IDs. It never sends raw content,
// user goals, emotions, transcripts, or any personal data.

import Foundation
import SwiftUI

// MARK: - Observability Event Model
// Only includes anonymous metrics and identifiers required for evaluation.
// CodingKeys use snake_case to match relay API schema.
struct ObservabilityEvent: Codable, Identifiable {
    // Local-only identifier for lists/debugging
    var id: UUID { traceID }

    let traceID: UUID
    let eventType: String   // "content_evaluation" | "user_feedback"
    let contentType: String // "video" | "article"
    let conceptCount: Int
    let relevanceScore: Double
    let learningValueScore: Double
    let decision: String   // "triggered" | "ignored"
    let systemDecision: String?
    let interventionPolicy: String?
    let careerStage: career_stage?
    let ignoreReason: IgnoreReason?
    let decisionConfidence: DecisionConfidence?
    let userFeedback: String? // "useful" | "not_useful"
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case traceID = "trace_id"
        case eventType = "event_type"
        case contentType = "content_type"
        case conceptCount = "concept_count"
        case relevanceScore = "relevance_score"
        case learningValueScore = "learning_value_score"
        case decision
        case systemDecision = "system_decision"
        case interventionPolicy = "intervention_policy"
        case careerStage = "career_stage"
        case ignoreReason = "ignore_reason"
        case decisionConfidence = "decision_confidence"
        case userFeedback = "user_feedback"
        case timestamp
    }

    init(
        traceID: UUID,
        eventType: String,
        contentType: String,
        conceptCount: Int,
        relevanceScore: Double,
        learningValueScore: Double,
        decision: String,
        systemDecision: String?,
        interventionPolicy: String?,
        careerStage: career_stage?,
        ignoreReason: IgnoreReason?,
        decisionConfidence: DecisionConfidence?,
        userFeedback: String?,
        timestamp: Date
    ) {
        self.traceID = traceID
        self.eventType = eventType
        self.contentType = contentType
        self.conceptCount = conceptCount
        self.relevanceScore = relevanceScore
        self.learningValueScore = learningValueScore
        self.decision = decision
        self.systemDecision = systemDecision
        self.interventionPolicy = interventionPolicy
        self.careerStage = careerStage
        self.ignoreReason = ignoreReason
        self.decisionConfidence = decisionConfidence
        self.userFeedback = userFeedback
        self.timestamp = timestamp
    }

    // Be lenient with optional enum fields so old stored values don't invalidate all metrics.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        traceID = try container.decode(UUID.self, forKey: .traceID)
        eventType = try container.decode(String.self, forKey: .eventType)
        contentType = try container.decode(String.self, forKey: .contentType)
        conceptCount = try container.decode(Int.self, forKey: .conceptCount)
        relevanceScore = try container.decode(Double.self, forKey: .relevanceScore)
        learningValueScore = try container.decode(Double.self, forKey: .learningValueScore)
        decision = try container.decode(String.self, forKey: .decision)
        systemDecision = try container.decodeIfPresent(String.self, forKey: .systemDecision)
        interventionPolicy = try container.decodeIfPresent(String.self, forKey: .interventionPolicy)
        if let rawCareerStage = try container.decodeIfPresent(String.self, forKey: .careerStage) {
            careerStage = career_stage(rawValue: rawCareerStage)
        } else {
            careerStage = nil
        }
        if let rawIgnoreReason = try container.decodeIfPresent(String.self, forKey: .ignoreReason) {
            ignoreReason = IgnoreReason(rawValue: rawIgnoreReason)
        } else {
            ignoreReason = nil
        }
        if let rawDecisionConfidence = try container.decodeIfPresent(String.self, forKey: .decisionConfidence) {
            decisionConfidence = DecisionConfidence(rawValue: rawDecisionConfidence)
        } else {
            decisionConfidence = nil
        }
        userFeedback = try container.decodeIfPresent(String.self, forKey: .userFeedback)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(traceID, forKey: .traceID)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(conceptCount, forKey: .conceptCount)
        try container.encode(relevanceScore, forKey: .relevanceScore)
        try container.encode(learningValueScore, forKey: .learningValueScore)
        try container.encode(decision, forKey: .decision)
        try container.encodeIfPresent(systemDecision, forKey: .systemDecision)
        try container.encodeIfPresent(interventionPolicy, forKey: .interventionPolicy)
        try container.encodeIfPresent(careerStage?.rawValue, forKey: .careerStage)
        try container.encodeIfPresent(ignoreReason?.rawValue, forKey: .ignoreReason)
        try container.encodeIfPresent(decisionConfidence?.rawValue, forKey: .decisionConfidence)
        try container.encodeIfPresent(userFeedback, forKey: .userFeedback)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Local Store (no PII)
// Stores events locally for demo/debug metrics and resilience when offline.
// DOES NOT store raw content, goals, emotions, or user comments.
final class ObservabilityStore {
    static let shared = ObservabilityStore()

    private let eventsKey = "signal.observability.events"
    private let contentTraceMapKey = "signal.observability.contentTraceMap"
    private let decisionByTraceKey = "signal.observability.decisionByTrace"
    private let contentTypeByTraceKey = "signal.observability.contentTypeByTrace"
    private let queue = DispatchQueue(label: "signal.observability.store", qos: .utility)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.keyEncodingStrategy = .convertToSnakeCase
        encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        dec.keyDecodingStrategy = .convertFromSnakeCase
        decoder = dec
    }

    // Append an event to local storage (keeps last 500 to bound size)
    func save(event: ObservabilityEvent) {
        queue.async {
            var events = self.loadEvents()
            events.append(event)
            if events.count > 500 { events.removeFirst(events.count - 500) }
            self.persistEvents(events)

            // Cache decision and content type by trace for correlation (e.g., false positives)
            self.setDecision(event.decision, for: event.traceID)
            self.setContentType(event.contentType, for: event.traceID)
        }
    }

    // Map a content ID to a trace ID to correlate evaluation with subsequent feedback.
    func map(contentID: UUID, to traceID: UUID, decision: String, contentType: String) {
        queue.async {
            var map = self.loadContentTraceMap()
            map[contentID.uuidString] = traceID.uuidString
            UserDefaults.standard.set(map, forKey: self.contentTraceMapKey)
            self.setDecision(decision, for: traceID)
            self.setContentType(contentType, for: traceID)
        }
    }

    func lastTraceID(for contentID: UUID) -> UUID? {
        let map = loadContentTraceMap()
        if let idStr = map[contentID.uuidString], let id = UUID(uuidString: idStr) {
            return id
        }
        return nil
    }

    func decision(for traceID: UUID) -> String? {
        let dict = UserDefaults.standard.dictionary(forKey: decisionByTraceKey) as? [String: String]
        return dict?[traceID.uuidString]
    }

    func contentType(for traceID: UUID) -> String? {
        let dict = UserDefaults.standard.dictionary(forKey: contentTypeByTraceKey) as? [String: String]
        return dict?[traceID.uuidString]
    }

    // MARK: - Stats for Debug View
    struct Stats {
        let total: Int
        let triggered: Int
        let ignored: Int
        let falsePositives: Int
        let lastFive: [ObservabilityEvent]
    }

    func stats() -> Stats {
        let events = loadEvents()
        let total = events.count
        let evals = events.filter { $0.eventType == "content_evaluation" }
        let triggered = evals.filter { $0.decision == "triggered" }.count
        let ignored = evals.filter { $0.decision == "ignored" }.count

        // False positive: evaluation triggered followed by user feedback not_useful on same trace
        let feedbacks = events.filter { $0.eventType == "user_feedback" && $0.userFeedback == "not_useful" }
        let badTraceIDs = Set(feedbacks.map { $0.traceID })
        let falsePositives = evals.filter { $0.decision == "triggered" && badTraceIDs.contains($0.traceID) }.count

        let lastFive = Array(evals.suffix(5).reversed())
        return Stats(total: total, triggered: triggered, ignored: ignored, falsePositives: falsePositives, lastFive: lastFive)
    }

    // MARK: - Private helpers
    private func loadEvents() -> [ObservabilityEvent] {
        guard let data = UserDefaults.standard.data(forKey: eventsKey) else { return [] }
        if let decoded = try? decoder.decode([ObservabilityEvent].self, from: data) {
            return decoded
        }

        // Best-effort recovery for partially incompatible historical payloads.
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        var recovered: [ObservabilityEvent] = []
        for eventJSON in json {
            guard JSONSerialization.isValidJSONObject(eventJSON),
                  let eventData = try? JSONSerialization.data(withJSONObject: eventJSON),
                  let event = try? decoder.decode(ObservabilityEvent.self, from: eventData)
            else { continue }
            recovered.append(event)
        }
        if !recovered.isEmpty {
            persistEvents(recovered)
        }
        return recovered
    }

    private func persistEvents(_ events: [ObservabilityEvent]) {
        if let data = try? encoder.encode(events) {
            UserDefaults.standard.set(data, forKey: eventsKey)
        }
    }

    private func loadContentTraceMap() -> [String: String] {
        return (UserDefaults.standard.dictionary(forKey: contentTraceMapKey) as? [String: String]) ?? [:]
    }

    private func setDecision(_ decision: String, for traceID: UUID) {
        var dict = (UserDefaults.standard.dictionary(forKey: decisionByTraceKey) as? [String: String]) ?? [:]
        dict[traceID.uuidString] = decision
        UserDefaults.standard.set(dict, forKey: decisionByTraceKey)
    }

    private func setContentType(_ contentType: String, for traceID: UUID) {
        var dict = (UserDefaults.standard.dictionary(forKey: contentTypeByTraceKey) as? [String: String]) ?? [:]
        dict[traceID.uuidString] = contentType
        UserDefaults.standard.set(dict, forKey: contentTypeByTraceKey)
    }
}

// MARK: - Observability Client
// Sends anonymized metrics to the relay. Non-blocking, silent failure, max 1 retry.
final class ObservabilityClient {
    static let shared = ObservabilityClient()
    private init() {}

    // Demo fallback token (for hackathon/testing). Prefer ENV/Info.plist when available.
    private let defaultRelayToken = "9460c0fa1162a2684f35b776ea56f639870ec927aec48950fccf0269751f8fdf"

    private let endpoint = URL(string: "https://signal-backend-seven.vercel.app/api/opik-log")!

    // Reads relay token from environment or Info.plist. If missing, network send is skipped.
    private var relayToken: String? {
        // Prefer environment variable
        if let env = ProcessInfo.processInfo.environment["SIGNAL_RELAY_TOKEN"], !env.isEmpty { return env }
        // Then Info.plist
        if let plist = Bundle.main.object(forInfoDictionaryKey: "SIGNAL_RELAY_TOKEN") as? String, !plist.isEmpty { return plist }
        // Finally, fallback to the embedded demo token to ensure the header is always attached in demos
        return defaultRelayToken
    }

    // Public API: log event (returns immediately). Always saves locally first.
    func log(_ event: ObservabilityEvent) {
        // Persist locally for offline resilience and debug metrics
        ObservabilityStore.shared.save(event: event)

        // Prepare network payload
        guard let token = relayToken else {
            // In debug builds, indicate missing token. Never block UI.
            #if DEBUG
            print("[Observability] Relay token missing. Event stored locally only.")
            #endif
            return
        }

        // Serialize JSON with snake_case keys and ISO8601 dates.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let body = try? encoder.encode(event) else {
            #if DEBUG
            print("[Observability] Failed to encode event.")
            #endif
            return
        }

        // Send on a background task; never block caller.
        Task.detached(priority: .utility) { [endpoint] in
            await self.send(body: body, token: token, attempt: 1)
        }
    }

    // MARK: - Networking (max 1 retry, silent failure)
    private func makeRequest(token: String, body: Data) -> URLRequest {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(token, forHTTPHeaderField: "X-Signal-Relay-Token")
        req.httpBody = body
        req.timeoutInterval = 8 // keep short to avoid UI impact
        return req
    }

    private func urlSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false // do not block when offline
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        return URLSession(configuration: config)
    }

    private func send(body: Data, token: String, attempt: Int) async {
        let request = makeRequest(token: token, body: body)
        do {
            let (_, response) = try await urlSession().data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                // Success; nothing else to do
                return
            } else {
                try await retryIfNeeded(body: body, token: token, attempt: attempt)
            }
        } catch {
            // Network error: retry once, then give up silently
            try? await retryIfNeeded(body: body, token: token, attempt: attempt)
        }
    }

    private func retryIfNeeded(body: Data, token: String, attempt: Int) async throws {
        if attempt >= 2 { return } // never retry more than once
        // Small backoff; do not block UI thread
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6s
        await send(body: body, token: token, attempt: attempt + 1)
    }
}
