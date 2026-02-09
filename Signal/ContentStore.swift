import Foundation
import Combine

final class ContentStore: ObservableObject {
    static let shared = ContentStore()

    @Published private(set) var contents: [LearningContent] = []

    private let key = "signal.content.store"
    private let mutedKey = "signal.content.muted"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "signal.content.store", qos: .utility)

    private init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        load()
    }

    func add(_ content: LearningContent) {
        queue.async {
            var list = self.contents
            list.insert(self.normalizeContent(content), at: 0)
            self.persist(list)
            DispatchQueue.main.async { StreakStore.shared.recordActivity() }
        }
    }

    func update(_ content: LearningContent) {
        queue.async {
            var list = self.contents
            if let idx = list.firstIndex(where: { $0.id == content.id }) {
                list[idx] = self.normalizeContent(content)
                self.persist(list)
            }
        }
    }

    func recordRecallOutcome(contentId: UUID, correct: Int, total: Int) {
        guard total > 0 else { return }
        let score = min(max(Double(correct) / Double(total), 0), 1)

        queue.async {
            var list = self.contents
            guard let idx = list.firstIndex(where: { $0.id == contentId }) else { return }

            var content = list[idx]
            for conceptIndex in content.concepts.indices {
                var concept = content.concepts[conceptIndex]
                let previousAttempts = concept.totalRecallAttempts
                let nextAttempts = previousAttempts + 1
                let weighted = (concept.masteryLevel * Double(previousAttempts)) + score

                concept.totalRecallAttempts = nextAttempts
                if score >= 0.7 {
                    concept.successfulRecalls += 1
                }
                concept.masteryLevel = weighted / Double(nextAttempts)
                concept.lastRecallDate = Date()
                content.concepts[conceptIndex] = concept
            }

            list[idx] = content
            self.persist(list)
        }
    }

    func all() -> [LearningContent] { contents }

    func mute(contentId: UUID) {
        queue.async {
            var list = (UserDefaults.standard.array(forKey: self.mutedKey) as? [String]) ?? []
            let id = contentId.uuidString
            if !list.contains(id) {
                list.append(id)
                UserDefaults.standard.set(list, forKey: self.mutedKey)
            }
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    func unmute(contentId: UUID) {
        queue.async {
            var list = (UserDefaults.standard.array(forKey: self.mutedKey) as? [String]) ?? []
            list.removeAll { $0 == contentId.uuidString }
            UserDefaults.standard.set(list, forKey: self.mutedKey)
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    func isMuted(contentId: UUID) -> Bool {
        (UserDefaults.standard.array(forKey: mutedKey) as? [String])?.contains(contentId.uuidString) ?? false
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? decoder.decode([LearningContent].self, from: data) {
            let (normalized, didChange) = normalizeConceptMetadata(in: decoded)
            self.contents = normalized
            if didChange, let updatedData = try? encoder.encode(normalized) {
                UserDefaults.standard.set(updatedData, forKey: key)
            }
        } else {
            self.contents = []
        }
    }

    private func normalizeConceptMetadata(in list: [LearningContent]) -> ([LearningContent], Bool) {
        var didChange = false
        let normalized = list.map { content -> LearningContent in
            let updated = normalizeContent(content)
            if updated.concepts != content.concepts {
                didChange = true
            }
            return updated
        }
        return (normalized, didChange)
    }

    private func normalizeContent(_ content: LearningContent) -> LearningContent {
        var updated = content
        updated.concepts = content.concepts.map(ConceptClassifier.enrich)
        return updated
    }

    private func persist(_ list: [LearningContent]) {
        if let data = try? encoder.encode(list) {
            UserDefaults.standard.set(data, forKey: key)
            DispatchQueue.main.async { self.contents = list }
        }
    }
}
