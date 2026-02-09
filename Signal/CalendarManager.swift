import Foundation
import EventKit

final class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()

    private init() {}

    @MainActor
    func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    @MainActor
    func hasAuthorizedAccess() -> Bool {
        isAuthorizedStatus(authorizationStatus())
    }

    @MainActor
    func requestAccessFromSystem() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestWriteOnlyAccessToEvents()
            } catch {
                #if DEBUG
                print("[Calendar] Access request failed: \(error.localizedDescription)")
                #endif
                return false
            }
        }

        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    @MainActor
    func syncGoalEventIfAuthorized(_ goal: LearningGoal) async -> LearningGoal {
        guard hasAuthorizedAccess() else { return goal }

        let event: EKEvent
        if let existingId = goal.calendarEventIdentifier,
           let existingEvent = eventStore.event(withIdentifier: existingId) {
            event = existingEvent
        } else {
            event = EKEvent(eventStore: eventStore)
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        event.title = "Goal: \(goal.title)"
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: goal.targetDate)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate.addingTimeInterval(60 * 60 * 24)
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = true
        if event.calendar == nil {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        var syncedGoal = goal
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            syncedGoal.calendarEventIdentifier = event.eventIdentifier
        } catch {
            #if DEBUG
            print("[Calendar] Failed to save goal event: \(error.localizedDescription)")
            #endif
        }
        return syncedGoal
    }

    @MainActor
    func syncPrepEventIfAuthorized(_ event: PrepEvent) async -> PrepEvent {
        guard hasAuthorizedAccess() else { return event }

        let ekEvent: EKEvent
        if let existingId = event.calendarEventIdentifier,
           let existingEvent = eventStore.event(withIdentifier: existingId) {
            ekEvent = existingEvent
        } else {
            ekEvent = EKEvent(eventStore: eventStore)
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
        }

        ekEvent.title = prepEventTitle(event)
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: event.date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate.addingTimeInterval(60 * 60 * 24)
        ekEvent.startDate = startDate
        ekEvent.endDate = endDate
        ekEvent.isAllDay = true
        if ekEvent.calendar == nil {
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
        }

        var syncedEvent = event
        do {
            try eventStore.save(ekEvent, span: .thisEvent, commit: true)
            syncedEvent.calendarEventIdentifier = ekEvent.eventIdentifier
        } catch {
            #if DEBUG
            print("[Calendar] Failed to save prep event: \(error.localizedDescription)")
            #endif
        }
        return syncedEvent
    }

    @MainActor
    func removeGoalEventIfAuthorized(_ goal: LearningGoal) async {
        guard hasAuthorizedAccess(),
              let eventId = goal.calendarEventIdentifier,
              let event = eventStore.event(withIdentifier: eventId) else {
            return
        }

        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
        } catch {
            #if DEBUG
            print("[Calendar] Failed to remove goal event: \(error.localizedDescription)")
            #endif
        }
    }

    @MainActor
    func removePrepEventIfAuthorized(_ prepEvent: PrepEvent) async {
        guard hasAuthorizedAccess(),
              let eventId = prepEvent.calendarEventIdentifier,
              let event = eventStore.event(withIdentifier: eventId) else {
            return
        }

        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
        } catch {
            #if DEBUG
            print("[Calendar] Failed to remove prep event: \(error.localizedDescription)")
            #endif
        }
    }

    @MainActor
    private func isAuthorizedStatus(_ status: EKAuthorizationStatus) -> Bool {
        if status == .authorized {
            return true
        }
        if #available(iOS 17.0, *) {
            return status == .fullAccess || status == .writeOnly
        }
        return false
    }

    private func prepEventTitle(_ event: PrepEvent) -> String {
        switch event.type {
        case .interview:
            return "Interview\(titleSuffix(company: event.metadata.company, role: event.metadata.role))"
        case .exam:
            if let examType = event.metadata.examType, !examType.isEmpty {
                return "Assessment: \(examType)"
            }
            if let domain = event.metadata.domain, !domain.isEmpty {
                return "Assessment: \(domain)"
            }
            return "Assessment"
        case .deadline:
            return "Application deadline\(titleSuffix(company: event.metadata.company, role: event.metadata.role))"
        }
    }

    private func titleSuffix(company: String?, role: String?) -> String {
        let trimmedCompany = company?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedRole = role?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCompany.isEmpty && !trimmedRole.isEmpty {
            return " – \(trimmedCompany) (\(trimmedRole))"
        }
        if !trimmedCompany.isEmpty {
            return " – \(trimmedCompany)"
        }
        if !trimmedRole.isEmpty {
            return " – \(trimmedRole)"
        }
        return ""
    }

    @MainActor
    func deniedOrRestricted() -> Bool {
        let status = authorizationStatus()
        switch status {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    @MainActor
    func needsSystemPermissionPrompt() -> Bool {
        authorizationStatus() == .notDetermined
    }
}
