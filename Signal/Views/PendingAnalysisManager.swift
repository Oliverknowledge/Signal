import Foundation
import SwiftUI
import BackgroundTasks

// Drains URLs queued by the Share Extension (UserDefaults app group) and
// submits them through the same analysis pipeline as the paste flow.
//
// Behavior:
// - Only runs when onboarding has been completed (goal context available).
// - Processes URLs sequentially to avoid overwhelming the pipeline.
// - On success, removes the URL from the pending queue.
// - On failure, leaves the URL in the queue to retry on next activation.
// - No UI navigation here; ContentStore is updated by CaptureService.
final class PendingAnalysisManager {
    static let shared = PendingAnalysisManager()
    private init() {}

    private let appGroupSuite = "group.OliverStevenson.Signal"
    private let pendingKey = "pendingAnalysis"
    private var isDraining = false

    // DEBUG/Diagnostics: current queue count
    func pendingQueueCount() -> Int {
        guard let ud = UserDefaults(suiteName: appGroupSuite) else { return 0 }
        return ud.stringArray(forKey: pendingKey)?.count ?? 0
    }

    func drainPending(appState: AppState) {
        Task { _ = await self.drainPendingNow(appState: appState) }
    }

    @discardableResult
    func drainPendingNow(appState: AppState) async -> Int {
        // Require onboarding to be complete
        guard AppStorage.hasOnboarded, AppStorage.selectedGoalId != nil else {
            #if DEBUG
            print("[PendingAnalysis] Skipping drain: onboarding incomplete or no goal selected")
            #endif
            return 0
        }
        guard !isDraining else {
            #if DEBUG
            print("[PendingAnalysis] Skipping drain: already in progress")
            #endif
            return 0
        }
        guard let ud = UserDefaults(suiteName: appGroupSuite) else {
            #if DEBUG
            print("[PendingAnalysis] ERROR: App Group UserDefaults not available for suite: \(appGroupSuite)")
            #endif
            return 0
        }

        if Task.isCancelled { return -1 }
        let pending = ud.stringArray(forKey: pendingKey) ?? []
        #if DEBUG
        print("[PendingAnalysis] Queue count at start: \(pending.count)")
        #endif
        guard !pending.isEmpty else { return 0 }

        isDraining = true
        var successCount = 0
        var remaining = ud.stringArray(forKey: pendingKey) ?? []

        for urlString in pending {
            if Task.isCancelled {
                isDraining = false
                return -1
            }
            guard let url = URL(string: urlString), let scheme = url.scheme, let host = url.host, ["http","https"].contains(scheme.lowercased()), !host.isEmpty else {
                remaining.removeAll { $0 == urlString }
                ud.set(remaining, forKey: pendingKey)
                continue
            }
            do {
                _ = try await CaptureService.shared.submit(urlString: urlString, appState: appState)
                remaining.removeAll { $0 == urlString }
                ud.set(remaining, forKey: pendingKey)
                successCount += 1
            } catch is CancellationError {
                isDraining = false
                return -1
            } catch {
                #if DEBUG
                print("[PendingAnalysis] Failed to analyze: \(urlString). Error: \(error.localizedDescription)")
                #endif
            }
        }

        if Task.isCancelled {
            isDraining = false
            return -1
        }

        if successCount > 0 {
            #if DEBUG
            print("[PendingAnalysis] Drain complete. Processed \(successCount). Remaining \(remaining.count).")
            #endif
        } else {
            #if DEBUG
            print("[PendingAnalysis] Drain complete. No items processed.")
            #endif
        }
        isDraining = false
        return successCount
    }
}
