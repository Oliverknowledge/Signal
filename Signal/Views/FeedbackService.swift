import Foundation

// Payload for POST /api/feedback
struct FeedbackPayload: Codable {
    let traceID: UUID
    let contentID: UUID
    let feedback: String
    let reasons: [String]?
    let recallCorrect: Int?
    let recallTotal: Int?
    let timestamp: Date
}

final class FeedbackService {
    static let shared = FeedbackService()
    private init() {}

    // Endpoint for feedback relay
    private let endpoint = URL(string: "https://signal-backend-seven.vercel.app/api/feedback")!

    // Persistent queue key
    private let queueKey = "signal.feedback.queue"
    private let queue = DispatchQueue(label: "signal.feedback.queue", qos: .utility)

    // Demo fallback token (same as ObservabilityClient)
    private let defaultRelayToken = "9460c0fa1162a2684f35b776ea56f639870ec927aec48950fccf0269751f8fdf"

    // Resolve relay token: ENV > Info.plist > default demo
    private var relayToken: String? {
        if let env = ProcessInfo.processInfo.environment["SIGNAL_RELAY_TOKEN"], !env.isEmpty { return env }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "SIGNAL_RELAY_TOKEN") as? String, !plist.isEmpty { return plist }
        return defaultRelayToken
    }

    // MARK: - Public API
    func submitFeedback(traceID: UUID,
                        contentID: UUID,
                        feedback: String,
                        reasons: [String]?,
                        recallCorrect: Int?,
                        recallTotal: Int?,
                        timestamp: Date) {
        let payload = FeedbackPayload(
            traceID: traceID,
            contentID: contentID,
            feedback: feedback,
            reasons: reasons,
            recallCorrect: recallCorrect,
            recallTotal: recallTotal,
            timestamp: timestamp
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let data = try? encoder.encode(payload) else {
            #if DEBUG
            print("[Feedback] Failed to encode payload")
            #endif
            return
        }

        enqueue(data)
        #if DEBUG
        let rc = reasons?.joined(separator: ",") ?? "-"
        print("[Feedback] queued (feedback=\(feedback), reasons=\(rc), queueCount=\(loadQueue().count))")
        #endif

        Task.detached(priority: .utility) { [weak self] in
            await self?.flushQueue()
        }
    }

    // MARK: - Queue Management
    private func loadQueue() -> [Data] {
        if let arr = UserDefaults.standard.array(forKey: queueKey) as? [Data] {
            return arr
        }
        return []
    }

    private func saveQueue(_ items: [Data]) {
        UserDefaults.standard.set(items, forKey: queueKey)
    }

    private func enqueue(_ item: Data) {
        queue.async {
            var items = self.loadQueue()
            items.append(item)
            if items.count > 200 { items.removeFirst(items.count - 200) }
            self.saveQueue(items)
        }
    }

    // MARK: - Networking
    private func makeRequest(token: String, body: Data) -> URLRequest {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(token, forHTTPHeaderField: "x-signal-relay-token")
        req.httpBody = body
        req.timeoutInterval = 8
        return req
    }

    private func urlSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        return URLSession(configuration: config)
    }

    @discardableResult
    func flushQueue() async -> Int {
        guard let token = relayToken, !token.isEmpty else {
            #if DEBUG
            print("[Feedback] Relay token missing; will retry later")
            #endif
            return 0
        }

        var sent = 0
        while true {
            var items: [Data] = []
            // Load snapshot synchronously
            queue.sync { items = self.loadQueue() }
            guard let first = items.first else { break }

            let request = makeRequest(token: token, body: first)
            do {
                let (_, response) = try await urlSession().data(for: request)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    // Remove first and persist
                    queue.sync {
                        var current = self.loadQueue()
                        if !current.isEmpty { current.removeFirst() }
                        self.saveQueue(current)
                    }
                    sent += 1
                    #if DEBUG
                    let remaining = max(items.count - 1, 0)
                    print("[Feedback] sent OK (remaining=\(remaining))")
                    #endif
                } else {
                    #if DEBUG
                    let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                    print("[Feedback] send failed (status=\(code)); will retry later")
                    #endif
                    break
                }
            } catch {
                #if DEBUG
                print("[Feedback] network error: \(error.localizedDescription); will retry later")
                #endif
                break
            }
        }
        return sent
    }
}
