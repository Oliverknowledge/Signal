import Foundation

// MARK: - Integration helpers

/// Ensure Share/Add Content flow checks onboarding state.
/// Call this before presenting capture/share UI.
func ensureOnboardingFlow(presentOnboarding: @escaping () -> Void) {
    if !AppStorage.hasOnboarded || AppStorage.selectedGoalId == nil {
        presentOnboarding()
    }
}

/// Build the analysis context payload parts.
struct AnalyzePayloadParts {
    // Role transition context (current_role → target_role).
    let goalId: String
    let goalDescription: String
    let careerStage: career_stage
    let knownConcepts: [String]
    let weakConcepts: [String]
}

func buildAnalyzePayloadParts() -> AnalyzePayloadParts? {
    guard let ctx = AppStorage.currentAnalysisContext() else { return nil }
    return AnalyzePayloadParts(goalId: ctx.goalId, goalDescription: ctx.goalDescription, careerStage: ctx.careerStage, knownConcepts: ctx.knownConcepts, weakConcepts: ctx.weakConcepts)
}

@MainActor
func completeOnboarding(result: OnboardingResult, appState: AppState? = nil) {
    AppStorage.selectedFieldId = result.fieldId
    AppStorage.selectedFieldTitle = result.fieldTitle
    AppStorage.selectedGoalId = result.goalId
    AppStorage.selectedGoalTitle = result.goalTitle
    AppStorage.selectedGoalDescription = result.goalDescription
    AppStorage.careerStage = .retraining
    AppStorage.hasOnboarded = true
    AppStorage.setWeakConcepts(result.weakConcepts)
    AppStorage.setKnownConcepts([])
    AppStorage.prepEvents = result.prepEvents

    guard let appState else { return }
    appState.prepEvents = result.prepEvents
    let alreadyExists = appState.learningGoals.contains { $0.title == result.goalTitle }
    if !alreadyExists {
        let goal = LearningGoal(title: result.goalTitle, targetDate: Date())
        appState.addGoal(goal)
    }
}
