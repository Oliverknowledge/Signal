import Foundation
import UserNotifications

extension Notification.Name {
    static let signalOpenRecall = Notification.Name("signalOpenRecall")
    static let signalOpenPrepEvent = Notification.Name("signalOpenPrepEvent")
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private static let pendingRecallKey = "signal.pendingRecallContentId"
    private static let pendingPrepEventKey = "signal.pendingPrepEventId"

    private override init() { super.init() }

    // Present notifications while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    // Deep-link into recall when user taps a recall notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        let userInfo = response.notification.request.content.userInfo
        if let eventIdStr = userInfo["prepEventId"] as? String,
           let eventId = UUID(uuidString: eventIdStr) {
            UserDefaults.standard.set(eventIdStr, forKey: Self.pendingPrepEventKey)
            NotificationCenter.default.post(name: .signalOpenPrepEvent, object: nil, userInfo: ["prepEventId": eventId])
            completionHandler()
            return
        }
        guard let idStr = userInfo["contentId"] as? String, let uuid = UUID(uuidString: idStr) else {
            completionHandler()
            return
        }
        UserDefaults.standard.set(idStr, forKey: Self.pendingRecallKey)
        NotificationCenter.default.post(name: .signalOpenRecall, object: nil, userInfo: ["contentId": uuid])
        completionHandler()
    }

    /// Call from app when becoming active to pick up pending recall from cold start
    static func consumePendingRecallContentId() -> UUID? {
        guard let idStr = UserDefaults.standard.string(forKey: Self.pendingRecallKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: Self.pendingRecallKey)
        return UUID(uuidString: idStr)
    }

    static func consumePendingPrepEventId() -> UUID? {
        guard let idStr = UserDefaults.standard.string(forKey: Self.pendingPrepEventKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: Self.pendingPrepEventKey)
        return UUID(uuidString: idStr)
    }
}
