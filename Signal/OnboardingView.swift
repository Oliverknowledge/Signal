import SwiftUI
import Combine
import UIKit

// MARK: - Haptics
struct Haptics {
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

struct OnboardingResult {
    let fieldId: String
    let fieldTitle: String
    let goalId: String
    let goalDescription: String
    let goalTitle: String
    let weakConcepts: [String]
    let prepEvents: [PrepEvent]
}

// MARK: - Tracks & Outcomes
enum Track: String, CaseIterable, Identifiable {
    case softwareEngineering = "software_engineering"
    case dataML = "data_ml"
    case productManagement = "product_management"
    case design = "ui_ux_design"
    case finance = "finance_investing"
    case entrepreneurship = "entrepreneurship"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .softwareEngineering: return "Software Engineering"
        case .dataML: return "Data / ML"
        case .productManagement: return "Product Management"
        case .design: return "Design"
        case .finance: return "Finance"
        case .entrepreneurship: return "Entrepreneurship"
        }
    }
    var systemImage: String {
        switch self {
        case .softwareEngineering: return "chevron.left.forwardslash.chevron.right"
        case .dataML: return "chart.xyaxis.line"
        case .productManagement: return "list.bullet.rectangle"
        case .design: return "paintbrush"
        case .finance: return "dollarsign.circle"
        case .entrepreneurship: return "briefcase"
        }
    }
}

struct OutcomeOption: Identifiable, Hashable {
    let id: String
    let label: String
}

struct FocusAreaOption: Identifiable, Hashable {
    let id: String
    let label: String
    let subtitle: String
    let icon: String
    let weakConceptSeeds: [String]
}

private func focusAreas(for track: Track) -> [FocusAreaOption] {
    switch track {
    case .softwareEngineering:
        return [
            .init(
                id: "cpp_systems",
                label: "C++ / Systems",
                subtitle: "Memory, performance, and low-level programming",
                icon: "cpu",
                weakConceptSeeds: ["RAII", "smart pointers", "move semantics", "templates", "concurrency", "memory management"]
            ),
            .init(
                id: "backend",
                label: "Backend",
                subtitle: "APIs, data modeling, and distributed systems",
                icon: "server.rack",
                weakConceptSeeds: ["REST API design", "databases", "caching", "queues", "auth", "observability"]
            ),
            .init(
                id: "frontend",
                label: "Frontend",
                subtitle: "Web apps, state, and performance",
                icon: "macwindow",
                weakConceptSeeds: ["state management", "rendering", "accessibility", "performance", "testing", "TypeScript"]
            ),
            .init(
                id: "mobile",
                label: "Mobile (iOS / Android)",
                subtitle: "Native architecture and app lifecycle",
                icon: "iphone",
                weakConceptSeeds: ["SwiftUI/UIKit", "Kotlin", "app lifecycle", "offline sync", "push notifications", "performance"]
            ),
            .init(
                id: "data_structures_algorithms",
                label: "Data Structures & Algorithms",
                subtitle: "Interview and core CS foundations",
                icon: "point.3.filled.connected.trianglepath.dotted",
                weakConceptSeeds: ["arrays", "hash maps", "trees", "graphs", "dynamic programming", "big O"]
            ),
            .init(
                id: "devops_platform",
                label: "DevOps / Platform",
                subtitle: "Infra automation, CI/CD, and reliability",
                icon: "wrench.and.screwdriver",
                weakConceptSeeds: ["CI/CD", "containers", "Kubernetes", "IaC", "monitoring", "incident response"]
            )
        ]
    case .dataML:
        return [
            .init(
                id: "ml_engineering",
                label: "ML Engineering",
                subtitle: "Training pipelines, serving, and MLOps",
                icon: "brain.head.profile",
                weakConceptSeeds: ["feature engineering", "model serving", "evaluation", "drift", "pipelines", "MLOps"]
            ),
            .init(
                id: "analytics",
                label: "Analytics",
                subtitle: "SQL, dashboards, and product analysis",
                icon: "chart.bar.doc.horizontal",
                weakConceptSeeds: ["SQL", "experimentation", "funnel analysis", "cohorts", "data modeling", "visualization"]
            ),
            .init(
                id: "data_engineering",
                label: "Data Engineering",
                subtitle: "ETL, warehousing, and data quality",
                icon: "tray.2",
                weakConceptSeeds: ["ETL", "warehousing", "batch vs streaming", "orchestration", "data quality", "schema design"]
            )
        ]
    case .productManagement:
        return [
            .init(
                id: "product_strategy",
                label: "Product Strategy",
                subtitle: "Prioritization, outcomes, and roadmaps",
                icon: "compass.drawing",
                weakConceptSeeds: ["north star metrics", "prioritization", "roadmapping", "tradeoffs", "go-to-market", "positioning"]
            ),
            .init(
                id: "execution",
                label: "Execution",
                subtitle: "Specs, delivery, and cross-functional alignment",
                icon: "checklist",
                weakConceptSeeds: ["PRDs", "stakeholder alignment", "scope control", "delivery planning", "risk management", "retrospectives"]
            )
        ]
    case .design:
        return [
            .init(
                id: "product_design",
                label: "Product Design",
                subtitle: "UX flows, interaction, and usability",
                icon: "scribble.variable",
                weakConceptSeeds: ["user flows", "interaction design", "usability testing", "information architecture", "heuristics", "accessibility"]
            ),
            .init(
                id: "visual_brand",
                label: "Visual / Brand",
                subtitle: "Typography, systems, and visual polish",
                icon: "textformat.size",
                weakConceptSeeds: ["typography", "color systems", "layout", "design tokens", "brand consistency", "component systems"]
            )
        ]
    case .finance:
        return [
            .init(
                id: "investing",
                label: "Investing",
                subtitle: "Portfolio construction and risk",
                icon: "chart.line.uptrend.xyaxis",
                weakConceptSeeds: ["asset allocation", "risk-adjusted return", "indexing", "portfolio rebalancing", "valuation", "macro context"]
            ),
            .init(
                id: "corporate_finance",
                label: "Corporate Finance",
                subtitle: "Modeling, statements, and valuation",
                icon: "building.columns",
                weakConceptSeeds: ["three-statement modeling", "DCF", "WACC", "cash flow", "working capital", "sensitivity analysis"]
            )
        ]
    case .entrepreneurship:
        return [
            .init(
                id: "early_stage",
                label: "Early-stage Startup",
                subtitle: "Discovery, MVP, and early traction",
                icon: "rocket",
                weakConceptSeeds: ["customer discovery", "MVP scoping", "positioning", "pricing", "activation", "retention"]
            ),
            .init(
                id: "growth_operations",
                label: "Growth & Operations",
                subtitle: "Scaling acquisition and execution",
                icon: "arrow.up.right.circle",
                weakConceptSeeds: ["growth loops", "channel strategy", "unit economics", "team ops", "forecasting", "process design"]
            )
        ]
    }
}

