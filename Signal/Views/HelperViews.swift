import SwiftUI
import UIKit

// MARK: - Add Content View
struct AddContentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var urlText: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var analyzedContent: LearningContent?
    @State private var navigateToDetail: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = "Saved"
    @State private var alertMessage: String = ""
    @State private var showingOnboarding: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.xl) {
                    Spacer()

                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Palette.primary)

                        Text("Share Content")
                            .font(Theme.Typography.title1)
                            .foregroundColor(Palette.primary)

                        Text("Paste a YouTube URL or article link")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        TextField("https://...", text: $urlText)
                            .font(Theme.Typography.body)
                            .foregroundColor(Palette.textPrimary)
                            .padding(Theme.Spacing.md)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .stroke(Palette.primary.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(Theme.CornerRadius.md)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                            .disabled(isAnalyzing)

                        if !urlText.isEmpty && !isValidURL(urlText) {
                            Text("Please enter a valid URL")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)

                    if isAnalyzing {
                        AnalyzingView()
                    } else {
                        SignalButton(title: "Analyze", style: .primary) {
                            if !AppStorage.hasOnboarded || AppStorage.selectedGoalId == nil {
                                showingOnboarding = true
                            } else {
                                analyzeContent()
                            }
                        }
                        .disabled(urlText.isEmpty || !isValidURL(urlText))
                        .opacity((urlText.isEmpty || !isValidURL(urlText)) ? 0.5 : 1.0)
                        .padding(.horizontal, Theme.Spacing.xl)
                    }

                    Spacer()

                    VStack(spacing: Theme.Spacing.sm) {
                        Text("Tip: Use the Share button in Safari or YouTube")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Palette.textSecondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(Palette.primary)
                            Image(systemName: "arrow.right")
                                .foregroundColor(Palette.primary)
                            Image(systemName: "waveform")
                                .foregroundColor(Palette.primary)
                        }
                        .font(.title3)
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                }

                // Hidden navigation link to detail when triggered
                NavigationLink(
                    destination: Group {
                        if let content = analyzedContent {
                            ContentDetailView(content: content)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $navigateToDetail,
                    label: { EmptyView() }
                )
                .hidden()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Palette.primary)
                    .disabled(isAnalyzing)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertTitle != "Error" {
                            dismiss()
                        }
                    }
                )
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
            .preferredColorScheme(.light)
        }
    }

    private func isValidURL(_ string: String) -> Bool {
        if let url = URL(string: string) {
            return url.scheme != nil && url.host != nil
        }
        return false
    }

    private func analyzeContent() {
        guard isValidURL(urlText) else { return }
        let currentURL = urlText
        isAnalyzing = true

        Task {
            do {
                let result = try await CaptureService.shared.submit(urlString: currentURL, appState: appState)
                // Clear input
                urlText = ""
                isAnalyzing = false

                switch result.decision {
                case .triggered:
                    analyzedContent = result.content
                    navigateToDetail = true
                case .ignored:
                    alertTitle = "Saved"
                    alertMessage = "Signal chose to ignore this to protect your focus. It’s saved if you want it later."
                    showAlert = true
                }
            } catch {
                isAnalyzing = false
                alertTitle = "Error"
                alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                showAlert = true
            }
        }
    }
}

