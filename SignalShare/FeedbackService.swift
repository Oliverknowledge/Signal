import Foundation

// intentionally unused (out of scope)

struct FeedbackPayload: Codable {
    let traceID: UUID
    let contentID: UUID
    let feedback: String
    let reasons: [String]?
    let recallCorrect: Int?
    let recallTotal: Int?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case traceID = "trace_id"
        case contentID = "content_id"
        case feedback
        case reasons
        case recallCorrect = "recall_correct"
        case recallTotal = "recall_total"
        case timestamp
    }
}

final class FeedbackService {
    static let shared = FeedbackService()
    
    private init() {}
    
    private let endpoint = URL(string: "https://signal-backend-seven.vercel.app/api/feedback")!
    private let queueKey = "signal.feedback.queue"
    private let maxQueueCount = 200
    
    private var token: String {
        if let envToken = ProcessInfo.processInfo.environment["SIGNAL_RELAY_TOKEN"], !envToken.isEmpty {
            return envToken
        }
        if let infoPlistToken = Bundle.main.object(forInfoDictionaryKey: "SIGNAL_RELAY_TOKEN") as? String, !infoPlistToken.isEmpty {
            return infoPlistToken
        }
        return "0a1bc4c9-0b7d-4f7a-a72a-7a3a5a17f9bc" // Demo token from ObservabilityClient
    }
    
    private func loadQueue() -> [Data] {
        let defaults = UserDefaults.standard
        return defaults.array(forKey: queueKey) as? [Data] ?? []
    }
    
    private func saveQueue(_ queue: [Data]) {
        let defaults = UserDefaults.standard
        let limitedQueue = Array(queue.prefix(maxQueueCount))
        defaults.set(limitedQueue, forKey: queueKey)
    }
    
    func submitFeedback(traceID: UUID, contentID: UUID, feedback: String, reasons: [String]?, recallCorrect: Int?, recallTotal: Int?, timestamp: Date) {
        let payload = FeedbackPayload(traceID: traceID,
                                      contentID: contentID,
                                      feedback: feedback,
                                      reasons: reasons,
                                      recallCorrect: recallCorrect,
                                      recallTotal: recallTotal,
                                      timestamp: timestamp)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        
        var queue = loadQueue()
        queue.append(data)
        saveQueue(queue)
        
        print("[Feedback] queued (feedback=\(feedback), reasons=\(reasons ?? []), queueCount=\(queue.count))")
        
        Task.detached(priority: .background) { [weak self] in
            await self?.flushQueue()
        }
    }
    
    func flushQueue() async {
        var queue = loadQueue()
        guard !queue.isEmpty else { return }
        
        let session = urlSession()
        
        while !queue.isEmpty {
            let data = queue.first!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "x-signal-relay-token")
            
            do {
                let (responseData, response) = try await session.data(for: request)
                if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                    queue.removeFirst()
                    saveQueue(queue)
                    print("[Feedback] sent OK (remaining=\(queue.count))")
                } else {
                    print("[Feedback] send failed (will retry)")
                    break
                }
            } catch {
                print("[Feedback] send failed (will retry)")
                break
            }
        }
    }
    
    private func urlSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 8
        return URLSession(configuration: cfg)
    }
}
