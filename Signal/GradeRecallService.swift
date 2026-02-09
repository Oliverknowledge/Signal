import Foundation

/// Response from POST /api/grade-recall
struct GradeRecallResponse: Codable {
    let score: Double
    let correct: Bool
    let threshold: Double
    let reasoning: String?
    let keyPoints: [String]?
    let couldHaveSaid: [String]?

    enum CodingKeys: String, CodingKey {
        case score
        case correct
        case threshold
        case reasoning
        case keyPoints = "key_points"
        case couldHaveSaid = "could_have_said"
    }
}

/// Payload for POST /api/grade-recall
struct GradeRecallPayload: Codable {
    let traceId: UUID
    let contentId: UUID
    let contentTitle: String
    let question: String
    let userAnswer: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case contentId = "content_id"
        case contentTitle = "content_title"
        case question
        case userAnswer = "user_answer"
        case timestamp
    }
}

/// Grades open-ended recall answers via the backend.
/// The backend uses an LLM to assess correctness (0-1) and returns whether it meets the threshold.
final class GradeRecallService {
    static let shared = GradeRecallService()
    private init() {}

    private let baseURL = APIConfig.baseURL
    private let defaultRelayToken = "9460c0fa1162a2684f35b776ea56f639870ec927aec48950fccf0269751f8fdf"

    private var relayToken: String? {
        if let env = ProcessInfo.processInfo.environment["SIGNAL_RELAY_TOKEN"], !env.isEmpty { return env }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "SIGNAL_RELAY_TOKEN") as? String, !plist.isEmpty { return plist }
        return defaultRelayToken
    }

    private var gradeEndpoint: URL? {
        URL(string: "\(baseURL)/api/grade-recall")
    }

    /// Grades an open-ended answer. Returns grading result or nil on failure.
    func grade(
        traceId: UUID,
        contentId: UUID,
        contentTitle: String,
        question: String,
        userAnswer: String
    ) async -> (correct: Bool, score: Double, reasoning: String?, keyPoints: [String], couldHaveSaid: [String])? {
        guard let url = gradeEndpoint,
              let token = relayToken,
              !userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let payload = GradeRecallPayload(
            traceId: traceId,
            contentId: contentId,
            contentTitle: contentTitle,
            question: question,
            userAnswer: userAnswer.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let body = try? encoder.encode(payload) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "x-signal-relay-token")
        request.httpBody = body
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(GradeRecallResponse.self, from: data)
            return (
                decoded.correct,
                decoded.score,
                decoded.reasoning,
                decoded.keyPoints ?? [],
                decoded.couldHaveSaid ?? []
            )
        } catch {
            #if DEBUG
            print("[GradeRecall] Error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
