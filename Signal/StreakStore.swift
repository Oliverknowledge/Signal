import Foundation
import Combine

/// Tracks daily learning activity for streak calculation.
/// Increments streak when user does learning activity (recall, add content) on consecutive days.
final class StreakStore: ObservableObject {
    static let shared = StreakStore()
        
    @Published private(set) var currentStreak: Int = 0
    
    private let lastActivityKey = "signal.streak.lastActivity"
    private let streakKey = "signal.streak.current"
    
    private init() {
        load()
    }
    
    /// Call when user completes a recall session, adds content, or does other learning activity.
    func recordActivity() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let lastDate = UserDefaults.standard.object(forKey: lastActivityKey) as? Date else {
            // First activity ever
            UserDefaults.standard.set(today, forKey: lastActivityKey)
            UserDefaults.standard.set(1, forKey: streakKey)
            DispatchQueue.main.async { self.currentStreak = 1 }
            return
        }
        
        let lastDay = calendar.startOfDay(for: lastDate)
        let daysSinceLast = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        
        if daysSinceLast == 0 {
            // Already did activity today, no change
            return
        } else if daysSinceLast == 1 {
            // Consecutive day: increment streak
            let newStreak = (UserDefaults.standard.integer(forKey: streakKey)) + 1
            UserDefaults.standard.set(today, forKey: lastActivityKey)
            UserDefaults.standard.set(newStreak, forKey: streakKey)
            DispatchQueue.main.async { self.currentStreak = newStreak }
        } else {
            // Gap: reset to 1
            UserDefaults.standard.set(today, forKey: lastActivityKey)
            UserDefaults.standard.set(1, forKey: streakKey)
            DispatchQueue.main.async { self.currentStreak = 1 }
        }
    }
    
    private func load() {
        let lastDate = UserDefaults.standard.object(forKey: lastActivityKey) as? Date
        let storedStreak = UserDefaults.standard.integer(forKey: streakKey)
        
        guard let last = lastDate else {
            currentStreak = 0
            return
        }
        
        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: Date())
        let daysSinceLast = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        
        if daysSinceLast == 0 {
            currentStreak = max(1, storedStreak)
        } else if daysSinceLast == 1 {
            currentStreak = storedStreak
        } else {
            currentStreak = 0
        }
    }
}
