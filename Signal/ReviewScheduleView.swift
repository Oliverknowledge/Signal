import SwiftUI

struct ReviewScheduleView: View {
    @EnvironmentObject var captureCoordinator: GlobalCaptureCoordinator
    @State private var selectedDate: Date = Date()
    @State private var showingAddEvent = false
    @State private var editingEvent: PrepEvent?
    @State private var pendingDeleteEvent: PrepEvent?
    @ObservedObject private var scheduledStore = ScheduledRecallStore.shared
    @EnvironmentObject var appState: AppState

    private var upcomingEvents: [CalendarEvent] {
        calendarEvents.filter { $0.date >= Date() }
    }

    private var filteredScheduledItems: [ScheduledRecallItem] {
        scheduledStore.all().filter { item in
            !RecallSessionStore.shared.isMuted(contentId: item.contentId)
        }
    }

    private var calendarEvents: [CalendarEvent] {
        let recallEvents = filteredScheduledItems.map { item in
            CalendarEvent(
                id: item.id,
                date: item.fireDate,
                title: "Recall: \(item.contentTitle)",
                subtitle: "Quick recall",
                kind: .recall,
                isAllDay: false
            )
        }
        let prepEvents = appState.prepEvents.map { event in
            CalendarEvent(
                id: event.id,
                date: event.date,
                title: eventTitle(event),
                subtitle: eventSubtitle(event),
                kind: .prep,
                isAllDay: true
            )
        }
        return (recallEvents + prepEvents).sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.primaryBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        calendarSection
                        upcomingSection
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Review Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    GlobalCaptureToolbarButton()
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
            Text("This removes the prep event from your schedule.")
        }
    }
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("This Month")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)
            
            CalendarGrid(selectedDate: $selectedDate, events: calendarEvents)
                .frame(height: 300)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.md)
                .padding(.bottom, Theme.Spacing.sm)
            
            HStack(spacing: Theme.Spacing.sm) {
                legendDot(color: Theme.Colors.primaryAccent)
                Text("Scheduled Review")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                
                Spacer()

                legendDot(color: Theme.Colors.success)
                Text("Prep Event")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
    }
    
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Upcoming Schedule")
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Menu {
                    Button("Add event") {
                        showingAddEvent = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
            }
            if upcomingEvents.isEmpty {
                Text("No items scheduled yet. You'll see upcoming reviews and prep events here.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.CornerRadius.md)
            } else {
                ForEach(upcomingEvents, id: \.id) { event in
                    if event.kind == .prep, let prepEvent = prepEvent(for: event) {
                        CalendarEventRow(
                            event: event,
                            onEdit: { editingEvent = prepEvent },
                            onDelete: { pendingDeleteEvent = prepEvent }
                        )
                    } else {
                        CalendarEventRow(event: event)
                    }
                }
            }
        }
    }
    
    private func legendDot(color: Color) -> some View {
        Circle().fill(color).frame(width: 8, height: 8)
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

    private func eventSubtitle(_ event: PrepEvent) -> String {
        var parts: [String] = []
        if let company = event.metadata.company, !company.isEmpty { parts.append(company) }
        if let role = event.metadata.role, !role.isEmpty { parts.append(role) }
        if event.type == .interview, let format = event.metadata.format, !format.isEmpty { parts.append(format) }
        if event.type == .exam, let examType = event.metadata.examType, !examType.isEmpty { parts.append(examType) }
        if event.type == .exam, let domain = event.metadata.domain, !domain.isEmpty { parts.append(domain) }
        return parts.isEmpty ? "Prep event" : parts.joined(separator: " • ")
    }

    private func prepEvent(for calendarEvent: CalendarEvent) -> PrepEvent? {
        guard calendarEvent.kind == .prep else { return nil }
        return appState.prepEvents.first(where: { $0.id == calendarEvent.id })
    }
}

struct CalendarGrid: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]

    private let calendar = Calendar.current

    var body: some View {
        let days = daysInCurrentMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text(monthYearString(for: selectedDate))
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)

            LazyVGrid(columns: columns, spacing: 6) {
                let weekdaySymbols = ["S","M","T","W","T","F","S"]
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    CalendarDayCell(date: day, isToday: calendar.isDateInToday(day), markers: markers(for: day))
                        .onTapGesture {
                            if day != Date.distantPast {
                                selectedDate = day
                            }
                        }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
    }

    private func daysInCurrentMonth() -> [Date] {
        let range = calendar.range(of: .day, in: .month, for: selectedDate) ?? 1..<31
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) ?? Date()
        let weekdayOffset = (calendar.component(.weekday, from: startOfMonth) + 6) % 7
        let prefix = Array(repeating: Date.distantPast, count: weekdayOffset)
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
        return prefix + days
    }

    private func markers(for date: Date) -> [Color] {
        guard date != Date.distantPast else { return [] }
        let dayEvents = events.filter { calendar.isDate($0.date, inSameDayAs: date) }
        if dayEvents.isEmpty { return [] }

        var markers: [Color] = []
        if dayEvents.contains(where: { $0.kind == .recall }) {
            markers.append(Theme.Colors.primaryAccent)
        }
        if dayEvents.contains(where: { $0.kind == .prep }) {
            markers.append(Theme.Colors.success)
        }
        return markers
    }
    
    private func monthYearString(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date)
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let markers: [Color]
    
    var body: some View {
        if date == Date.distantPast {
            Color.clear.frame(height: 36)
        } else {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                
                HStack(spacing: 2) {
                    ForEach(0..<markers.count, id: \.self) { idx in
                        Circle().fill(markers[idx]).frame(width: 4, height: 4)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(height: 36)
            .background(isToday ? Theme.Colors.primaryAccent.opacity(0.12) : Color.clear)
            .cornerRadius(6)
        }
    }
}

struct CalendarEventRow: View {
    let event: CalendarEvent
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: iconName)
                .foregroundColor(accentColor)
                .frame(width: 44, height: 44)
                .background(accentColor.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(event.title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(event.subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
            
            Spacer()
            
            Text(timeString(event.date, isAllDay: event.isAllDay))
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)

            if let onEdit = onEdit, let onDelete = onDelete {
                Menu {
                    Button("Edit event") {
                        onEdit()
                    }
                    Button("Delete event", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .padding(.leading, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var accentColor: Color {
        switch event.kind {
        case .prep:
            return Theme.Colors.success
        case .recall:
            return Theme.Colors.primaryAccent
        }
    }

    private var iconName: String {
        switch event.kind {
        case .prep:
            return "briefcase"
        case .recall:
            return "calendar"
        }
    }

    private func timeString(_ date: Date, isAllDay: Bool) -> String {
        if isAllDay { return "All day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE h:mm a"
        return fmt.string(from: date)
    }
}

struct CalendarEvent: Identifiable, Hashable {
    enum Kind: Hashable {
        case recall
        case prep
    }

    let id: UUID
    let date: Date
    let title: String
    let subtitle: String
    let kind: Kind
    let isAllDay: Bool
}

#Preview {
    ReviewScheduleView()
        .environmentObject(AppState())
        .environmentObject(GlobalCaptureCoordinator())
}