private func outcomes(for track: Track) -> [OutcomeOption] {
    switch track {
    case .softwareEngineering:
        return [
            .init(id: "job_ready", label: "Get job-ready"),
            .init(id: "switch_roles", label: "Switch roles"),
            .init(id: "level_up_senior", label: "Level up as a senior"),
            .init(id: "prepare_interviews", label: "Prepare for interviews"),
            .init(id: "build_production_systems", label: "Build production-grade systems")
        ]
    case .dataML:
        return [
            .init(id: "job_ready", label: "Get job-ready"),
            .init(id: "switch_roles", label: "Switch roles"),
            .init(id: "level_up", label: "Level up"),
            .init(id: "prepare_interviews", label: "Prepare for interviews"),
            .init(id: "ship_models", label: "Ship production models")
        ]
    case .productManagement:
        return [
            .init(id: "job_ready", label: "Get job-ready"),
            .init(id: "switch_roles", label: "Switch roles"),
            .init(id: "level_up", label: "Level up"),
            .init(id: "lead_roadmaps", label: "Lead roadmaps"),
            .init(id: "prepare_interviews", label: "Prepare for interviews")
        ]
    case .design:
        return [
            .init(id: "job_ready", label: "Get job-ready"),
            .init(id: "switch_roles", label: "Switch roles"),
            .init(id: "level_up", label: "Level up"),
            .init(id: "ship_systems", label: "Ship design systems"),
            .init(id: "prepare_interviews", label: "Prepare for interviews")
        ]
    case .finance:
        return [
            .init(id: "job_ready", label: "Get job-ready"),
            .init(id: "switch_roles", label: "Switch roles"),
            .init(id: "level_up", label: "Level up"),
            .init(id: "analyze_markets", label: "Analyze markets"),
            .init(id: "invest_better", label: "Invest better")
        ]
    case .entrepreneurship:
        return [
            .init(id: "launch_mvp", label: "Launch an MVP"),
            .init(id: "find_fit", label: "Find product-market fit"),
            .init(id: "grow_revenue", label: "Grow revenue"),
            .init(id: "position_pricing", label: "Nail positioning & pricing"),
            .init(id: "scale_ops", label: "Scale ops")
        ]
    }
}


