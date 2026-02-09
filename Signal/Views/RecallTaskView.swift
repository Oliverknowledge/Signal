import SwiftUI
import Combine

struct RecallTaskView: View {
    let task: RecallTask
    @StateObject private var viewModel: RecallTaskViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(task: RecallTask) {
        self.task = task
        _viewModel = StateObject(wrappedValue: RecallTaskViewModel(task: task))
    }
    
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    if !viewModel.isCompleted {
                        questionSection
                        answerSection
                    } else {
                        resultSection
                        emotionalReflectionSection
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Active Recall")
    }
    
    private var questionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: iconForType(task.type))
                    .font(.title2)
                    .foregroundColor(Palette.primary)
                
                Text(task.type.rawValue)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)
            }
            
            Text(task.question)
                .font(Theme.Typography.title2)
                .foregroundColor(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    @ViewBuilder
    private var answerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Your Answer")
                .font(Theme.Typography.headline)
                .foregroundColor(Palette.textPrimary)
            
            switch task.type {
            case .multipleChoice:
                multipleChoiceOptions
            case .openEnded:
                openEndedInput
            case .codeComprehension:
                openEndedInput
            }
            
            SignalButton(title: "Submit", style: .primary) {
                viewModel.submitAnswer()
            }
            .disabled(viewModel.selectedAnswer.isEmpty)
            .opacity(viewModel.selectedAnswer.isEmpty ? 0.5 : 1.0)
        }
    }
    
    private var multipleChoiceOptions: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(task.options ?? [], id: \.self) { option in
                Button {
                    viewModel.selectedAnswer = option
                } label: {
                    HStack {
                        Text(option)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Palette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if viewModel.selectedAnswer == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Palette.primary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        viewModel.selectedAnswer == option ?
                        Palette.primary.opacity(0.1) :
                        Palette.card
                    )
                    .cornerRadius(Theme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(
                                viewModel.selectedAnswer == option ?
                                Palette.primary :
                                Color.clear,
                                lineWidth: 2
                            )
                    )
                }
            }
        }
    }
    
    private var openEndedInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            TextEditor(text: $viewModel.selectedAnswer)
                .frame(height: 150)
                .padding(Theme.Spacing.sm)
                .background(Palette.card)
                .cornerRadius(Theme.CornerRadius.md)
                .foregroundColor(Palette.textPrimary)
                .font(Theme.Typography.body)
            
            Text("\(viewModel.selectedAnswer.count) characters")
                .font(Theme.Typography.caption)
                .foregroundColor(Palette.textSecondary)
        }
    }
    
    private var resultSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Result indicator
            ZStack {
                Circle()
                    .fill(Palette.primary)
                    .frame(width: 100, height: 100)
                
                Image(systemName: viewModel.wasCorrect ? "checkmark" : "lightbulb.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text(viewModel.wasCorrect ? "Great work!" : "Keep learning")
                .font(Theme.Typography.title1)
                .foregroundColor(Palette.textPrimary)
            
            // Your answer
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Your Answer")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Palette.textSecondary)
                
                Text(viewModel.selectedAnswer)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textPrimary)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.card)
                    .cornerRadius(Theme.CornerRadius.md)
            }
            
            // Correct answer (if wrong)
            if !viewModel.wasCorrect {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Correct Answer")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                    
                    Text(task.correctAnswer)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textOnLight)
                        .padding(Theme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.success.opacity(0.1))
                        .cornerRadius(Theme.CornerRadius.md)
                }
            }
            
            SignalButton(title: "Continue", style: .primary) {
                dismiss()
            }
        }
    }
    
    private var emotionalReflectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("How did this feel?")
                .font(Theme.Typography.title3)
                .foregroundColor(Palette.textPrimary)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Energy Level")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)
                
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            viewModel.energyLevel = level
                        } label: {
                            Circle()
                                .fill(viewModel.energyLevel >= level ? Palette.primary : Palette.card)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("\(level)")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(Palette.textPrimary)
                                )
                        }
                    }
                }
                
                HStack {
                    Text("Draining")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                    Spacer()
                    Text("Energizing")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Palette.card)
            .cornerRadius(Theme.CornerRadius.md)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Challenge Level")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Palette.textSecondary)
                
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            viewModel.challengeLevel = level
                        } label: {
                            Circle()
                                .fill(viewModel.challengeLevel >= level ? Palette.primary : Palette.card)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("\(level)")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(Palette.textPrimary)
                                )
                        }
                    }
                }
                
                HStack {
                    Text("Easy")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                    Spacer()
                    Text("Challenging")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Palette.card)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
    
    private func iconForType(_ type: RecallType) -> String {
        switch type {
        case .multipleChoice: return "checkmark.circle"
        case .openEnded: return "text.bubble"
        case .codeComprehension: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

class RecallTaskViewModel: ObservableObject {
    let task: RecallTask
    @Published var selectedAnswer: String = ""
    @Published var isCompleted: Bool = false
    @Published var wasCorrect: Bool = false
    @Published var energyLevel: Int = 0
    @Published var challengeLevel: Int = 0
    
    init(task: RecallTask) {
        self.task = task
    }
    
    func submitAnswer() {
        // Simple comparison for demo - in real app, use more sophisticated matching
        if task.type == .multipleChoice {
            wasCorrect = selectedAnswer == task.correctAnswer
        } else {
            // For open-ended, we'd use LLM evaluation in production
            wasCorrect = selectedAnswer.lowercased().contains(task.correctAnswer.lowercased().components(separatedBy: " ").first ?? "")
        }
        
        withAnimation {
            isCompleted = true
        }
    }
}

#Preview {
    NavigationView {
        RecallTaskView(task: RecallTask(
            conceptId: UUID(),
            type: .multipleChoice,
            question: "What is the main benefit of using smart pointers in C++?",
            options: [
                "Faster execution",
                "Automatic memory management",
                "Better syntax",
                "Smaller binary size"
            ],
            correctAnswer: "Automatic memory management",
            scheduledDate: Date()
        ))
    }
}

