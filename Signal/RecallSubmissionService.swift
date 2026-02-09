import Foundation

/// Payload for POST /api/recall. Does not send open-ended answers.
struct RecallPayload: Codable {
    let traceId: UUID
    let contentId: UUID
    let recallCorrect: Int
    let recallTotal: Int
}

final class RecallSubmissionService {
    static let shared = RecallSubmissionService()
    private init() {}

    private let baseURL = APIConfig.baseURL
    private let queueKey = "signal.recall.queue"
    private let queue = DispatchQueue(label: "signal.recall.queue", qos: .utility)

    private var recallEndpoint: URL? {
        URL(string: "\(baseURL)/api/recall")
    }

    private let defaultRelayToken = "9460c0fa1162a2684f35b776ea56f639870ec927aec48950fccf0269751f8fdf"

    private var relayToken: String? {
        if let env = ProcessInfo.processInfo.environment["SIGNAL_RELAY_TOKEN"], !env.isEmpty { return env }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "SIGNAL_RELAY_TOKEN") as? String, !plist.isEmpty { return plist }
        return defaultRelayToken
    }

    func submit(traceId: UUID, contentId: UUID, recallCorrect: Int, recallTotal: Int) {
        let payload = RecallPayload(
            traceId: traceId,
            contentId: contentId,
            recallCorrect: recallCorrect,
            recallTotal: recallTotal
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let data = try? encoder.encode(payload) else {
            #if DEBUG
            print("[Recall] Failed to encode payload")
            #endif
            return
        }

        enqueue(data)
        #if DEBUG
        print("[Recall] queued (correct=\(recallCorrect), total=\(recallTotal), queueCount=\(loadQueue().count))")
        #endif

        Task.detached(priority: .utility) { [weak self] in
            await self?.flushQueue()
        }
    }

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

    private func makeRequest(token: String, body: Data) -> URLRequest? {
        guard let url = recallEndpoint else { return nil }
        var req = URLRequest(url: url)
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
            print("[Recall] Relay token missing; will retry later")
            #endif
            return 0
        }

        var sent = 0
        while true {
            var items: [Data] = []
            queue.sync { items = self.loadQueue() }
            guard let first = items.first, let request = makeRequest(token: token, body: first) else { break }

            do {
                let (_, response) = try await urlSession().data(for: request)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    queue.sync {
                        var current = self.loadQueue()
                        if !current.isEmpty { current.removeFirst() }
                        self.saveQueue(current)
                    }
                    sent += 1
                } else {
                    break
                }
            } catch {
                break
            }
        }
        return sent
    }
}