// MARK: - ViewModel
final class OnboardingFlowViewModel: ObservableObject {
    // Selections
    @Published var selectedTrack: Track? = nil
    @Published var selectedFocusAreaId: String? = nil
    @Published var selectedFocusAreaLabel: String? = nil
    @Published var selectedFocusAreaWeakSeeds: [String] = []
    @Published var selectedOutcomeId: String? = nil
    @Published var selectedOutcomeLabel: String? = nil

    // Events
    @Published var selectedEventTypes: Set<PrepEventType> = []
    @Published var noneSelected: Bool = true
    @Published var prepEvents: [PrepEvent] = []

    // Helpers
    let totalSteps: Int = 5

    func toggleEventType(_ type: PrepEventType) {
        if selectedEventTypes.contains(type) {
            selectedEventTypes.remove(type)
            prepEvents.removeAll { $0.type == type }
            if selectedEventTypes.isEmpty {
                noneSelected = true
            }
        } else {
            selectedEventTypes.insert(type)
            noneSelected = false
        }
        Haptics.select()
    }

    func selectNoneYet() {
        noneSelected = true
        selectedEventTypes.removeAll()
        prepEvents.removeAll()
        Haptics.select()
    }

    // Completion & persistence
    func complete(onFinished: (OnboardingResult) -> Void) {
        guard let track = selectedTrack,
              let focusAreaId = selectedFocusAreaId,
              let focusAreaLabel = selectedFocusAreaLabel,
              let outcomeId = selectedOutcomeId,
              let outcomeLabel = selectedOutcomeLabel
        else { return }
        let goalId = "\(track.id)_\(focusAreaId)_\(outcomeId)"
        let goalTitle = "\(track.displayName) (\(focusAreaLabel)): \(outcomeLabel)"
        let description = GoalBuilder.goalDescription(
            months: nil,
            trackName: track.displayName,
            focusArea: focusAreaLabel,
            outcomeLabel: outcomeLabel,
            metrics: []
        )
        let weakConcepts = uniqueConcepts(
            GoalBuilder.weakSeeds(for: track.id) + selectedFocusAreaWeakSeeds
        )
        let now = Date()
        let upcoming = prepEvents
            .filter { $0.date >= Calendar.current.startOfDay(for: now) }
            .sorted { $0.date < $1.date }
        onFinished(
            OnboardingResult(
                fieldId: track.id,
                fieldTitle: track.displayName,
                goalId: goalId,
                goalDescription: description,
                goalTitle: goalTitle,
                weakConcepts: weakConcepts,
                prepEvents: upcoming
            )
        )
    }

    private func uniqueConcepts(_ concepts: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for concept in concepts {
            let trimmed = concept.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered
    }
}

// MARK: - Root host
struct OnboardingView: View {
    var onFinished: (OnboardingResult) -> Void
    var body: some View { OnboardingFlowView(onFinished: onFinished) }
}

struct OnboardingFlowView: View {
    var onFinished: (OnboardingResult) -> Void
    @StateObject private var vm = OnboardingFlowViewModel()
    @State private var step: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressHeader(step: step, totalSteps: vm.totalSteps)
                    .padding(.horizontal)
                    .padding(.top, 12)

                ZStack {
                    switch step {
                    case 0: Step1_Track(vm: vm) { advance() }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 1: Step2_FocusArea(vm: vm) { advance() }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 2: Step3_Outcome(vm: vm) { advance() }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 3: Step4_EventCheck(vm: vm) { advance() }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 4: Step5_EventDetails(vm: vm) {
                        vm.complete(onFinished: onFinished)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    default:
                        Step5_EventDetails(vm: vm) {
                            vm.complete(onFinished: onFinished)
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal)
                .padding(.top, 8)
                .animation(.spring(response: 0.5, dampingFraction: 0.9), value: step)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 && step < vm.totalSteps {
                        Button("Back") { withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = max(0, step - 1) }; Haptics.impact(.light) }
                    }
                }
            }
        }
    }

    private func advance() { withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { step = min(step + 1, vm.totalSteps) }; Haptics.select() }
}

