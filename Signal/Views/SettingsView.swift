import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var captureCoordinator: GlobalCaptureCoordinator
    @ObservedObject private var recallStore = RecallSessionStore.shared
    @State private var notificationsEnabled = AppStorage.smartNotificationsEnabled
    @State private var prepReadyNudgesEnabled = AppStorage.prepReadyNudgesEnabled
    @State private var interventionPolicy = AppStorage.interventionPolicy
    @State private var goalCalendarSyncEnabled = AppStorage.goalCalendarSyncEnabled
    @State private var showingGoals = false
    @State private var showingPrepEvents = false
    @State private var showingCalendarExplainer = false
    @State private var showingCalendarAccessAlert = false

    private var upcomingPrepEvents: [PrepEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return appState.prepEvents
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
    }

    private var weeklyRecallSummary: WeeklyRecallSummary {
        recallStore.weeklySummary()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.primaryBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Learning Mode
                        learningModeSection

                        // Intervention Policy
                        interventionPolicySection
                        
                        // Goals
                        goalsSection

                        // Prep Events
                        prepEventsSection

                        // Calendar Sync
                        calendarSyncSection
                        
                        // Notifications
                        notificationsSection
                        
                        // Data
                        dataSection
                        
                        // About
                        aboutSection
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingGoals) {
                GoalsView()
            }
            .sheet(isPresented: $showingPrepEvents) {
                PrepEventsView()
            }
            .sheet(isPresented: $showingCalendarExplainer) {
                CalendarPermissionExplainerView(
                    onCancel: {
                        showingCalendarExplainer = false
                        goalCalendarSyncEnabled = false
                        AppStorage.goalCalendarSyncEnabled = false
                    },
                    onContinue: {
                        showingCalendarExplainer = false
                        Task { await requestCalendarAccessAfterExplainer() }
                    }
                )
            }
            .alert("Calendar Access Needed", isPresented: $showingCalendarAccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow calendar access in iOS Settings to sync prep events.")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    GlobalCaptureToolbarButton()
                }
            }
        }
    }
    
    private var learningModeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Learning Mode")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)
            
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(LearningMode.allCases, id: \.self) { mode in
                    Button {
                        appState.learningMode = mode
                        AppStorage.learningModeRaw = mode.rawValue
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(mode.rawValue)
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Theme.Colors.textOnLight)
                                    .fontWeight(.semibold)
                                
                                Text(mode.description)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                            
                            Spacer()
                            
                            if appState.learningMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.Colors.primaryAccent)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(
                            appState.learningMode == mode ?
                            Theme.Colors.primaryAccent.opacity(0.1) :
                            Theme.Colors.contentSurface
                        )
                        .cornerRadius(Theme.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(
                                    appState.learningMode == mode ?
                                    Theme.Colors.primaryAccent :
                                    Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                }
            }
        }
    }
    
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Learning Goals")
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    showingGoals = true
                } label: {
                    Text("Manage")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
            }

            GoalMeasurementCard(summary: weeklyRecallSummary)
            
            if appState.learningGoals.isEmpty {
                Text("No goals set. Add goals to define your long-term intent.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.contentSurface)
                    .cornerRadius(Theme.CornerRadius.md)
            } else {
                ForEach(appState.learningGoals) { goal in
                    GoalCard(goal: goal)
                }
            }
        }
    }

    private var calendarSyncSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Calendar")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)

            Toggle(isOn: Binding(
                get: { goalCalendarSyncEnabled },
                set: { handleCalendarSyncToggle($0) }
            )) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Sync Events to Apple Calendar")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textOnLight)

                    Text("Keep prep events in sync with Calendar when enabled.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            .tint(Theme.Colors.primaryAccent)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.contentSurface)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
    
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Notifications")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)

            Toggle(isOn: Binding(
                get: { notificationsEnabled },
                set: { newValue in
                    notificationsEnabled = newValue
                    AppStorage.smartNotificationsEnabled = newValue
                    if !newValue {
                        Task {
                            await NotificationManager.shared.clearPrepEventNotifications()
                            await NotificationManager.shared.clearPrepReadyNotifications()
                        }
                    } else {
                        Task {
                            await NotificationManager.shared.reschedulePrepEventNotifications(events: appState.prepEvents)
                        }
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Event Reminders")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textOnLight)

                    Text("Get reminders 7, 3, and 1 days before interviews, exams, or deadlines.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            .tint(Theme.Colors.primaryAccent)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.contentSurface)
            .cornerRadius(Theme.CornerRadius.md)

            Toggle(isOn: Binding(
                get: { prepReadyNudgesEnabled },
                set: { newValue in
                    prepReadyNudgesEnabled = newValue
                    AppStorage.prepReadyNudgesEnabled = newValue
                    if !newValue {
                        Task { await NotificationManager.shared.clearPrepReadyNotifications() }
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Also nudge me when prep is ready")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textOnLight)

                    Text("Only when new prep is triggered for your nearest event.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            .tint(Theme.Colors.primaryAccent)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.contentSurface)
            .cornerRadius(Theme.CornerRadius.md)
            .disabled(!notificationsEnabled)
            .opacity(notificationsEnabled ? 1 : 0.6)
        }
    }

    private var prepEventsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Prep Events")
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Button {
                    showingPrepEvents = true
                } label: {
                    Text("Manage")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
            }

            if upcomingPrepEvents.isEmpty {
                Text("No upcoming events yet.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.contentSurface)
                    .cornerRadius(Theme.CornerRadius.md)
            } else {
                ForEach(upcomingPrepEvents.prefix(2)) { event in
                    prepEventRow(event)
                }
            }

            Text("Interviews, assessments, and deadlines are the only urgency drivers.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.contentSurface)
                .cornerRadius(Theme.CornerRadius.md)
        }
    }

    private func prepEventRow(_ event: PrepEvent) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: event.type.systemImage)
                .foregroundColor(Theme.Colors.primaryAccent)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.primaryAccent.opacity(0.12))
                .cornerRadius(Theme.CornerRadius.sm)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(event.type.displayName)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textOnLight)

                if let summary = prepEventSummary(event) {
                    Text(summary)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(shortDate(event.date))
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.contentSurface)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private func prepEventSummary(_ event: PrepEvent) -> String? {
        var parts: [String] = []
        if let company = event.metadata.company, !company.isEmpty { parts.append(company) }
        if let role = event.metadata.role, !role.isEmpty { parts.append(role) }
        if event.type == .exam, let examType = event.metadata.examType, !examType.isEmpty { parts.append(examType) }
        if event.type == .exam, let domain = event.metadata.domain, !domain.isEmpty { parts.append(domain) }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Data & Privacy")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)
            
            VStack(spacing: Theme.Spacing.sm) {
                NavigationLink(destination: CaptureCenterView()) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .foregroundColor(Theme.Colors.primaryAccent)
                        Text("Capture Center")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textOnLight)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.contentSurface)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("About")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Signal")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.md)
        }
    }
    

    private var interventionPolicySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Intervention Policy")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(interventionPolicyOptions, id: \.value) { option in
                    Button {
                        interventionPolicy = option.value
                        AppStorage.interventionPolicy = option.value
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(option.title)
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Theme.Colors.textOnLight)
                                    .fontWeight(.semibold)

                                Text(option.description)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textMuted)
                            }

                            Spacer()

                            if interventionPolicy == option.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.Colors.primaryAccent)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(
                            interventionPolicy == option.value ?
                            Theme.Colors.primaryAccent.opacity(0.1) :
                            Theme.Colors.contentSurface
                        )
                        .cornerRadius(Theme.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(
                                    interventionPolicy == option.value ?
                                    Theme.Colors.primaryAccent :
                                    Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                }
            }
        }
    }

    private var interventionPolicyOptions: [(value: String, title: String, description: String)] {
        [
            (
                value: "focused",
                title: "Focused",
                description: "Fewer interruptions. Only the most important moments."
            ),
            (
                value: "aggressive",
                title: "Aggressive",
                description: "More frequent interruptions to keep you moving."
            )
        ]
    }

    private func handleCalendarSyncToggle(_ enabled: Bool) {
        if !enabled {
            goalCalendarSyncEnabled = false
            AppStorage.goalCalendarSyncEnabled = false
            return
        }

        Task { @MainActor in
            if CalendarManager.shared.hasAuthorizedAccess() {
                await enableCalendarSync()
            } else if CalendarManager.shared.needsSystemPermissionPrompt() {
                goalCalendarSyncEnabled = false
                showingCalendarExplainer = true
            } else {
                goalCalendarSyncEnabled = false
                AppStorage.goalCalendarSyncEnabled = false
                showingCalendarAccessAlert = true
            }
        }
    }

    @MainActor
    private func requestCalendarAccessAfterExplainer() async {
        let granted = await CalendarManager.shared.requestAccessFromSystem()
        if granted {
            await enableCalendarSync()
        } else {
            goalCalendarSyncEnabled = false
            AppStorage.goalCalendarSyncEnabled = false
            showingCalendarAccessAlert = true
        }
    }

    @MainActor
    private func enableCalendarSync() async {
        goalCalendarSyncEnabled = true
        AppStorage.goalCalendarSyncEnabled = true
        var updatedEvents: [PrepEvent] = []
        for event in appState.prepEvents {
            let syncedEvent = await CalendarManager.shared.syncPrepEventIfAuthorized(event)
            updatedEvents.append(syncedEvent)
        }
        appState.replacePrepEvents(updatedEvents)
    }
}

