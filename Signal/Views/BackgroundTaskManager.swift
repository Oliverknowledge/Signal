import Foundation
import BackgroundTasks
import SwiftUI

// Refactor to allow immediate/manual execution of signal work,
// with single-flight coordination and cancellation support

final class BackgroundTaskManager {
    enum ExecutionReason {
        case backgroundRefresh
        case backgroundProcessing
        case manualTrigger
    }
    
    private actor WorkState {
        private var currentTask: Task<Int, Never>? = nil
        func tryStartOrReturnExisting(_ factory: () -> Task<Int, Never>) -> Task<Int, Never> {
            if let existing = currentTask { return existing }
            let task = factory()
            currentTask = task
            return task
        }
        func clear() {
            currentTask = nil
        }
        func cancel() {
            currentTask?.cancel()
        }
        func hasActive() -> Bool { currentTask != nil }
    }
    
    static let shared = BackgroundTaskManager()
    private init() {}

    // IMPORTANT: Add these identifiers to Info.plist under BGTaskSchedulerPermittedIdentifiers
    // <key>BGTaskSchedulerPermittedIdentifiers</key>
    // <array>
    //   <string>OliverStevenson.Signal.refresh</string>
    //   <string>OliverStevenson.Signal.processing</string>
    // </array>
    let refreshTaskIdentifier = "OliverStevenson.Signal.refresh"
    let processingTaskIdentifier = "OliverStevenson.Signal.processing"
    
    private var registered = false
    private let workState = WorkState()

    func register(appState: AppState) {
        #if DEBUG
        print("[BGTask] register(appState:) called")
        #endif
        guard !registered else { return }
        registered = true
        #if DEBUG
        print("[BGTask] Registering handlers for identifiers: refresh=\(refreshTaskIdentifier), processing=\(processingTaskIdentifier)")
        #endif
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            #if DEBUG
            print("[BGTask] BGAppRefreshTask received by system")
            #endif
            self.handleAppRefresh(task: task as! BGAppRefreshTask, appState: appState)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
            #if DEBUG
            print("[BGTask] BGProcessingTask received by system")
            #endif
            self.handleProcessing(task: task as! BGProcessingTask, appState: appState)
        }
    }

    func scheduleAppRefresh(earliestBegin: TimeInterval = 15 * 60) {
        #if DEBUG
        let minutes = Int(earliestBegin / 60)
        print("[BGTask] Scheduling app refresh in ~" + String(minutes) + " min")
        #endif
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestBegin)
        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            print("[BGTask] App refresh submitted successfully")
            #endif
        } catch {
            #if DEBUG
            print("[BGTask] Failed to schedule app refresh: \(error.localizedDescription)")
            #endif
        }
    }
    
    func scheduleProcessing(earliestBegin: TimeInterval = 30 * 60,
                            requiresNetworkConnectivity: Bool = true,
                            requiresExternalPower: Bool = false) {
        #if DEBUG
        let minutes = Int(earliestBegin / 60)
        print("[BGTask] Scheduling processing in ~" + String(minutes) + " min (requiresNetwork=\(requiresNetworkConnectivity), requiresPower=\(requiresExternalPower))")
        #endif
        let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestBegin)
        request.requiresNetworkConnectivity = requiresNetworkConnectivity
        request.requiresExternalPower = requiresExternalPower
        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            print("[BGTask] Processing task submitted successfully")
            #endif
        } catch {
            #if DEBUG
            print("[BGTask] Failed to schedule processing: \(error.localizedDescription)")
            #endif
        }
    }
    
    @discardableResult
    func performSignalWork(reason: ExecutionReason, appState: AppState) async -> Int {
        #if DEBUG
        print("[BGTask] performSignalWork start (reason=\(reason))")
        #endif
        // Delegate to the same pipeline used by foreground/background
        let count = await PendingAnalysisManager.shared.drainPendingNow(appState: appState)
        #if DEBUG
        print("[BGTask] performSignalWork finished (reason=\(reason), processed=\(count))")
        #endif
        return count
    }
    
    @discardableResult
    func triggerNow(appState: AppState) async -> Task<Int, Never> {
        #if DEBUG
        print("[BGTask] triggerNow invoked (manual trigger)")
        #endif
        let task = Task { [weak self] () -> Int in
            guard let self = self else { return 0 }
            let processed = await self.performSignalWork(reason: .manualTrigger, appState: appState)
            await self.workState.clear()
            return processed
        }
        return await workState.tryStartOrReturnExisting { task }
    }

    private func handleAppRefresh(task: BGAppRefreshTask, appState: AppState) {
        #if DEBUG
        print("[BGTask] handleAppRefresh started")
        #endif
        // Always schedule the next one
        scheduleAppRefresh()

        // Expiration cancels the active work
        task.expirationHandler = { [weak self] in
            #if DEBUG
            print("[BGTask] handleAppRefresh expirationHandler invoked — cancelling work")
            #endif
            Task { await self?.workState.cancel() }
        }

        // Orchestrate single-flight work and completion in an async context
        Task { [weak self] in
            guard let self = self else { return }
            let runningTask = Task { [weak self] () -> Int in
                guard let self = self else { return 0 }
                let processed = await self.performSignalWork(reason: .backgroundRefresh, appState: appState)
                await self.workState.clear()
                return processed
            }
            let work = await self.workState.tryStartOrReturnExisting { runningTask }
            let processed = await work.value
            #if DEBUG
            print("[BGTask] handleAppRefresh: work finished (processed=\(processed)). Marking task completed.")
            #endif
            task.setTaskCompleted(success: processed >= 0)
        }
    }
    
    private func handleProcessing(task: BGProcessingTask, appState: AppState) {
        #if DEBUG
        print("[BGTask] handleProcessing started")
        #endif
        // Always schedule the next one
        scheduleProcessing()

        // Expiration cancels the active work
        task.expirationHandler = { [weak self] in
            #if DEBUG
            print("[BGTask] handleProcessing expirationHandler invoked — cancelling work")
            #endif
            Task { await self?.workState.cancel() }
        }

        Task { [weak self] in
            guard let self = self else { return }
            let runningTask = Task { [weak self] () -> Int in
                guard let self = self else { return 0 }
                let processed = await self.performSignalWork(reason: .backgroundProcessing, appState: appState)
                await self.workState.clear()
                return processed
            }
            let work = await self.workState.tryStartOrReturnExisting { runningTask }
            let processed = await work.value
            #if DEBUG
            print("[BGTask] handleProcessing: work finished (processed=\(processed)). Marking task completed.")
            #endif
            task.setTaskCompleted(success: processed >= 0)
        }
    }
}

