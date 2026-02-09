import Combine
import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView().accentColor(Palette.primary)
    }
}

final class GlobalCaptureCoordinator: ObservableObject {
    @Published var showingAddContent = false

    func openAddContent() {
        showingAddContent = true
    }
}

struct GlobalCaptureToolbarButton: View {
    @EnvironmentObject var captureCoordinator: GlobalCaptureCoordinator

    var body: some View {
        Button {
            captureCoordinator.openAddContent()
        } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(Palette.primary)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var captureCoordinator = GlobalCaptureCoordinator()
    @State private var selectedTab = 0
    
    private var showRecallSheet: Binding<Bool> {
        Binding(
            get: { appState.pendingRecallContentId != nil },
            set: { if !$0 { appState.pendingRecallContentId = nil } }
        )
    }

    private var showPrepEventSheet: Binding<Bool> {
        Binding(
            get: { appState.pendingPrepEventId != nil },
            set: { if !$0 { appState.pendingPrepEventId = nil } }
        )
    }
    
    private var pendingRecallContent: LearningContent? {
        guard let id = appState.pendingRecallContentId else { return nil }
        return ContentStore.shared.all().first { $0.id == id }
    }

    private var pendingPrepEvent: PrepEvent? {
        guard let id = appState.pendingPrepEventId else { return nil }
        return appState.prepEvents.first { $0.id == id }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .environmentObject(captureCoordinator)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            InsightsView()
                .environmentObject(captureCoordinator)
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            RecallView()
                .environmentObject(captureCoordinator)
                .tabItem {
                    Label("Recall", systemImage: "brain.head.profile")
                }
                .tag(2)
            
            ReviewScheduleView()
                .environmentObject(captureCoordinator)
                .tabItem {
                    Label("Review", systemImage: "calendar")
                }
                .tag(3)
            
            SettingsView()
                .environmentObject(captureCoordinator)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(Palette.primary)
        .onReceive(NotificationCenter.default.publisher(for: .signalOpenRecall)) { notification in
            if let uuid = notification.userInfo?["contentId"] as? UUID {
                appState.pendingRecallContentId = uuid
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .signalOpenPrepEvent)) { notification in
            if let uuid = notification.userInfo?["prepEventId"] as? UUID {
                appState.pendingPrepEventId = uuid
            }
        }
        .fullScreenCover(isPresented: showRecallSheet, onDismiss: { appState.pendingRecallContentId = nil }) {
            recallSheetContent
        }
        .sheet(isPresented: showPrepEventSheet, onDismiss: { appState.pendingPrepEventId = nil }) {
            prepEventSheetContent
        }
        .sheet(isPresented: $captureCoordinator.showingAddContent) {
            AddContentView()
                .environmentObject(appState)
        }
    }
    
    @ViewBuilder
    private var recallSheetContent: some View {
        if let content = pendingRecallContent {
            RecallSessionView(content: content)
        } else {
            Color.clear
                .onAppear { appState.pendingRecallContentId = nil }
        }
    }

    @ViewBuilder
    private var prepEventSheetContent: some View {
        if let event = pendingPrepEvent {
            EventPrepView(event: event)
        } else {
            Color.clear
                .onAppear { appState.pendingPrepEventId = nil }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