struct GoalCard: View {
    let goal: LearningGoal
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(goal.title)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textOnLight)
                .fontWeight(.semibold)
            
            HStack {
                Text("\(Int(progress * 100))%")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.primaryAccent)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.Colors.secondaryBackground.opacity(0.3))
                    
                    Rectangle()
                        .fill(Theme.Colors.primaryAccent)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.contentSurface)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private var progress: Double {
        min(max(goal.progress, 0), 1)
    }
}

struct GoalMeasurementCard: View {
    let summary: WeeklyRecallSummary
    private let mcqStandard: Double = 0.8
    private let chartHeight: CGFloat = 58

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Measurable Standard")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textOnLight)
                .fontWeight(.semibold)

            HStack(spacing: Theme.Spacing.md) {
                metricPill(
                    title: "7-day average",
                    value: "\(format(summary.averageSessionsPerDay))/day",
                    subtitle: "\(summary.totalSessions) sessions total"
                )
                metricPill(
                    title: "MCQ accuracy",
                    value: "\(Int((summary.mcqAccuracy * 100).rounded()))%",
                    subtitle: summary.mcqTotal > 0 ? "\(summary.mcqCorrect)/\(summary.mcqTotal)" : "0/0"
                )
            }

            sessionChart

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Standard: keep MCQ accuracy above 80%")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                    Spacer()
                    Image(systemName: meetsStandard ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(meetsStandard ? Theme.Colors.success : Theme.Colors.evaluationMedium)
                        .font(.caption)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.secondaryBackground.opacity(0.35))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(meetsStandard ? Theme.Colors.success : Theme.Colors.primaryAccent)
                            .frame(width: geometry.size.width * max(0, min(summary.mcqAccuracy, 1)))