struct PasteLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var urlText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let onEnqueued: (LearningContent) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Add a link")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Palette.textPrimary)

                    TextField("https://...", text: $urlText)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(Palette.primary.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(Theme.CornerRadius.md)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .disabled(isSubmitting)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Typography.caption)
                            .foregroundColor(.red)
                    }

                    HStack(spacing: Theme.Spacing.sm) {
                        Button("Paste") {
                            fillFromClipboard(manualTap: true)
                        }
                        .font(Theme.Typography.callout)
                        .foregroundColor(Palette.primary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Palette.card)
                        .cornerRadius(Theme.CornerRadius.md)
                        .disabled(isSubmitting)

                        Spacer()

                        Button {
                            submit()
                        } label: {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.sm)
                            } else {
                                Text("Analyze")
                                    .font(Theme.Typography.callout)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.sm)
                            }
                        }
                        .foregroundColor(.white)
                        .background(isValidURL(urlText) ? Palette.primary : Palette.textSecondary)
                        .cornerRadius(Theme.CornerRadius.md)
                        .disabled(!isValidURL(urlText) || isSubmitting)
                        .frame(maxWidth: 180)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Palette.primary)
                    .disabled(isSubmitting)
                }
            }
        }
        .onAppear {
            fillFromClipboard(manualTap: false)
        }
    }

    private func fillFromClipboard(manualTap: Bool) {
        guard let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              isValidURL(clipboardText) else {
            if manualTap {
                errorMessage = "Clipboard doesn't contain a valid URL."
            }
            return
        }

        urlText = clipboardText
        errorMessage = nil
    }

    private func submit() {
        let candidate = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            errorMessage = "Please enter a URL."
            return
        }

        guard isValidURL(candidate) else {
            errorMessage = "Please enter a valid URL."
            return
        }

        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                let result = try await CaptureService.shared.submit(urlString: candidate, appState: appState)
                await MainActor.run {
                    isSubmitting = false
                    onEnqueued(result.content)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't analyze this link right now."
                }
            }
        }
    }

    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              let host = url.host,
              !host.isEmpty else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
}

