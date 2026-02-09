import SwiftUI
import Combine

struct CaptureCenterView: View {
    @State private var urlText: String = ""
    @State private var showHelp = false
    @State private var captureHistory: [CapturedItem] = []
    @EnvironmentObject var appState: AppState
    @State private var showingOnboarding: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.primaryBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        captureBox
                        tips
                        history
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Capture Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHelp.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.Colors.primaryAccent)
                    }
                }
            }
            .sheet(isPresented: $showHelp) {
                CaptureHelpView()
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView { result in
                    completeOnboarding(result: result, appState: appState)
                    showingOnboarding = false
                }
            }
            .onAppear {
                ensureOnboardingFlow {
                    showingOnboarding = true
                }
            }
        }
    }
    
    private var captureBox: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Paste a link to analyze")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textPrimary)
            
            HStack(spacing: Theme.Spacing.sm) {
                TextField("https://...", text: $urlText)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textOnLight)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                
                Button {
                    if !AppStorage.hasOnboarded || AppStorage.selectedGoalId == nil {
                        showingOnboarding = true
                        return
                    }
                    Task {
                        let submittedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !submittedURL.isEmpty else { return }
                        // Optimistic UI: add pending row
                        captureHistory.insert(CapturedItem(url: submittedURL, title: "Queued", status: .pending), at: 0)
                        urlText = ""
                        do {
                            let result = try await CaptureService.shared.submit(urlString: submittedURL, appState: appState)
                            // Update the latest matching item
                            if let idx = captureHistory.firstIndex(where: { $0.url == submittedURL }) {
                                captureHistory[idx].title = result.content.title
                                switch result.decision {
                                case .triggered:
                                    captureHistory[idx].status = .completed
                                case .ignored:
                                    captureHistory[idx].status = .belowThreshold
                                }
                            }
                        } catch {
                            if let idx = captureHistory.firstIndex(where: { $0.url == submittedURL }) {
                                captureHistory[idx].status = .failed
                                captureHistory[idx].title = "Failed to analyze"
                            }
                        }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.primaryAccent)
                        .cornerRadius(Theme.CornerRadius.md)
                }
                .disabled(urlText.isEmpty || !isValidURL(urlText))
                .opacity((urlText.isEmpty || !isValidURL(urlText)) ? 0.5 : 1.0)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var tips: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Tips")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)
            
            HStack(spacing: Theme.Spacing.md) {
                tip(icon: "square.and.arrow.up", text: "Use the iOS Share Sheet from any app")
                tip(icon: "sparkles", text: "Signal ignores low-value content to protect focus")
            }
            
            HStack(spacing: Theme.Spacing.md) {
                tip(icon: "calendar", text: "Scheduled reviews appear in Review Schedule")
                tip(icon: "bell", text: "Smart notifications avoid interruptions")
            }
        }
    }
    
    private func tip(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.primaryAccent)
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textOnLight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var history: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recent Captures")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)
            
            ForEach(captureHistory) { item in
                CapturedItemRow(item: item)
            }
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string), let scheme = url.scheme, let host = url.host else { return false }
        return ["http", "https"].contains(scheme.lowercased()) && !host.isEmpty
    }
}

struct CapturedItemRow: View {
    let item: CapturedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: item.sourceIcon)
                    .foregroundColor(Theme.Colors.primaryAccent)
                Text(item.sourceLabel)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                Spacer()
                Text(item.status.rawValue)
                    .font(Theme.Typography.caption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
            }
            
            Text(item.title)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textOnLight)
                .lineLimit(2)
            
            Text(item.url)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending: return Theme.Colors.evaluationMedium
        case .completed: return Theme.Colors.success
        case .failed: return .red
        case .belowThreshold: return Theme.Colors.evaluationLow
        }
    }
}

struct CapturedItem: Identifiable, Hashable {
    enum Status: String { case pending = "Queued", completed = "Analyzed", failed = "Failed", belowThreshold = "Ignored" }
    let id = UUID()
    let url: String
    var title: String
    var status: Status
    
    var sourceIcon: String { url.contains("youtube.com") ? "play.rectangle.fill" : "doc.text.fill" }
    var sourceLabel: String { url.contains("youtube.com") ? "YouTube" : "Web" }
}

struct CaptureHelpView: View {
    var body: some View {
        ZStack {
            Theme.Colors.primaryBackground.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primaryAccent)
                
                Text("How to Capture Content")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    helpRow("Open any app (Safari, YouTube, Medium, X)")
                    helpRow("Tap the Share button")
                    helpRow("Choose Signal from the share sheet")
                    helpRow("We’ll queue the link for analysis")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.md)
                
                Text("Tip: Enable Signal in the share sheet via ‘More’ if you don't see it.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .padding(Theme.Spacing.md)
        }
    }
    
    private func helpRow(_ text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.Colors.success)
            Text(text).font(Theme.Typography.callout).foregroundColor(Theme.Colors.textOnLight)
        }
    }
}

#Preview {
    CaptureCenterView()
}
