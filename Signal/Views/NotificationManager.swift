import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}
    private let prepEventIdKey = "prepEventId"
    private let contentIdKey = "contentId"
    private let prepNotificationPrefix = "prep-event-"
    private let prepReadyPrefix = "ready-"
    private let recallPrefix = "recall-"

    func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                return granted
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func schedulePrepReadyNotification(contentTitle: String, contentId: UUID, event: PrepEvent) async {
        guard AppStorage.smartNotificationsEnabled else { return }
        guard AppStorage.prepReadyNudgesEnabled else { return }
        guard event.date >= Calendar.current.startOfDay(for: Date()) else { return }
        let granted = await ensureAuthorization()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Prep ready"
        let subtitle = contentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subtitle.isEmpty {
            content.subtitle = subtitle
        }
        content.body = prepReadyBody(for: event)
        content.sound = .default
        content.userInfo = [
            prepEventIdKey: event.id.uuidString,
            contentIdKey: contentId.uuidString
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let identifier = "\(prepReadyPrefix)\(contentId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Silently ignore scheduling errors
        }
    }

    /// Preferred recall reminder delay based on selected learning mode.
    static func preferredRecallDelay() -> TimeInterval {
        switch LearningMode.fromStored(AppStorage.learningModeRaw) {
        case .assessmentExamPrep:
            return 2 * 3600    // 2h: tighter cadence for exam-style practice
        case .interviewPrep:
            return 12 * 3600   // 12h: frequent but not overwhelming
        case .generalLearning:
            return 24 * 3600   // 24h: default lighter cadence
        }
    }

    func scheduleRecallReminder(contentTitle: String, contentId: UUID, delay: TimeInterval? = nil) async {
        guard AppStorage.smartNotificationsEnabled else { return }
        let granted = await ensureAuthorization()
        guard granted else { return }

        let now = Date()
        let fireDate: Date = {
            if let delay, delay > 0 {
                return now.addingTimeInterval(delay)
            }
            return Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(24 * 3600)
        }()
        guard fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Recall reminder"
        let trimmedTitle = contentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            content.subtitle = trimmedTitle
        }
        content.body = "Time to review what you learned."
        content.sound = .default
        content.userInfo = [contentIdKey: contentId.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "\(recallPrefix)\(contentId.uuidString)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            // Silently ignore scheduling errors
        }
    }

    func cancelRecallNotifications(contentId: UUID) {
        let identifiers = [
            "\(prepReadyPrefix)\(contentId.uuidString)",
            "\(recallPrefix)\(contentId.uuidString)"
        ]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func reschedulePrepEventNotifications(events: [PrepEvent]) async {
        await clearPrepEventNotifications()
        guard AppStorage.smartNotificationsEnabled else { return }
        let granted = await ensureAuthorization()
        guard granted else { return }

        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let upcoming = events
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }

        for event in upcoming {
            await schedulePrepEventNotification(for: event, daysBefore: 7)
            await schedulePrepEventNotification(for: event, daysBefore: 3)
            await schedulePrepEventNotification(for: event, daysBefore: 1)
        }
    }

    private func schedulePrepEventNotification(for event: PrepEvent, daysBefore: Int) async {
        guard let fireDate = prepNotificationDate(eventDate: event.date, daysBefore: daysBefore) else { return }
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = event.type.displayName
        content.body = notificationBody(for: event, daysBefore: daysBefore)
        content.sound = .default
        content.userInfo = [prepEventIdKey: event.id.uuidString]

        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let identifier = "\(prepNotificationPrefix)\(event.id.uuidString)-\(daysBefore)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Silently ignore scheduling errors
        }
    }

    private func prepNotificationDate(eventDate: Date, daysBefore: Int) -> Date? {
        let calendar = Calendar.current
        let eventDay = calendar.startOfDay(for: eventDate)
        guard let targetDay = calendar.date(byAdding: .day, value: -daysBefore, to: eventDay) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components)
    }

    private func notificationBody(for event: PrepEvent, daysBefore: Int) -> String {
        switch daysBefore {
        case 7:
            return "\(event.type.displayName) next week. Tap to prepare."
        case 3:
            return "3 days until your \(event.type.notificationNoun)."
        default:
            return "Tomorrow is your \(event.type.notificationNoun)."
        }
    }

    func clearPrepEventNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prepNotificationPrefix) }
        if !pendingIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIds)
        }

        let delivered = await center.deliveredNotifications()
        let deliveredIds = delivered
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(prepNotificationPrefix) }
        if !deliveredIds.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIds)
        }
    }

    func clearPrepReadyNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prepReadyPrefix) || $0.hasPrefix(recallPrefix) }
        if !pendingIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIds)
        }

        let delivered = await center.deliveredNotifications()
        let deliveredIds = delivered
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(prepReadyPrefix) || $0.hasPrefix(recallPrefix) }
        if !deliveredIds.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIds)
        }
    }

    private func prepReadyBody(for event: PrepEvent) -> String {
        return "New prep ready for your \(event.type.notificationNoun). Tap to prepare."
    }
}
