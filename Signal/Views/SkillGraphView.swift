import SwiftUI

// intentionally unused (out of scope)
import Combine

struct SkillGraphView: View {
    @StateObject private var viewModel = SkillGraphViewModel()
    @State private var selectedCategory: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Palette.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Overall Mastery
                        overallMasterySection
                        
                        // Category Filter
                        categoryFilterSection
                        
                        // Skills by Category
                        skillsSection
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Skill Graph")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.refresh() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Show insights
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(Palette.primary)
                    }
                }
            }
        }
    }
    
    private var overallMasterySection: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Overall Mastery")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Palette.textSecondary)
                    
                    Text("\(Int(viewModel.overallMastery * 100))%")
                        .font(Theme.Typography.largeTitle)
                        .foregroundColor(Palette.textPrimary)
                }
                
                Spacer()
                
                ScoreCircle(score: viewModel.overallMastery, size: 80)
            }
            
            Divider()
                .background(Palette.card)
            
            HStack(spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("\(viewModel.totalConcepts)")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Palette.textPrimary)
                    Text("Concepts")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("\(viewModel.masteredConcepts)")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.success)
                    Text("Mastered")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("\(viewModel.inProgressConcepts)")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.evaluationMedium)
                    Text("In Progress")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                CategoryChip(
                    name: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                ForEach(viewModel.categories, id: \.self) { category in
                    CategoryChip(
                        name: category,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
        }
    }
    
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(selectedCategory ?? "All Skills")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)

            if filteredConcepts.isEmpty {
                Text("No skills yet. Capture content to build your skill graph.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.card)
                    .cornerRadius(Theme.CornerRadius.md)
            } else {
                ForEach(filteredConcepts) { concept in
                    SkillCard(concept: concept)
                }
            }
        }
    }
    
    private var filteredConcepts: [Concept] {
        if let category = selectedCategory {
            return viewModel.concepts.filter { $0.category == category }
        }
        return viewModel.concepts
    }
}

struct CategoryChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(Theme.Typography.callout)
                .foregroundColor(isSelected ? .white : Palette.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isSelected ? Palette.primary : Palette.card)
                .cornerRadius(Theme.CornerRadius.lg)
        }
    }
}

struct SkillCard: View {
    let concept: Concept
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(concept.name)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Palette.textPrimary)
                        .fontWeight(.semibold)
                    
                    Text(concept.categoryPathLabel)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text("\(Int(concept.masteryLevel * 100))%")
                        .font(Theme.Typography.title3)
                        .foregroundColor(masteryColor)
                    
                    Text(masteryLevel)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
            }
            
            // Mastery Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Palette.card.opacity(0.3))
                    
                    Rectangle()
                        .fill(masteryColor)
                        .frame(width: geometry.size.width * concept.masteryLevel)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
            
            // Stats
            HStack(spacing: Theme.Spacing.lg) {
                StatItem(
                    icon: "target",
                    value: "\(concept.totalRecallAttempts)",
                    label: "Attempts"
                )
                
                StatItem(
                    icon: "checkmark.circle",
                    value: "\(concept.successfulRecalls)",
                    label: "Success"
                )
                
                if let lastRecall = concept.lastRecallDate {
                    StatItem(
                        icon: "clock",
                        value: timeAgo(from: lastRecall),
                        label: "Last Recall"
                    )
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var masteryColor: Color {
        Palette.primary
    }
    
    private var masteryLevel: String {
        if concept.masteryLevel >= 0.8 {
            return "Mastered"
        } else if concept.masteryLevel >= 0.5 {
            return "Proficient"
        } else if concept.masteryLevel >= 0.2 {
            return "Learning"
        } else {
            return "Beginner"
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))h"
        } else {
            return "\(Int(seconds / 86400))d"
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Palette.textSecondary)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Palette.textPrimary)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textSecondary)
            }
        }
    }
}

class SkillGraphViewModel: ObservableObject {
    @Published var concepts: [Concept] = []
    @Published var categories: [String] = []
    @Published var overallMastery: Double = 0.0
    @Published var totalConcepts: Int = 0
    @Published var masteredConcepts: Int = 0
    @Published var inProgressConcepts: Int = 0

    private let contentStore = ContentStore.shared

    init() {}

    func refresh() {
        let allConcepts = contentStore.all().flatMap(\.concepts)
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

        let mergedConcepts = Array(merged.values)
            .sorted { $0.masteryLevel > $1.masteryLevel }
        concepts = mergedConcepts
        categories = Array(Set(mergedConcepts.map(\.category))).sorted()
        totalConcepts = mergedConcepts.count
        masteredConcepts = mergedConcepts.filter { $0.masteryLevel >= 0.8 }.count
        inProgressConcepts = mergedConcepts.filter { $0.masteryLevel >= 0.2 && $0.masteryLevel < 0.8 }.count

        let conceptsWithMastery = mergedConcepts.filter { $0.totalRecallAttempts > 0 || $0.masteryLevel > 0 }
        if conceptsWithMastery.isEmpty {
            overallMastery = 0
        } else {
            let weighted = conceptsWithMastery.reduce((score: 0.0, weight: 0.0)) { partial, concept in
                let weight = concept.difficulty.masteryWeight
                return (
                    score: partial.score + (concept.masteryLevel * weight),
                    weight: partial.weight + weight
                )
            }
            overallMastery = weighted.weight > 0 ? weighted.score / weighted.weight : 0
        }
    }
}

#Preview {
    SkillGraphView()
}
