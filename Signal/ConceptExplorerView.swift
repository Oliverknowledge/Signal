import SwiftUI
import Combine

struct ConceptExplorerView: View {
    @StateObject private var viewModel = ConceptExplorerViewModel()
    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedDifficulty: DifficultyLevel? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.primaryBackground.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.md) {
                    filters
                    list
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Concepts")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.refresh() }
        }
    }
    
    private var filters: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Search concepts", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .frame(height: 40)
                    .background(Theme.Colors.contentSurface)
                    .cornerRadius(Theme.CornerRadius.md)
                
                Menu {
                    Button("All Difficulties") { selectedDifficulty = nil }
                    ForEach([DifficultyLevel.beginner, .intermediate, .advanced, .expert], id: \.self) { level in
                        Button(level.rawValue) { selectedDifficulty = level }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedDifficulty?.rawValue ?? "All")
                    }
                    .foregroundColor(Theme.Colors.textOnLight)
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(height: 40)
                    .background(Theme.Colors.contentSurface)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    CategoryChip(name: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }
                    ForEach(viewModel.categories, id: \.self) { cat in
                        CategoryChip(name: cat, isSelected: selectedCategory == cat) { selectedCategory = cat }
                    }
                }
            }
        }
    }
    
    private var list: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if filteredConcepts.isEmpty {
                    Text("No concepts yet. Analyze content to populate this view.")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textMuted)
                        .padding(Theme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.contentSurface)
                        .cornerRadius(Theme.CornerRadius.md)
                } else {
                    ForEach(filteredConcepts) { concept in
                        ConceptExplorerRow(concept: concept)
                    }
                }
            }
        }
    }
    
    private var filteredConcepts: [Concept] {
        viewModel.concepts.filter { c in
            let matchesText = searchText.isEmpty || c.name.localizedCaseInsensitiveContains(searchText)
            let matchesCat = selectedCategory == nil || c.category == selectedCategory
            let matchesDiff = selectedDifficulty == nil || c.difficulty == selectedDifficulty
            return matchesText && matchesCat && matchesDiff
        }
    }
}

struct ConceptExplorerRow: View {
    let concept: Concept
    @State private var showPrereqs = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(concept.name)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textOnLight)
                        .fontWeight(.semibold)
                    Text(concept.categoryPathLabel)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                Spacer()
                Text(concept.difficulty.rawValue)
                    .font(Theme.Typography.caption)
                    .foregroundColor(diffColor)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(diffColor.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.Colors.secondaryBackground.opacity(0.3))
                    Rectangle().fill(Theme.Colors.mastery).frame(width: geometry.size.width * max(0, concept.masteryLevel))
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
            
            HStack {
                Button(action: { withAnimation { showPrereqs.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: showPrereqs ? "chevron.up" : "chevron.down")
                        Text("Prerequisites")
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.primaryAccent)
                }
                Spacer()
                Text("\(Int(concept.masteryLevel * 100))% mastery")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
            
            if showPrereqs && !concept.effectivePrerequisites.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(concept.effectivePrerequisites, id: \.self) { p in
                        HStack(spacing: Theme.Spacing.xs) {
                            Circle().fill(Theme.Colors.secondaryBackground).frame(width: 6, height: 6)
                            Text(p)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textOnLight)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.contentSurface)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var diffColor: Color {
        switch concept.difficulty {
        case .beginner: return Theme.Colors.success
        case .intermediate: return Theme.Colors.evaluationMedium
        case .advanced: return Theme.Colors.primaryAccent
        case .expert: return Theme.Colors.evaluationLow
        }
    }
}

final class ConceptExplorerViewModel: ObservableObject {
    @Published var concepts: [Concept] = []
    @Published var categories: [String] = []
    
    private var contentStore = ContentStore.shared
    
    init() {
        refresh()
    }
    
    func refresh() {
        let allConcepts = contentStore.all().flatMap { $0.concepts }
        var merged: [String: Concept] = [:]

        for concept in allConcepts {
            let key = concept.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !key.isEmpty else { continue }

            if var existing = merged[key] {
                existing.totalRecallAttempts += concept.totalRecallAttempts
                existing.successfulRecalls += concept.successfulRecalls
                existing.lastRecallDate = [existing.lastRecallDate, concept.lastRecallDate]
                    .compactMap { $0 }
                    .max()

                if existing.totalRecallAttempts > 0 {
                    existing.masteryLevel = Double(existing.successfulRecalls) / Double(existing.totalRecallAttempts)
                } else {
                    existing.masteryLevel = max(existing.masteryLevel, concept.masteryLevel)
                }
                merged[key] = existing
            } else {
                merged[key] = concept
            }
        }

        concepts = Array(merged.values)
        categories = Array(Set(concepts.map(\.category))).sorted()
    }
}

#Preview {
    ConceptExplorerView()
}
