import SwiftUI

struct RootView: View {
    @State private var hasOnboarded: Bool = AppStorage.hasOnboarded
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if hasOnboarded {
                MainContainerView()
            } else {
                OnboardingView(onFinished: { result in
                    completeOnboarding(result: result, appState: appState)
                    hasOnboarded = true
                })
            }
        }
        .onAppear {
            hasOnboarded = AppStorage.hasOnboarded
        }
    }
}

// A simple container that shows your existing app structure.
// We keep this minimal and do not change unrelated styling.
struct MainContainerView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
