import Foundation

// MARK: - Analyze API Models
struct AnalyzeRequest: Codable {
    let contentUrl: String
    let userIdHash: String
    // Role transition context (current_role → target_role).
    let goalId: String
    let goalDescription: String
    let careerStage: career_stage
    let interventionPolicy: String
    /// Question style/difficulty profile sent to backend
    /// (interview_prep | assessment_exam_prep | general_learning).
    let learningMode: String
    let knownConcepts: [String]
    let weakConcepts: [String]
    /// Optional local library digest for lightweight retrieval.
    let libraryDigest: [LibraryDigestItem]?
}

struct LibraryDigestItem: Codable {
    let contentId: String
    let title: String
    let concepts: [String]
    /// Unix seconds (local content creation time).
    let createdAt: Int
}

struct AnalyzeResponse: Codable {
    let traceId: String
    let concepts: [String]
    let relevanceScore: Double
    let learningValueScore: Double
    let decision: Decision
    let recallQuestions: [RecallQuestion]
    /// Optional retrieval metadata (absent when no retrieval happened).
    let relatedItems: [RelatedItem]?
    let retrievalUsed: Bool?
}

struct RelatedItem: Codable {
    let contentId: String
    let title: String
    let overlapConcepts: [String]
    let overlapScore: Int
}

enum Decision: String, Codable {
    case triggered
    case ignored
}

struct RecallQuestion: Codable, Identifiable {
    var id: String { question + (options?.joined() ?? "") }
    let question: String
    let type: QuestionType
    /// MCQ only: exactly 4 options.
    let options: [String]?
    /// MCQ only: index of correct option (0..<4). Backend sends correct_index.
    let correctIndex: Int?

    init(question: String, type: QuestionType, options: [String]? = nil, correctIndex: Int? = nil) {
        self.question = question
        self.type = type
        self.options = options
        self.correctIndex = correctIndex
    }
}

enum QuestionType: String, Codable {
    case open
    case mcq
}

struct ErrorResponse: Codable {
    let error: String
    let message: String?
    let details: [ValidationError]?
}

struct ValidationError: Codable {
    let path: [String]
    let message: String
}