                        RoundedRectangle(cornerRadius: 1)
                            .fill(Theme.Colors.textOnLight.opacity(0.7))
                            .frame(width: 2)
                            .offset(x: max(0, min(geometry.size.width * mcqStandard - 1, geometry.size.width - 2)))
                    }
                }
                .frame(height: 8)
                .cornerRadius(4)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.contentSurface)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private var meetsStandard: Bool {
        summary.mcqTotal > 0 && summary.mcqAccuracy >= mcqStandard
    }

    private var maxDailySessions: Int {
        max(summary.points.map(\.sessions).max() ?? 0, 1)
    }

    private var sessionChart: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            ForEach(summary.points) { point in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.secondaryBackground.opacity(0.35))
                            .frame(height: chartHeight)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Palette.primary)
                            .frame(height: barHeight(for: point.sessions))
                    }

                    Text(point.dayLabel)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                    Text("\(point.sessions)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textOnLight)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func metricPill(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
            Text(value)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textOnLight)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground.opacity(0.35))
        .cornerRadius(Theme.CornerRadius.sm)
    }

    private func barHeight(for sessions: Int) -> CGFloat {
        guard sessions > 0 else { return 0 }
        return max(CGFloat(sessions) / CGFloat(maxDailySessions) * chartHeight, 2)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", max(0, value))
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(GlobalCaptureCoordinator())
}

private struct CalendarPermissionExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Sync prep events to Apple Calendar.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Signal will add and update calendar events for your interviews, assessments, and deadlines. You can disable this any time in Settings.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)

                Spacer()

                Button("Continue") {
                    onContinue()
                    dismiss()
                }
                .font(Theme.Typography.callout)
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.primaryAccent)
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)

                Button("Not Now") {
                    onCancel()
                    dismiss()
                }
                .font(Theme.Typography.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .foregroundColor(Theme.Colors.textMuted)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.primaryBackground.ignoresSafeArea())
            .navigationTitle("Calendar Permission")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
