import Foundation

// MARK: - AppStorage wrapper
// A small wrapper around UserDefaults for onboarding and goal selection state.
// Note: This intentionally uses the name AppStorage per the requirement.
// If you need SwiftUI's @AppStorage property wrapper, reference it as SwiftUI.AppStorage.

enum AppStorage {
    // Keys
    private enum Keys {
        static let hasOnboarded = "hasOnboarded"
        static let selectedFieldId = "selectedFieldId"
        static let selectedFieldTitle = "selectedFieldTitle"
        static let selectedGoalId = "selectedGoalId"
        static let selectedGoalTitle = "selectedGoalTitle"
        static let selectedGoalDescription = "selectedGoalDescription"
        static let careerStage = "careerStage"
        static let interventionPolicy = "signal.intervention.policy"
        static let learningMode = "learningMode"
        static let smartNotificationsEnabled = "smartNotificationsEnabled"
        static let prepReadyNudgesEnabled = "prepReadyNudgesEnabled"
        static let goalCalendarSyncEnabled = "goalCalendarSyncEnabled"
        static let knownConcepts = "knownConcepts"
        static let weakConcepts = "weakConcepts"
        static let learningGoals = "learningGoals"
        static let prepEvents = "prepEvents"
    }

    private static var defaults: UserDefaults { .standard }
    private static let appGroupSuite = "group.OliverStevenson.Signal"
    private static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroupSuite) }

    // Required properties
    static var hasOnboarded: Bool {
        get { defaults.bool(forKey: Keys.hasOnboarded) }
        set {
            defaults.set(newValue, forKey: Keys.hasOnboarded)
            sharedDefaults?.set(newValue, forKey: Keys.hasOnboarded)
        }
    }

    static var selectedGoalId: String? {
        get { defaults.string(forKey: Keys.selectedGoalId) }
        set {
            defaults.set(newValue, forKey: Keys.selectedGoalId)
            if let value = newValue {
                sharedDefaults?.set(value, forKey: Keys.selectedGoalId)
            } else {
                sharedDefaults?.removeObject(forKey: Keys.selectedGoalId)
            }
        }
    }

    static var selectedFieldId: String? {
        get { defaults.string(forKey: Keys.selectedFieldId) }
        set {
            defaults.set(newValue, forKey: Keys.selectedFieldId)
            if let value = newValue {
                sharedDefaults?.set(value, forKey: Keys.selectedFieldId)
            } else {
                sharedDefaults?.removeObject(forKey: Keys.selectedFieldId)
            }
        }
    }

    static var selectedFieldTitle: String? {
        get { defaults.string(forKey: Keys.selectedFieldTitle) }
        set { defaults.set(newValue, forKey: Keys.selectedFieldTitle) }
    }

    static var selectedGoalTitle: String? {
        get { defaults.string(forKey: Keys.selectedGoalTitle) }
        set {
            defaults.set(newValue, forKey: Keys.selectedGoalTitle)
            if let value = newValue {
                sharedDefaults?.set(value, forKey: Keys.selectedGoalTitle)
            } else {
                sharedDefaults?.removeObject(forKey: Keys.selectedGoalTitle)
            }
        }
    }

    static var selectedGoalDescription: String? {
        get { defaults.string(forKey: Keys.selectedGoalDescription) }
        set { defaults.set(newValue, forKey: Keys.selectedGoalDescription) }
    }

    /// Career transition stage (logging only; defaults to retraining).
    static var careerStage: career_stage {
        get {
            if let raw = defaults.string(forKey: Keys.careerStage),
               let stage = career_stage(rawValue: raw) {
                return stage
            }
            return .retraining
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.careerStage) }
    }

    /// Intervention policy preference (string-backed; default "focused").
    static var interventionPolicy: String {
        get { defaults.string(forKey: Keys.interventionPolicy) ?? "focused" }
        set { defaults.set(newValue, forKey: Keys.interventionPolicy) }
    }

    /// Learning mode (Interview Prep / Assessment / Exam Prep / General Learning).
    static var learningModeRaw: String? {
        get { defaults.string(forKey: Keys.learningMode) }
        set { defaults.set(newValue, forKey: Keys.learningMode) }
    }

    /// Controls user-facing Signal reminders.
    /// Defaults to true when unset.
    static var smartNotificationsEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.smartNotificationsEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.smartNotificationsEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.smartNotificationsEnabled) }
    }

    /// Optional: nudge when new prep content is ready for the nearest upcoming event.
    /// Defaults to false when unset.
    static var prepReadyNudgesEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.prepReadyNudgesEnabled) == nil {
                return false
            }
            return defaults.bool(forKey: Keys.prepReadyNudgesEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.prepReadyNudgesEnabled) }
    }

    /// Controls whether Signal should sync prep events to Apple Calendar.
    /// Defaults to false until user enables it.
    static var goalCalendarSyncEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.goalCalendarSyncEnabled) == nil {
                return false
            }
            return defaults.bool(forKey: Keys.goalCalendarSyncEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.goalCalendarSyncEnabled) }
    }

    // Concept arrays storage (MVP)
    static func setKnownConcepts(_ concepts: [String]) {
        defaults.set(concepts, forKey: Keys.knownConcepts)
    }

    static func setWeakConcepts(_ concepts: [String]) {
        defaults.set(concepts, forKey: Keys.weakConcepts)
    }

    static func knownConcepts() -> [String] {
        defaults.stringArray(forKey: Keys.knownConcepts) ?? []
    }

    static func weakConcepts() -> [String] {
        defaults.stringArray(forKey: Keys.weakConcepts) ?? []
    }

    // Learning goals storage
    static var learningGoals: [LearningGoal] {
        get {
            guard let data = defaults.data(forKey: Keys.learningGoals) else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode([LearningGoal].self, from: data)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(newValue) {
                defaults.set(data, forKey: Keys.learningGoals)
            } else {
                defaults.removeObject(forKey: Keys.learningGoals)
            }
        }
    }

    static var prepEvents: [PrepEvent] {
        get {
            guard let data = defaults.data(forKey: Keys.prepEvents) else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode([PrepEvent].self, from: data)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(newValue) {
                defaults.set(data, forKey: Keys.prepEvents)
            } else {
                defaults.removeObject(forKey: Keys.prepEvents)
            }
        }
    }

    // Reset only onboarding-related keys (DEBUG helper)
    static func resetOnboarding() {
        defaults.set(false, forKey: Keys.hasOnboarded)
        defaults.removeObject(forKey: Keys.selectedFieldId)
        defaults.removeObject(forKey: Keys.selectedFieldTitle)
        defaults.removeObject(forKey: Keys.selectedGoalId)
        defaults.removeObject(forKey: Keys.selectedGoalTitle)
        defaults.removeObject(forKey: Keys.selectedGoalDescription)
        defaults.removeObject(forKey: Keys.careerStage)
        defaults.removeObject(forKey: Keys.learningMode)
        defaults.removeObject(forKey: Keys.prepEvents)
        defaults.removeObject(forKey: Keys.knownConcepts)
        defaults.removeObject(forKey: Keys.weakConcepts)
        sharedDefaults?.set(false, forKey: Keys.hasOnboarded)
        sharedDefaults?.removeObject(forKey: Keys.selectedFieldId)
        sharedDefaults?.removeObject(forKey: Keys.selectedGoalId)
    }

    static func syncToAppGroup() {
        guard let sharedDefaults else { return }
        sharedDefaults.set(hasOnboarded, forKey: Keys.hasOnboarded)
        if let fieldId = selectedFieldId {
            sharedDefaults.set(fieldId, forKey: Keys.selectedFieldId)
        } else {
            sharedDefaults.removeObject(forKey: Keys.selectedFieldId)
        }
        if let goalId = selectedGoalId {
            sharedDefaults.set(goalId, forKey: Keys.selectedGoalId)
        } else {
            sharedDefaults.removeObject(forKey: Keys.selectedGoalId)
        }
        if let goalTitle = selectedGoalTitle {
            sharedDefaults.set(goalTitle, forKey: Keys.selectedGoalTitle)
        } else {
            sharedDefaults.removeObject(forKey: Keys.selectedGoalTitle)
        }
    }
}

// MARK: - Analysis context helpers
// Use these helpers when building the /api/analyze payload.

struct AnalysisContext {
    // Role transition context (current_role → target_role).
    let goalId: String
    let goalDescription: String
    let careerStage: career_stage
    let knownConcepts: [String]
    let weakConcepts: [String]
}

extension AppStorage {
    // Returns nil if a goal hasn't been selected yet.
    static func currentAnalysisContext() -> AnalysisContext? {
        guard let goalId = selectedGoalId, let desc = selectedGoalDescription else { return nil }
        let known = knownConcepts()
        let weak = weakConcepts()
        return AnalysisContext(goalId: goalId, goalDescription: desc, careerStage: careerStage, knownConcepts: known, weakConcepts: weak)
    }
}
