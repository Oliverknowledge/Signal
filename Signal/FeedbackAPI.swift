import Foundation

// intentionally unused (out of scope)

public struct FeedbackSubmission: Codable {
    public let contentId: UUID
    public let traceId: UUID
    public let questionId: UUID?
    public let questionText: String
    public let type: String
    public let userAnswer: String?
    public let selectedIndex: Int?
    public let correctIndex: Int?
    
    public init(
        contentId: UUID,
        traceId: UUID,
        questionId: UUID?,
        questionText: String,
        type: String,
        userAnswer: String?,
        selectedIndex: Int?,
        correctIndex: Int?
    ) {
        self.contentId = contentId
        self.traceId = traceId
        self.questionId = questionId
        self.questionText = questionText
        self.type = type
        self.userAnswer = userAnswer
        self.selectedIndex = selectedIndex
        self.correctIndex = correctIndex
    }
}

public struct FeedbackResponse: Codable {
    public let correct: Bool
    public let score: Double?
    public let rationale: String?
    
    public init(correct: Bool, score: Double?, rationale: String?) {
        self.correct = correct
        self.score = score
        self.rationale = rationale
    }
}

public struct RecallSessionMetrics: Codable {
    public let sessions: Int
    public let correct: Int
    public let total: Int
    public let accuracy: Double
    
    public init(sessions: Int, correct: Int, total: Int, accuracy: Double) {
        self.sessions = sessions
        self.correct = correct
        self.total = total
        self.accuracy = accuracy
    }
}

public final class FeedbackAPI {
    public static let shared = FeedbackAPI()

    private let baseURL: URL
    private let session: URLSession

    private enum FeedbackAPIError: LocalizedError {
        case missingBaseURL
        case httpError(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "API base URL not found in Info.plist under key 'API_BASE_URL'."
            case .httpError(let statusCode):
                return "HTTP request failed with status code \(statusCode)."
            }
        }
    }

    private init() {
        guard let url = URL(string: "https://signal-backend-seven.vercel.app") else {
            fatalError("Invalid base URL")
        }
        self.baseURL = url
        self.session = URLSession.shared
    }

    public func submitAnswer(
        contentId: UUID,
        traceId: UUID,
        questionId: UUID?,
        questionText: String,
        type: String,
        userAnswer: String?,
        selectedIndex: Int?,
        correctIndex: Int?
    ) async throws -> FeedbackResponse {
        let submission = FeedbackSubmission(
            contentId: contentId,
            traceId: traceId,
            questionId: questionId,
            questionText: questionText,
            type: type,
            userAnswer: userAnswer,
            selectedIndex: selectedIndex,
            correctIndex: correctIndex
        )
        let request = try makeRequest(path: "/feedback/answer", method: "POST", body: submission)
        let (data, response) = try await session.data(for: request)
        try validateHttpResponse(response)
        let decoded = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        return decoded
    }

    public func fetchRecallMetrics() async throws -> RecallSessionMetrics {
        let urlRequest = try makeRequest(path: "/metrics/recall")
        let (data, response) = try await session.data(for: urlRequest)
        try validateHttpResponse(response)
        let decoded = try JSONDecoder().decode(RecallSessionMetrics.self, from: data)
        return decoded
    }

    private func makeRequest(path: String, method: String = "GET", body: Encodable? = nil) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        return request
    }

    private func validateHttpResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FeedbackAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

/// Helper type to encode any Encodable type erased to Encodable
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
