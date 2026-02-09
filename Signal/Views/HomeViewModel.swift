import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var recentContent: [LearningContent] = []
    @Published var upcomingRecallTasks: [RecallTask] = []
    @Published var totalConcepts: Int = 0
    @Published var averageMastery: Double = 0.0
    @Published var currentStreak: Int = 0
    
    init() {}
}

