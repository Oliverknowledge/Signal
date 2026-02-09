import Foundation
import Combine

/// A scheduled recall reminder (shown on Review Schedule calendar).
struct ScheduledRecallItem: Identifiable, Hashable, Codable {
    let id: UUID
    let contentId: UUID
    let contentTitle: String
    let fireDate: Date

    init(id: UUID = UUID(), contentId: UUID, contentTitle: String, fireDate: Date) {
        self.id = id
        self.contentId = contentId
        self.contentTitle = contentTitle
        self.fireDate = fireDate
    }
}

/// Stores scheduled recall reminders so they appear on the Review Schedule calendar.
final class ScheduledRecallStore: ObservableObject {
    static let shared = ScheduledRecallStore()
    private let key: String
    private let queue: DispatchQueue
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        key = "signal.scheduledRecall"
        queue = DispatchQueue(label: "signal.scheduledRecall", qos: .utility)
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        decoder = d
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        encoder = e
    }

    func add(contentId: UUID, contentTitle: String, fireDate: Date) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var list = self.load()
            list.append(ScheduledRecallItem(contentId: contentId, contentTitle: contentTitle, fireDate: fireDate))
            list.sort { $0.fireDate < $1.fireDate }
            self.save(list)
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    func remove(contentId: UUID) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var list = self.load()
            list.removeAll { $0.contentId == contentId }
            self.save(list)
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    /// Upcoming items (fire date in the future), sorted by date.
    func upcoming(limit: Int = 50) -> [ScheduledRecallItem] {
        let now = Date()
        return load().filter { $0.fireDate >= now }.prefix(limit).map { $0 }
    }

    /// All items (for calendar markers); includes past for current month.
    func all() -> [ScheduledRecallItem] {
        load()
    }

    private func load() -> [ScheduledRecallItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? decoder.decode([ScheduledRecallItem].self, from: data) else { return [] }
        return decoded
    }

    private func save(_ items: [ScheduledRecallItem]) {
        guard let data = try? encoder.encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