// MARK: - Progress Header
struct ProgressHeader: View {
    let step: Int
    let totalSteps: Int
    private var progress: Double {
        let clamped = min(max(step, 0), totalSteps)
        if clamped >= totalSteps { return 1.0 }
        return Double(clamped + 1) / Double(totalSteps)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= min(step, totalSteps - 1) ? Color.accentColor : Color.gray.opacity(0.25))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: step)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
    }
}

// MARK: - Step 1: Track (full-width single-column)
struct Step1_Track: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    var onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What are you strengthening in 2026?")
                .font(.largeTitle).bold()
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Track.allCases) { track in
                        SelectableCard(title: track.displayName, subtitle: nil, icon: track.systemImage, isSelected: vm.selectedTrack == track) {
                            vm.selectedTrack = track
                            vm.selectedFocusAreaId = nil
                            vm.selectedFocusAreaLabel = nil
                            vm.selectedFocusAreaWeakSeeds = []
                            vm.selectedOutcomeId = nil
                            vm.selectedOutcomeLabel = nil
                            onNext()
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }
}

// MARK: - Step 2: Focus Area (full-width single-column)
struct Step2_FocusArea: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    var onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which area should Signal focus on?")
                .font(.largeTitle).bold()
                .padding(.top, 8)

            if let track = vm.selectedTrack {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(focusAreas(for: track)) { focus in
                            SelectableCard(title: focus.label, subtitle: focus.subtitle, icon: focus.icon, isSelected: vm.selectedFocusAreaId == focus.id) {
                                vm.selectedFocusAreaId = focus.id
                                vm.selectedFocusAreaLabel = focus.label
                                vm.selectedFocusAreaWeakSeeds = focus.weakConceptSeeds
                                vm.selectedOutcomeId = nil
                                vm.selectedOutcomeLabel = nil
                                onNext()
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                Text("Select a track first.").foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Step 3: Outcome (full-width single-column)
struct Step3_Outcome: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    var onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What are you aiming for?")
                .font(.largeTitle).bold()
                .padding(.top, 8)

            if let track = vm.selectedTrack {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(outcomes(for: track)) { outcome in
                            SelectableCard(title: outcome.label, subtitle: nil, icon: "target", isSelected: vm.selectedOutcomeId == outcome.id) {
                                vm.selectedOutcomeId = outcome.id
                                vm.selectedOutcomeLabel = outcome.label
                                onNext()
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                Text("Select a track first.").foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Step 4: Event Check
struct Step4_EventCheck: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    var onNext: () -> Void

    private var canContinue: Bool { vm.noneSelected || !vm.selectedEventTypes.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Do you have any of these coming up? (Select all that apply)")
                .font(.largeTitle).bold()
                .padding(.top, 8)

            VStack(spacing: 12) {
                ForEach(PrepEventType.allCases) { eventType in
                    OptionCard(
                        title: eventType.displayName,
                        subtitle: "Plan around this event",
                        isSelected: vm.selectedEventTypes.contains(eventType)
                    ) {
                        vm.toggleEventType(eventType)
                    }
                }

                OptionCard(
                    title: "None yet",
                    subtitle: "I’ll add events later",
                    isSelected: vm.noneSelected
                ) {
                    vm.selectNoneYet()
                }
            }

            Spacer(minLength: 0)

            PrimaryButton(title: "Next", action: onNext)
                .disabled(!canContinue)
        }
    }
}

// MARK: - Step 5: Event Details (repeatable)
struct Step5_EventDetails: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    var onFinish: () -> Void

    private var selectedTypes: [PrepEventType] {
        PrepEventType.allCases.filter { vm.selectedEventTypes.contains($0) }
    }

    private var canFinish: Bool {
        guard !(vm.noneSelected || selectedTypes.isEmpty) else { return true }
        return selectedTypes.allSatisfy { type in
            vm.prepEvents.contains(where: { $0.type == type })
        }
    }

    private var finishTitle: String {
        canFinish ? "Finish" : "Add event details to finish"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add details for upcoming events")
                .font(.largeTitle).bold()
                .padding(.top, 8)

            if vm.noneSelected || selectedTypes.isEmpty {
                Text("No events yet. You can add them anytime from Review Schedule or Settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)

                PrimaryButton(title: finishTitle, action: onFinish)
                    .disabled(!canFinish)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(selectedTypes) { eventType in
                            EventInputSection(type: eventType, events: $vm.prepEvents)
                        }
                    }
                    .padding(.vertical, 4)
                }

                PrimaryButton(title: finishTitle, action: onFinish)
                    .disabled(!canFinish)
            }
        }
    }
}

struct EventInputSection: View {
    let type: PrepEventType
    @Binding var events: [PrepEvent]

    @State private var date: Date = Date()
    @State private var company: String = ""
    @State private var role: String = ""
    @State private var format: String = ""
    @State private var examType: String = ""
    @State private var domain: String = ""

    private var existingEvents: [PrepEvent] {
        events
            .filter { $0.type == type }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: type.systemImage)
                    .foregroundColor(.accentColor)
                Text(type.displayName)
                    .font(.headline)
            }

            DatePicker("Date", selection: $date, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.compact)

            if type == .interview {
                TextField("Company (optional)", text: $company)
                    .textInputAutocapitalization(.words)
                TextField("Role (optional)", text: $role)
                    .textInputAutocapitalization(.words)
                TextField("Format (optional)", text: $format)
                    .textInputAutocapitalization(.sentences)
            } else if type == .exam {
                TextField("Exam type (optional)", text: $examType)
                    .textInputAutocapitalization(.sentences)
                TextField("Domain or role (optional)", text: $domain)
                    .textInputAutocapitalization(.words)
            } else {
                TextField("Company (optional)", text: $company)
                    .textInputAutocapitalization(.words)
                TextField("Role (optional)", text: $role)
                    .textInputAutocapitalization(.words)
            }

            PrimaryButton(title: "Add \(type.shortLabel)") {
                addEvent()
            }

            if !existingEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Added")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(existingEvents) { event in
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Self.dateFormatter.string(from: event.date))
                                    .font(.subheadline.weight(.semibold))
                                if let subtitle = eventSubtitle(event) {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                events.removeAll { $0.id == event.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.card)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }

    private func addEvent() {
        let metadata = PrepEventMetadata(
            company: trimmed(company),
            role: trimmed(role),
            format: type == .interview ? trimmed(format) : nil,
            examType: type == .exam ? trimmed(examType) : nil,
            domain: type == .exam ? trimmed(domain) : nil
        )
        let event = PrepEvent(type: type, date: date, metadata: metadata)
        events.append(event)
        resetFields()
        Haptics.success()
    }

    private func resetFields() {
        date = Date()
        company = ""
        role = ""
        format = ""
        examType = ""
        domain = ""
    }

    private func eventSubtitle(_ event: PrepEvent) -> String? {
        var parts: [String] = []
        if let company = event.metadata.company, !company.isEmpty { parts.append(company) }
        if let role = event.metadata.role, !role.isEmpty { parts.append(role) }
        if type == .interview, let format = event.metadata.format, !format.isEmpty { parts.append(format) }
        if type == .exam, let examType = event.metadata.examType, !examType.isEmpty { parts.append(examType) }
        if type == .exam, let domain = event.metadata.domain, !domain.isEmpty { parts.append(domain) }
        if parts.isEmpty { return nil }
        return parts.joined(separator: " • ")
    }

    private func trimmed(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Reusable UI
struct SelectableCard: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { action() } }) {
            HStack(alignment: .center, spacing: 12) {
                if let icon { Image(systemName: icon).imageScale(.large).foregroundColor(.accentColor) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline).foregroundColor(.primary)
                    if let subtitle { Text(subtitle).font(.caption).foregroundColor(.secondary) }
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor) }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Palette.primary.opacity(0.1) : Palette.card)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Palette.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSelected)
    }
}


struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Palette.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
}

// MARK: - Helper Views

struct OptionCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.card)
                    .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 16 : 10, x: 0, y: isSelected ? 10 : 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.25) : Color.clear, radius: isSelected ? 12 : 0)
            )
            .scaleEffect(isSelected ? 0.985 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    OnboardingView(onFinished: { _ in })
}