struct AnalyzingView: View {
    @State private var currentStep = 0
    let steps = [
        "Fetching content...",
        "Extracting key concepts...",
        "Evaluating relevance...",
        "Running Opik analysis..."
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .tint(Palette.primary)
                .scaleEffect(1.5)

            Text(steps[min(currentStep, steps.count - 1)])
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textSecondary)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { timer in
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            timer.invalidate()
                        }
                    }
                }
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Content Library View
struct ContentLibraryView: View {
    @ObservedObject private var store = ContentStore.shared
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if !store.contents.isEmpty {
                        ForEach(store.contents) { content in
                            NavigationLink(destination: ContentDetailView(content: content)) {
                                ContentCard(content: content)
                            }
                        }
                    } else {
                        Text("No content yet. Open Capture Center to add a link and get started.")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Palette.textSecondary)
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.card)
                            .cornerRadius(Theme.CornerRadius.md)
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .navigationTitle("Learning Library")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Goals View
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject private var recallStore = RecallSessionStore.shared
    @State private var showingAddGoal = false
    @State private var editingGoal: LearningGoal?
    @State private var pendingDeleteGoal: LearningGoal?

    private var weeklyRecallSummary: WeeklyRecallSummary {
        recallStore.weeklySummary()
    }

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        GoalMeasurementCard(summary: weeklyRecallSummary)

                        if appState.learningGoals.isEmpty {
                            emptyState
                        } else {
                            ForEach(appState.learningGoals) { goal in
                                VStack(spacing: Theme.Spacing.sm) {
                                    GoalCard(goal: goal)

                                    HStack {
                                        Button {
                                            editingGoal = goal
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            pendingDeleteGoal = goal
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Palette.textSecondary)
                                    .padding(.horizontal, Theme.Spacing.xs)
                                }
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Learning Goals")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                appState.refreshLearningGoalProgress()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Palette.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Palette.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView { newGoal in
                    Task { await saveNewGoal(newGoal) }
                }
            }
            .sheet(item: $editingGoal) { goal in
                EditGoalView(goal: goal) { updatedGoal in
                    Task { await saveUpdatedGoal(updatedGoal) }
                }
            }
            .alert("Delete this goal?", isPresented: Binding(
                get: { pendingDeleteGoal != nil },
                set: { if !$0 { pendingDeleteGoal = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    guard let goal = pendingDeleteGoal else { return }
                    pendingDeleteGoal = nil
                    Task { await deleteGoal(goal) }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteGoal = nil
                }
            } message: {
                Text("This removes the goal from Signal.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(Palette.textSecondary)

            Text("No Goals Yet")
                .font(Theme.Typography.title2)
                .foregroundColor(Palette.textPrimary)

            Text("Set learning goals to define your long-term intent")
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, 100)
    }

    @MainActor
    private func saveNewGoal(_ goal: LearningGoal) async {
        appState.addGoal(goal)
    }

    @MainActor
    private func saveUpdatedGoal(_ goal: LearningGoal) async {
        appState.updateGoal(goal)
    }

    @MainActor
    private func deleteGoal(_ goal: LearningGoal) async {
        _ = appState.removeGoal(id: goal.id)
    }
}

struct PrepEventsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showingAddEvent = false
    @State private var editingEvent: PrepEvent?
    @State private var pendingDeleteEvent: PrepEvent?

    private var sortedEvents: [PrepEvent] {
        appState.prepEvents.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        if sortedEvents.isEmpty {
                            VStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(Palette.textSecondary)
                                Text("No prep events yet")
                                    .font(Theme.Typography.title3)
                                    .foregroundColor(Palette.textPrimary)
                                Text("Add interviews, exams, or deadlines to drive preparation urgency.")
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Palette.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, Theme.Spacing.xl)
                        } else {
                            ForEach(sortedEvents) { event in
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                        Image(systemName: event.type.systemImage)
                                            .foregroundColor(Palette.primary)

                                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                            Text(eventTitle(event))
                                                .font(Theme.Typography.callout)
                                                .foregroundColor(Palette.textPrimary)
                                                .fontWeight(.semibold)
                                            Text(Self.dateFormatter.string(from: event.date))
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Palette.textSecondary)
                                            if let subtitle = eventSubtitle(event) {
                                                Text(subtitle)
                                                    .font(Theme.Typography.caption)
                                                    .foregroundColor(Palette.textSecondary)
                                            }
                                        }

                                        Spacer()
                                    }

                                    HStack {
                                        Button {
                                            editingEvent = event
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            pendingDeleteEvent = event
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Palette.textSecondary)
                                }
                                .padding(Theme.Spacing.md)
                                .background(Palette.card)
                                .cornerRadius(Theme.CornerRadius.md)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Prep Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Palette.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Palette.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddPrepEventView { event in
                    appState.addPrepEvent(event)
                }
            }
            .sheet(item: $editingEvent) { event in
                EditPrepEventView(event: event) { updated in
                    appState.updatePrepEvent(updated)
                }
            }
            .alert("Delete this event?", isPresented: Binding(
                get: { pendingDeleteEvent != nil },
                set: { if !$0 { pendingDeleteEvent = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    guard let event = pendingDeleteEvent else { return }
                    pendingDeleteEvent = nil
                    _ = appState.removePrepEvent(id: event.id)
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteEvent = nil
                }
            } message: {
                Text("This removes the prep event from Signal.")
            }
        }
    }

    private func eventTitle(_ event: PrepEvent) -> String {
        switch event.type {
        case .interview:
            return "Interview"
        case .exam:
            return "Assessment"
        case .deadline:
            return "Application deadline"
        }
    }

    private func eventSubtitle(_ event: PrepEvent) -> String? {
        var parts: [String] = []
        if let company = event.metadata.company, !company.isEmpty { parts.append(company) }
        if let role = event.metadata.role, !role.isEmpty { parts.append(role) }
        if event.type == .exam, let examType = event.metadata.examType, !examType.isEmpty { parts.append(examType) }
        if event.type == .exam, let domain = event.metadata.domain, !domain.isEmpty { parts.append(domain) }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Add Goal View
struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goalTitle: String = ""
    let onSave: (LearningGoal) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Goal title", text: $goalTitle)
                    } header: {
                        Text("What do you want to learn?")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmedTitle = goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty else { return }
                        let newGoal = LearningGoal(
                            title: trimmedTitle,
                            targetDate: Date()
                        )
                        onSave(newGoal)
                        dismiss()
                    }
                    .disabled(goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct EditGoalView: View {
    @Environment(\.dismiss) private var dismiss
    let goal: LearningGoal
    @State private var goalTitle: String
    let onSave: (LearningGoal) -> Void

    init(goal: LearningGoal, onSave: @escaping (LearningGoal) -> Void) {
        self.goal = goal
        self.onSave = onSave
        _goalTitle = State(initialValue: goal.title)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Goal title", text: $goalTitle)
                    } header: {
                        Text("What do you want to learn?")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmedTitle = goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty else { return }
                        onSave(
                            LearningGoal(
                                id: goal.id,
                                title: trimmedTitle,
                                targetDate: goal.targetDate,
                                progress: goal.progress,
                                relatedConcepts: goal.relatedConcepts,
                                calendarEventIdentifier: goal.calendarEventIdentifier
                            )
                        )
                        dismiss()
                    }
                    .disabled(goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Prep Event Views
struct AddPrepEventView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var type: PrepEventType = .interview
    @State private var date: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var company: String = ""
    @State private var role: String = ""
    @State private var format: String = ""
    @State private var examType: String = ""
    @State private var domain: String = ""

    let onSave: (PrepEvent) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                Form {
                    Section {
                        Picker("Event type", selection: $type) {
                            ForEach(PrepEventType.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                    }

                    Section {
                        DatePicker("Date", selection: $date, in: Date()..., displayedComponents: .date)
                    }

                    Section {
                        if type == .interview {
                            TextField("Company (optional)", text: $company)
                            TextField("Role (optional)", text: $role)
                            TextField("Format (optional)", text: $format)
                        } else if type == .exam {
                            TextField("Exam type (optional)", text: $examType)
                            TextField("Domain or role (optional)", text: $domain)
                        } else {
                            TextField("Company (optional)", text: $company)
                            TextField("Role (optional)", text: $role)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let metadata = PrepEventMetadata(
                            company: trimmed(company),
                            role: trimmed(role),
                            format: type == .interview ? trimmed(format) : nil,
                            examType: type == .exam ? trimmed(examType) : nil,
                            domain: type == .exam ? trimmed(domain) : nil
                        )
                        let event = PrepEvent(type: type, date: date, metadata: metadata)
                        onSave(event)
                        dismiss()
                    }
                }
            }
        }
    }

    private func trimmed(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

struct EditPrepEventView: View {
    @Environment(\.dismiss) private var dismiss
    let event: PrepEvent
    @State private var type: PrepEventType
    @State private var date: Date
    @State private var company: String
    @State private var role: String
    @State private var format: String
    @State private var examType: String
    @State private var domain: String

    let onSave: (PrepEvent) -> Void

    init(event: PrepEvent, onSave: @escaping (PrepEvent) -> Void) {
        self.event = event
        self.onSave = onSave
        _type = State(initialValue: event.type)
        _date = State(initialValue: event.date)
        _company = State(initialValue: event.metadata.company ?? "")
        _role = State(initialValue: event.metadata.role ?? "")
        _format = State(initialValue: event.metadata.format ?? "")
        _examType = State(initialValue: event.metadata.examType ?? "")
        _domain = State(initialValue: event.metadata.domain ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                Form {
                    Section {
                        Picker("Event type", selection: $type) {
                            ForEach(PrepEventType.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                    }

                    Section {
                        DatePicker("Date", selection: $date, in: Date()..., displayedComponents: .date)
                    }

                    Section {
                        if type == .interview {
                            TextField("Company (optional)", text: $company)
                            TextField("Role (optional)", text: $role)
                            TextField("Format (optional)", text: $format)
                        } else if type == .exam {
                            TextField("Exam type (optional)", text: $examType)
                            TextField("Domain or role (optional)", text: $domain)
                        } else {
                            TextField("Company (optional)", text: $company)
                            TextField("Role (optional)", text: $role)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let metadata = PrepEventMetadata(
                            company: trimmed(company),
                            role: trimmed(role),
                            format: type == .interview ? trimmed(format) : nil,
                            examType: type == .exam ? trimmed(examType) : nil,
                            domain: type == .exam ? trimmed(domain) : nil
                        )
                        let updated = PrepEvent(
                            id: event.id,
                            type: type,
                            date: date,
                            metadata: metadata,
                            calendarEventIdentifier: event.calendarEventIdentifier
                        )
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }

    private func trimmed(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

struct EventPrepView: View {
    let event: PrepEvent
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddContent = false
    @State private var showingRecallSession = false
    @State private var selectedRecallContent: LearningContent?
    @ObservedObject private var store = ContentStore.shared

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        headerCard
                        motivationCard
                        prepTipsSection
                        recallSection
                        SignalButton(title: primaryCTATitle, style: .primary) {
                            handlePrimaryCTA()
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle(event.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddContent) {
                AddContentView()
            }
            .sheet(isPresented: $showingRecallSession) {
                if let content = selectedRecallContent {
                    RecallSessionView(content: content)
                } else {
                    Color.clear
                }
            }
        }
    }

    private var recallCandidates: [LearningContent] {
        let scheduled = ScheduledRecallStore.shared.all()
            .filter { !RecallSessionStore.shared.isMuted(contentId: $0.contentId) }
        let lookup = Dictionary(uniqueKeysWithValues: store.contents.map { ($0.id, $0) })
        let mapped: [(ScheduledRecallItem, LearningContent)] = scheduled.compactMap { item in
            guard let content = lookup[item.contentId] else { return nil }
            return (item, content)
        }
        return mapped
            .sorted { $0.0.fireDate < $1.0.fireDate }
            .map { $0.1 }
    }

    private var primaryCTATitle: String {
        recallCandidates.isEmpty ? "Start preparation" : "Start recall session"
    }

    private func handlePrimaryCTA() {
        if let content = recallCandidates.first {
            selectedRecallContent = content
            showingRecallSession = true
        } else {
            showingAddContent = true
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: event.type.systemImage)
                    .foregroundColor(Palette.primary)
                Text(event.type.displayName)
                    .font(Theme.Typography.title2)
                    .foregroundColor(Palette.textPrimary)
            }

            Text(event.countdownLabel())
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)

            Text(formattedDate(event.date))
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textSecondary)

            if let details = eventDetailsLine() {
                Text(details)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private var motivationCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("You’re closer than you think.")
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textPrimary)
                .fontWeight(.semibold)
            Text(motivationCopy())
                .font(Theme.Typography.callout)
                .foregroundColor(Palette.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }

    private var prepTipsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Prep tips")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(prepTips(), id: \.self) { tip in
                    Text(tip)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                        .background(Palette.card)
                        .cornerRadius(Theme.CornerRadius.md)
                }
            }
        }
    }

    private var recallSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Recall to sharpen")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)

            if recallCandidates.isEmpty {
                Text("No recall tasks yet. Add a link or note to generate prep-ready recall.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)
                    .padding(Theme.Spacing.md)
                    .background(Palette.card)
                    .cornerRadius(Theme.CornerRadius.md)
            } else {
                ForEach(recallCandidates.prefix(3)) { content in
                    NavigationLink(destination: RecallSessionView(content: content)) {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "brain.head.profile")
                                .font(.title3)
                                .foregroundColor(Palette.primary)
                                .frame(width: 36, height: 36)
                                .background(Palette.primary.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.sm)

                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(content.title)
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Palette.textPrimary)
                                    .lineLimit(2)
                                Text("Ready for recall")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Palette.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Palette.textSecondary)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Palette.card)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func motivationCopy() -> String {
        switch event.type {
        case .interview:
            return "Clear stories and calm delivery beat last-minute cramming. One strong example per skill is enough."
        case .exam:
            return "Short, focused recall beats rereading. Aim for coverage first, then depth."
        case .deadline:
            return "Finish the essentials, then polish. A clean, complete application wins more than extra bells and whistles."
        }
    }

    private func prepTips() -> [String] {
        switch event.type {
        case .interview:
            return [
                "Use STAR: Situation, Task, Action, Result. Prepare 2-3 stories that cover teamwork, conflict, and impact.",
                "Review the role basics and be ready to explain your trade-offs out loud.",
                "Do one timed mock question to get comfortable speaking under pressure."
            ]
        case .exam:
            return [
                "Start with a quick outline of the major topics, then drill your weakest two.",
                "Practice retrieval: write what you remember before checking notes.",
                "Do a mini timed set to build pacing and confidence."
            ]
        case .deadline:
            return [
                "Confirm the submission requirements and format now.",
                "Focus on clarity and completeness before extra polish.",
                "Do a final pass for spelling, links, and attachments."
            ]
        }
    }

    private func eventDetailsLine() -> String? {
        var parts: [String] = []
        if let company = event.metadata.company, !company.isEmpty { parts.append(company) }
        if let role = event.metadata.role, !role.isEmpty { parts.append(role) }
        if event.type == .interview, let format = event.metadata.format, !format.isEmpty { parts.append(format) }
        if event.type == .exam, let examType = event.metadata.examType, !examType.isEmpty { parts.append(examType) }
        if event.type == .exam, let domain = event.metadata.domain, !domain.isEmpty { parts.append(domain) }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Feedback View
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let content: LearningContent
    @State private var wasUseful: Bool? = nil
    @State private var selectedReasons: Set<String> = []
    @State private var isSubmitting: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var confirmationMessage: String = "Feedback submitted."

    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        Text("Was this intervention useful?")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Palette.primary)

                        HStack(spacing: Theme.Spacing.lg) {
                            Button {
                                if wasUseful != true {
                                    wasUseful = true
                                    selectedReasons.removeAll()
                                }
                            } label: {
                                VStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(wasUseful == true ? Palette.primary : Palette.textSecondary)

                                    Text("Useful")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(wasUseful == true ? Palette.primary : Palette.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Theme.Spacing.lg)
                                .background(wasUseful == true ? Palette.primary.opacity(0.1) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                        .stroke(wasUseful == true ? Palette.primary : Palette.primary.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(Theme.CornerRadius.md)
                            }

                            Button {
                                if wasUseful != false {
                                    wasUseful = false
                                    selectedReasons.removeAll()
                                }
                            } label: {
                                VStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(wasUseful == false ? Palette.primary : Palette.textSecondary)

                                    Text("Not Useful")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(wasUseful == false ? Palette.primary : Palette.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Theme.Spacing.lg)
                                .background(wasUseful == false ? Palette.primary.opacity(0.1) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                        .stroke(wasUseful == false ? Palette.primary : Palette.primary.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(Theme.CornerRadius.md)
                            }
                        }

                        if let useful = wasUseful {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                Text("Why? (optional)")
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Palette.textSecondary)

                                let reasons = useful
                                    ? ["aligned_goal","practical","clear","challenging"]
                                    : ["not_aligned","too_basic","too_advanced","low_quality","clickbait"]

                                // Display chips in flexible grid
                                FlexibleView(data: reasons, spacing: Theme.Spacing.sm, alignment: .leading) { reason in
                                    ReasonChip(
                                        label: reason,
                                        isSelected: selectedReasons.contains(reason)
                                    ) {
                                        if selectedReasons.contains(reason) {
                                            selectedReasons.remove(reason)
                                        } else {
                                            selectedReasons.insert(reason)
                                        }
                                    }
                                }
                            }
                        }

                        SignalButton(title: "Submit", style: .primary) {
                            submitFeedback()
                        }
                        .disabled(wasUseful == nil || isSubmitting)
                        .opacity((wasUseful == nil || isSubmitting) ? 0.5 : 1.0)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Palette.primary)
                }
            }
            .alert(isPresented: $showConfirmation) {
                Alert(
                    title: Text("Thanks!"),
                    message: Text(confirmationMessage),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                    }
                )
            }
        }
    }

    private func submitFeedback() {
        guard let useful = wasUseful else { return }

        let existingTrace = ObservabilityStore.shared.lastTraceID(for: content.id)
        let trace = existingTrace ?? UUID()

        if existingTrace == nil {
            let contentType = (content.source == .youtube) ? "video" : "article"
            let decision = (content.analysisStatus == .completed) ? "triggered" : "ignored"
            ObservabilityStore.shared.map(contentID: content.id, to: trace, decision: decision, contentType: contentType)
        }

        let feedbackString = useful ? "useful" : "not_useful"
        let reasonsArray = Array(selectedReasons)

        debugPrint("Submitting feedback with traceID: \(trace), contentID: \(content.id), feedback: \(feedbackString), reasons: \(reasonsArray)")

        isSubmitting = true

        FeedbackService.shared.submitFeedback(
            traceID: trace,
            contentID: content.id,
            feedback: feedbackString,
            reasons: reasonsArray,
            recallCorrect: nil,
            recallTotal: nil,
            timestamp: Date()
        )
 
        debugPrint("Feedback enqueued for background send")

        // set isSubmitting false immediately since it's enqueued and non-blocking
        isSubmitting = false

        let decision = (content.analysisStatus == .completed) ? "triggered" : "ignored"
        let ignoreReason = (decision == "ignored")
            ? (content.ignoreReason ?? IgnoreReason.fromScores(relevance: content.relevanceScore, learningValue: content.learningValue))
            : nil
        let decisionConfidence = DecisionConfidence.fromScores(
            relevance: content.relevanceScore,
            learningValue: content.learningValue,
            conceptCount: content.concepts.count,
            interventionPolicy: AppStorage.interventionPolicy
        )
        let event = ObservabilityEvent(
            traceID: trace,
            eventType: "user_feedback",
            contentType: (content.source == .youtube) ? "video" : "article",
            conceptCount: content.concepts.count,
            relevanceScore: content.relevanceScore,
            learningValueScore: content.learningValue,
            decision: decision,
            systemDecision: decision,
            interventionPolicy: AppStorage.interventionPolicy,
            careerStage: AppStorage.careerStage,
            ignoreReason: ignoreReason,
            decisionConfidence: decisionConfidence,
            userFeedback: feedbackString,
            timestamp: Date()
        )
        ObservabilityClient.shared.log(event)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if !useful {
            ContentStore.shared.mute(contentId: content.id)
            RecallSessionStore.shared.mute(contentId: content.id)
            ScheduledRecallStore.shared.remove(contentId: content.id)
            NotificationManager.shared.cancelRecallNotifications(contentId: content.id)
            confirmationMessage = "Got it - we won't prompt you about this again (still saved)."
        } else {
            if content.analysisStatus == .belowThreshold {
                enablePracticeForIgnoredContent()
                confirmationMessage = "Added for practice. You can review it from Next up or Recall."
            } else {
                confirmationMessage = "Feedback submitted."
            }
        }
        showConfirmation = true
    }

    private func enablePracticeForIgnoredContent() {
        var updated = content
        let existingQuestions = updated.recallQuestions ?? []
        if existingQuestions.isEmpty {
            updated.recallQuestions = generatedRecallQuestions(for: updated)
        }
        updated.lastFeedback = "useful"
        ContentStore.shared.unmute(contentId: updated.id)
        RecallSessionStore.shared.unmute(contentId: updated.id)
        ContentStore.shared.update(updated)

        // Keep Review Schedule in sync with newly enabled recall practice.
        if let questions = updated.recallQuestions, !questions.isEmpty {
            let fireDate = Date().addingTimeInterval(NotificationManager.preferredRecallDelay())
            ScheduledRecallStore.shared.remove(contentId: updated.id)
            ScheduledRecallStore.shared.add(contentId: updated.id, contentTitle: updated.title, fireDate: fireDate)
        }
    }

    private func generatedRecallQuestions(for content: LearningContent) -> [RecallQuestion] {
        let concepts = content.concepts
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if concepts.isEmpty {
            return [
                RecallQuestion(
                    question: "What is the main takeaway from this content, and where would you apply it?",
                    type: .open
                )
            ]
        }

        var seen = Set<String>()
        let uniqueConcepts = concepts.filter { seen.insert($0.lowercased()).inserted }

        return uniqueConcepts.prefix(3).map { concept in
            RecallQuestion(
                question: "Explain \(concept) in your own words and give one practical use case.",
                type: .open
            )
        }
    }
}

// MARK: - Reason Chip
private struct ReasonChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    private var displayText: String {
        switch label {
        case "aligned_goal": return "Aligned Goal"
        case "practical": return "Practical"
        case "clear": return "Clear"
        case "challenging": return "Challenging"
        case "not_aligned": return "Not Aligned"
        case "too_basic": return "Too Basic"
        case "too_advanced": return "Too Advanced"
        case "low_quality": return "Low Quality"
        case "clickbait": return "Clickbait"
        default: return label.capitalized
        }
    }

    var body: some View {
        Text(displayText)
            .font(Theme.Typography.caption)
            .foregroundColor(isSelected ? Palette.primary : Palette.textSecondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isSelected ? Palette.primary.opacity(0.15) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(isSelected ? Palette.primary : Palette.primary.opacity(0.2), lineWidth: 1)
                    )
            )
            .onTapGesture {
                onTap()
            }
    }
}

// Helper FlexibleView to lay out chips nicely
private struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat = 8, alignment: HorizontalAlignment = .leading, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        let items = Array(data)

        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                content(item)
                    .padding(.all, 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if index == 0 {
                            width = 0
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if index == 0 {
                            height = 0
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geo.size.height
            }
            return Color.clear
        }
    }
}

#Preview("Add Content") {
    AddContentView()
}

#Preview("Goals") {
    GoalsView()
}

#Preview("Feedback") {
    FeedbackView(content: LearningContent(
        url: "https://example.com",
        title: "Test Content",
        source: .youtube,
        analysisStatus: .completed,
        traceId: nil,
        lastFeedback: nil
    ))
}
