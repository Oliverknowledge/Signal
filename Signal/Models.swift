import Foundation

// MARK: - Career Stage
// Lightweight enum for career transition context; logged only (no behavior changes).
enum career_stage: String, Codable, CaseIterable {
    case exploring
    case retraining
    case interviewing
}

// MARK: - Prep Events
enum PrepEventType: String, Codable, CaseIterable, Identifiable {
    case interview
    case exam
    case deadline

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .interview: return "Interview"
        case .exam: return "Job exam / assessment"
        case .deadline: return "Application deadline"
        }
    }

    var shortLabel: String {
        switch self {
        case .interview: return "Interview"
        case .exam: return "Assessment"
        case .deadline: return "Deadline"
        }
    }

    var notificationNoun: String {
        switch self {
        case .interview: return "interview"
        case .exam: return "assessment"
        case .deadline: return "application deadline"
        }
    }

    var systemImage: String {
        switch self {
        case .interview: return "person.bubble"
        case .exam: return "doc.text.magnifyingglass"
        case .deadline: return "calendar.badge.exclamationmark"
        }
    }
}

struct PrepEventMetadata: Codable, Hashable {
    var company: String?
    var role: String?
    var format: String?
    var examType: String?
    var domain: String?
}

struct PrepEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var type: PrepEventType
    var date: Date
    var metadata: PrepEventMetadata
    var calendarEventIdentifier: String?

    init(id: UUID = UUID(), type: PrepEventType, date: Date, metadata: PrepEventMetadata = PrepEventMetadata(), calendarEventIdentifier: String? = nil) {
        self.id = id
        self.type = type
        self.date = date
        self.metadata = metadata
        self.calendarEventIdentifier = calendarEventIdentifier
    }

    func daysUntil(from reference: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: reference)
        let eventDay = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: start, to: eventDay)
        return max(0, components.day ?? 0)
    }

    func countdownLabel(from reference: Date = Date()) -> String {
        let days = daysUntil(from: reference)
        if days == 0 { return "\(type.shortLabel) today" }
        if days == 1 { return "\(type.shortLabel) tomorrow" }
        return "\(type.shortLabel) in \(days) days"
    }
}

// MARK: - Ignore Reasons
enum IgnoreReason: String, Codable {
    case low_relevance_for_role
    case low_learning_depth
    case poor_interruption_timing

    /// Explain why ignored content was not worth interrupting for.
    static func fromScores(relevance: Double, learningValue: Double, triggerThreshold: Double = 0.7) -> IgnoreReason {
        if relevance < triggerThreshold && learningValue >= triggerThreshold {
            return .low_relevance_for_role
        }
        if learningValue < triggerThreshold && relevance >= triggerThreshold {
            return .low_learning_depth
        }

        // Both are below threshold. If both are moderately strong, treat as timing.
        let timingThreshold = max(triggerThreshold - 0.15, 0.0)
        if relevance >= timingThreshold && learningValue >= timingThreshold {
            return .poor_interruption_timing
        }

        return (relevance <= learningValue) ? .low_relevance_for_role : .low_learning_depth
    }
}

// MARK: - Decision Confidence
enum DecisionConfidence: String, Codable {
    case high
    case borderline
    case low

    // Confidence bands are derived from the same inputs as the policy decision.
    // "high" = clearly worth interrupting, "low" = clearly not worth interrupting.
    static func fromScores(
        relevance: Double,
        learningValue: Double,
        conceptCount: Int,
        interventionPolicy: String
    ) -> DecisionConfidence {
        let policy = (interventionPolicy == "aggressive") ? "aggressive" : "focused"
        if policy == "focused" {
            if relevance >= 0.85 && learningValue >= 0.85 && conceptCount >= 6 { return .high }
            if relevance < 0.65 || learningValue < 0.65 || conceptCount < 4 { return .low }
            return .borderline
        }

        if relevance >= 0.75 && learningValue >= 0.75 && conceptCount >= 4 { return .high }
        if relevance < 0.55 || learningValue < 0.55 || conceptCount < 2 { return .low }
        return .borderline
    }
}

// MARK: - Learning Content
struct LearningContent: Identifiable, Codable {
    let id: UUID
    let url: String
    let title: String
    let source: ContentSource
    let dateShared: Date
    let analysisStatus: AnalysisStatus
    var concepts: [Concept]
    var relevanceScore: Double
    var learningValue: Double
    var agentReasoning: [ReasoningStep]
    var traceId: UUID?
    var lastFeedback: String?
    /// Present when a piece of content was ignored (explains why it was skipped).
    var ignoreReason: IgnoreReason?
    /// Present when decision was "triggered"; used for Active Recall flow.
    var recallQuestions: [RecallQuestion]?

    init(id: UUID = UUID(), url: String, title: String, source: ContentSource, dateShared: Date = Date(), analysisStatus: AnalysisStatus = .pending, concepts: [Concept] = [], relevanceScore: Double = 0.0, learningValue: Double = 0.0, agentReasoning: [ReasoningStep] = [], traceId: UUID? = nil, lastFeedback: String? = nil, ignoreReason: IgnoreReason? = nil, recallQuestions: [RecallQuestion]? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.source = source
        self.dateShared = dateShared
        self.analysisStatus = analysisStatus
        self.concepts = concepts
        self.relevanceScore = relevanceScore
        self.learningValue = learningValue
        self.agentReasoning = agentReasoning
        self.traceId = traceId
        self.lastFeedback = lastFeedback
        self.ignoreReason = ignoreReason
        self.recallQuestions = recallQuestions
    }
}

enum ContentSource: String, Codable {
    case youtube = "YouTube"
    case webpage = "Web"
}

enum AnalysisStatus: String, Codable {
    case pending = "Analyzing..."
    case completed = "Analyzed"
    case failed = "Analysis Failed"
    case belowThreshold = "Ignored"
}

// MARK: - Concepts & Skills
struct Concept: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let category: String
    let subcategory: String?
    let difficulty: DifficultyLevel
    let prerequisites: [String]
    var masteryLevel: Double // 0.0 - 1.0
    var confidenceScore: Double // 0.0 - 1.0
    var lastRecallDate: Date?
    var totalRecallAttempts: Int
    var successfulRecalls: Int
    
    init(id: UUID = UUID(), name: String, category: String, subcategory: String? = nil, difficulty: DifficultyLevel, prerequisites: [String] = [], masteryLevel: Double = 0.0, confidenceScore: Double = 0.0, lastRecallDate: Date? = nil, totalRecallAttempts: Int = 0, successfulRecalls: Int = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.difficulty = difficulty
        self.prerequisites = prerequisites
        self.masteryLevel = masteryLevel
        self.confidenceScore = confidenceScore
        self.lastRecallDate = lastRecallDate
        self.totalRecallAttempts = totalRecallAttempts
        self.successfulRecalls = successfulRecalls
    }
}

enum DifficultyLevel: String, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
}

extension DifficultyLevel {
    /// Higher-level concepts contribute more to aggregate mastery.
    var masteryWeight: Double {
        switch self {
        case .beginner: return 1.0
        case .intermediate: return 1.3
        case .advanced: return 1.7
        case .expert: return 2.1
        }
    }
}

struct ConceptProfile {
    let category: String
    let subcategory: String
    let difficulty: DifficultyLevel
    let prerequisites: [String]
}

enum ConceptClassifier {
    static func profile(for conceptName: String) -> ConceptProfile {
        let ctx = MatchContext(conceptName)
        let language = inferLanguage(in: ctx)
        let category = inferCategory(in: ctx, language: language)
        let subcategory = inferSubcategory(in: ctx, category: category, language: language)
        let difficulty = inferDifficulty(in: ctx, language: language)
        let prerequisites = inferPrerequisites(in: ctx, category: category, difficulty: difficulty)
        return ConceptProfile(
            category: category,
            subcategory: subcategory,
            difficulty: difficulty,
            prerequisites: prerequisites
        )
    }

    static func makeConcept(name: String) -> Concept {
        let profile = profile(for: name)
        return Concept(
            name: name,
            category: profile.category,
            subcategory: profile.subcategory,
            difficulty: profile.difficulty,
            prerequisites: profile.prerequisites,
            masteryLevel: 0.0,
            confidenceScore: 0.0
        )
    }

    static func enrich(_ concept: Concept) -> Concept {
        let profile = profile(for: concept.name)
        let category = normalizedCategory(existing: concept.category, fallback: profile.category)
        let subcategory = normalizedSubcategory(existing: concept.subcategory, category: category, fallback: profile.subcategory)
        let prerequisites = concept.prerequisites.isEmpty ? profile.prerequisites : concept.prerequisites

        let shouldReclassifyDifficulty =
            isPlaceholderCategory(concept.category) ||
            concept.prerequisites.isEmpty
        let difficulty = shouldReclassifyDifficulty ? profile.difficulty : concept.difficulty

        return Concept(
            id: concept.id,
            name: concept.name,
            category: category,
            subcategory: subcategory,
            difficulty: difficulty,
            prerequisites: prerequisites,
            masteryLevel: concept.masteryLevel,
            confidenceScore: concept.confidenceScore,
            lastRecallDate: concept.lastRecallDate,
            totalRecallAttempts: concept.totalRecallAttempts,
            successfulRecalls: concept.successfulRecalls
        )
    }

    private struct MatchContext {
        let raw: String
        let tokens: Set<String>

        init(_ value: String) {
            let lowered = value.lowercased()
            self.raw = lowered
            let tokenized = lowered
                .replacingOccurrences(of: "[^a-z0-9+#]+", with: " ", options: .regularExpression)
                .split(separator: " ")
                .map(String.init)
            self.tokens = Set(tokenized)
        }
    }

    private static func inferLanguage(in ctx: MatchContext) -> String? {
        if ctx.raw.contains("c++") || ctx.raw.contains("c plus plus") || ctx.tokens.contains("cpp") {
            return "C++"
        }
        if ctx.raw.contains("c#") || ctx.raw.contains("c sharp") || ctx.tokens.contains("csharp") {
            return "C#"
        }
        if ctx.tokens.contains("typescript") { return "TypeScript" }
        if ctx.tokens.contains("javascript") || ctx.raw.contains("node.js") || ctx.tokens.contains("nodejs") {
            return "JavaScript"
        }
        if ctx.tokens.contains("python") { return "Python" }
        if ctx.tokens.contains("swift") { return "Swift" }
        if ctx.tokens.contains("rust") { return "Rust" }
        if ctx.tokens.contains("kotlin") { return "Kotlin" }
        if ctx.tokens.contains("java") { return "Java" }
        if ctx.tokens.contains("golang") { return "Go" }
        if ctx.tokens.contains("go"), containsAny(in: ctx, tokens: ["goroutine", "interface", "struct", "channel", "pointer", "package"]) {
            return "Go"
        }
        if ctx.tokens.contains("php") { return "PHP" }
        if ctx.tokens.contains("ruby") { return "Ruby" }
        return nil
    }

    private static func inferCategory(in ctx: MatchContext, language: String?) -> String {
        if language != nil { return "Programming" }

        if containsAny(in: ctx, tokens: ["sql", "database", "postgres", "postgresql", "mysql", "sqlite", "indexing", "normalization", "schema", "query"]) {
            return "Data"
        }
        if containsAny(in: ctx, tokens: ["machine", "learning", "neural", "regression", "classification", "transformer", "llm", "embedding", "prompt"]) {
            return "AI/ML"
        }
        if containsAny(in: ctx, tokens: ["docker", "kubernetes", "terraform", "devops", "ci", "cd", "pipeline", "aws", "gcp", "azure", "infrastructure"]) {
            return "DevOps"
        }
        if containsAny(in: ctx, tokens: ["oauth", "jwt", "auth", "authentication", "authorization", "encryption", "xss", "csrf", "security"]) {
            return "Security"
        }
        if containsAny(in: ctx, tokens: ["api", "rest", "graphql", "http", "endpoint", "frontend", "backend", "react", "css", "html"]) {
            return "Web Development"
        }
        if containsAny(in: ctx, tokens: ["test", "testing", "tdd", "refactor", "clean", "pattern", "architecture", "maintainability"]) {
            return "Engineering"
        }
        if containsAny(in: ctx, tokens: ["variable", "variables", "loop", "loops", "function", "functions", "algorithm", "algorithms", "recursion", "pointer", "pointers", "class", "classes", "object", "objects", "inheritance", "polymorphism", "encapsulation", "data", "structure", "structures", "array", "arrays"]) {
            return "Programming"
        }
        return "General"
    }

    private static func inferSubcategory(in ctx: MatchContext, category: String, language: String?) -> String {
        if let language { return language }

        switch category {
        case "Programming":
            if containsAny(in: ctx, tokens: ["pointer", "pointers", "ownership", "borrow", "allocator", "heap", "stack", "memory"]) {
                return "Memory Management"
            }
            if containsAny(in: ctx, tokens: ["class", "classes", "object", "objects", "inheritance", "polymorphism", "encapsulation", "oop"]) || ctx.raw.contains("object oriented") {
                return "Object-Oriented Programming"
            }
            if containsAny(in: ctx, tokens: ["algorithm", "algorithms", "array", "arrays", "hashmap", "hash", "tree", "graph", "queue", "stack", "recursion", "complexity"]) {
                return "Algorithms & Data Structures"
            }
            if containsAny(in: ctx, tokens: ["concurrency", "thread", "threads", "async", "await", "parallel", "mutex", "race", "deadlock"]) {
                return "Concurrency"
            }
            return "Fundamentals"
        case "Web Development":
            if containsAny(in: ctx, tokens: ["frontend", "react", "css", "html", "dom", "ui"]) {
                return "Frontend"
            }
            if containsAny(in: ctx, tokens: ["api", "rest", "graphql", "backend", "server", "http", "endpoint"]) {
                return "Backend APIs"
            }
            return "Web Fundamentals"
        case "Data":
            if containsAny(in: ctx, tokens: ["sql", "database", "postgres", "mysql", "indexing", "schema", "query", "join"]) {
                return "Databases"
            }
            return "Data Engineering"
        case "AI/ML":
            if containsAny(in: ctx, tokens: ["llm", "transformer", "embedding", "prompt", "token"]) {
                return "LLM & NLP"
            }
            if containsAny(in: ctx, tokens: ["neural", "gradient", "backpropagation", "cnn", "rnn"]) {
                return "Deep Learning"
            }
            return "Machine Learning"
        case "DevOps":
            if containsAny(in: ctx, tokens: ["docker", "kubernetes", "container", "containers"]) {
                return "Containers & Orchestration"
            }
            if containsAny(in: ctx, tokens: ["ci", "cd", "pipeline", "github", "actions"]) {
                return "CI/CD"
            }
            return "Infrastructure"
        case "Security":
            if containsAny(in: ctx, tokens: ["oauth", "jwt", "auth", "authentication", "authorization"]) {
                return "Authentication"
            }
            if containsAny(in: ctx, tokens: ["encryption", "hashing", "cipher", "tls"]) {
                return "Cryptography"
            }
            return "Application Security"
        case "Engineering":
            if containsAny(in: ctx, tokens: ["test", "testing", "tdd", "unit", "integration", "mock"]) {
                return "Testing"
            }
            return "Best Practices"
        default:
            return "Best Practices"
        }
    }

    private static func inferDifficulty(in ctx: MatchContext, language: String?) -> DifficultyLevel {
        if let language,
           ctx.raw.trimmingCharacters(in: .whitespacesAndNewlines) == language.lowercased() {
            return .beginner
        }

        if containsAny(in: ctx, tokens: ["paxos", "raft", "formal", "verification", "metaprogramming", "kernel", "lockfree", "lock-free", "compiler"]) {
            return .expert
        }

        if containsAny(in: ctx, tokens: ["variable", "variables", "loop", "loops", "if", "else", "function", "functions", "syntax", "string", "strings", "array", "arrays", "datatype", "datatypes"]) ||
            containsAny(in: ctx, phrases: ["control flow", "basic syntax", "data types", "intro to", "introduction to", "fundamentals of"]) {
            return .beginner
        }

        if containsAny(in: ctx, tokens: ["pointer", "pointers", "multithreading", "concurrency", "race", "deadlock", "distributed", "sharding", "optimization", "unsafe", "profiling", "memory"]) ||
            containsAny(in: ctx, phrases: ["memory management", "thread safety", "pointer arithmetic", "distributed systems"]) {
            return .advanced
        }

        if containsAny(in: ctx, tokens: ["class", "classes", "object", "objects", "inheritance", "polymorphism", "encapsulation", "oop", "recursion", "sql", "join", "rest", "graphql", "testing", "pattern", "refactor", "interface"]) ||
            containsAny(in: ctx, phrases: ["object oriented", "dependency injection", "design pattern"]) {
            return .intermediate
        }

        if containsAny(in: ctx, tokens: ["basics", "beginner", "foundation", "foundations"]) {
            return .beginner
        }
        if containsAny(in: ctx, tokens: ["advanced", "scalability", "performance"]) {
            return .advanced
        }

        return .intermediate
    }

    private static func inferPrerequisites(
        in ctx: MatchContext,
        category: String,
        difficulty: DifficultyLevel
    ) -> [String] {
        if containsAny(in: ctx, tokens: ["pointer", "pointers", "memory", "heap", "stack"]) {
            return [
                "Variables and data types",
                "Memory addresses",
                "Control flow"
            ]
        }
        if containsAny(in: ctx, tokens: ["class", "classes", "object", "objects", "inheritance", "polymorphism", "encapsulation", "oop"]) ||
            ctx.raw.contains("object oriented") {
            return [
                "Variables and data types",
                "Functions and methods",
                "Control flow"
            ]
        }
        if containsAny(in: ctx, tokens: ["algorithm", "algorithms", "array", "arrays", "hashmap", "tree", "graph", "recursion", "complexity"]) {
            return [
                "Variables and data types",
                "Control flow",
                "Functions and methods"
            ]
        }
        if containsAny(in: ctx, tokens: ["concurrency", "thread", "threads", "mutex", "race", "deadlock", "async", "await"]) {
            return [
                "Functions and methods",
                "Mutable state basics",
                "Debugging fundamentals"
            ]
        }
        if containsAny(in: ctx, tokens: ["sql", "database", "postgres", "mysql", "query", "indexing", "join"]) {
            return [
                "Tables, rows, and keys",
                "Basic CRUD queries",
                "Filtering and sorting data"
            ]
        }
        if containsAny(in: ctx, tokens: ["api", "rest", "graphql", "http", "endpoint"]) {
            return [
                "Client/server basics",
                "JSON and data formats",
                "HTTP request/response flow"
            ]
        }
        if containsAny(in: ctx, tokens: ["test", "testing", "tdd", "integration", "unit", "mock"]) {
            return [
                "Functions and modules",
                "Expected vs actual outcomes",
                "Edge case thinking"
            ]
        }
        if containsAny(in: ctx, tokens: ["oauth", "jwt", "auth", "authentication", "authorization", "encryption", "security"]) {
            return [
                "HTTP fundamentals",
                "State and session basics",
                "Common web attack patterns"
            ]
        }
        if category == "AI/ML" {
            return [
                "Python fundamentals",
                "Linear algebra basics",
                "Probability basics"
            ]
        }
        if category == "General" {
            return [
                "Basic software workflow",
                "Reading technical docs"
            ]
        }

        switch difficulty {
        case .beginner:
            return [
                "Basic syntax",
                "Variables and data types"
            ]
        case .intermediate:
            return [
                "Variables and control flow",
                "Functions and modules"
            ]
        case .advanced:
            return [
                "Core language fundamentals",
                "Data structures",
                "Debugging basics"
            ]
        case .expert:
            return [
                "Advanced language features",
                "Systems fundamentals",
                "Performance analysis"
            ]
        }
    }

    private static func normalizedCategory(existing: String, fallback: String) -> String {
        let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if isPlaceholderCategory(trimmed) {
            return fallback
        }
        return trimmed
    }

    private static func normalizedSubcategory(existing: String?, category: String, fallback: String) -> String {
        guard let existing else { return fallback }
        let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare("general") == .orderedSame || trimmed.caseInsensitiveCompare(category) == .orderedSame {
            return fallback
        }
        return trimmed
    }

    private static func isPlaceholderCategory(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.caseInsensitiveCompare("general") == .orderedSame
    }

    private static func containsAny(in ctx: MatchContext, tokens: [String]) -> Bool {
        for token in tokens {
            if ctx.tokens.contains(token) { return true }
        }
        return false
    }

    private static func containsAny(in ctx: MatchContext, phrases: [String]) -> Bool {
        for phrase in phrases {
            if ctx.raw.contains(phrase) { return true }
        }
        return false
    }
}

extension Concept {
    var categoryPathLabel: String {
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryValue = cleanCategory.isEmpty ? "General" : cleanCategory

        let cleanSubcategory = subcategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subcategoryValue: String
        if let cleanSubcategory, !cleanSubcategory.isEmpty {
            subcategoryValue = cleanSubcategory
        } else {
            subcategoryValue = categoryValue.caseInsensitiveCompare("General") == .orderedSame
                ? "Best Practices"
                : "Fundamentals"
        }

        if subcategoryValue.caseInsensitiveCompare(categoryValue) == .orderedSame {
            return categoryValue
        }
        return "\(categoryValue) -> \(subcategoryValue)"
    }

    var effectivePrerequisites: [String] {
        if prerequisites.isEmpty {
            return ConceptClassifier.profile(for: name).prerequisites
        }
        return prerequisites
    }
}

// MARK: - Agent Reasoning
struct ReasoningStep: Identifiable, Codable {
    let id: UUID
    let stepNumber: Int
    let action: String
    let reasoning: String
    let output: String
    let timestamp: Date
    
    init(id: UUID = UUID(), stepNumber: Int, action: String, reasoning: String, output: String, timestamp: Date = Date()) {
        self.id = id
        self.stepNumber = stepNumber
        self.action = action
        self.reasoning = reasoning
        self.output = output
        self.timestamp = timestamp
    }
}

// MARK: - Recall & Quizzes
struct RecallTask: Identifiable, Codable {
    let id: UUID
    let conceptId: UUID
    let type: RecallType
    let question: String
    let options: [String]?
    let correctAnswer: String
    let scheduledDate: Date
    var completed: Bool
    var userAnswer: String?
    var wasCorrect: Bool?
    var emotionalResponse: EmotionalResponse?
    
    init(id: UUID = UUID(), conceptId: UUID, type: RecallType, question: String, options: [String]? = nil, correctAnswer: String, scheduledDate: Date, completed: Bool = false, userAnswer: String? = nil, wasCorrect: Bool? = nil, emotionalResponse: EmotionalResponse? = nil) {
        self.id = id
        self.conceptId = conceptId
        self.type = type
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        self.scheduledDate = scheduledDate
        self.completed = completed
        self.userAnswer = userAnswer
        self.wasCorrect = wasCorrect
        self.emotionalResponse = emotionalResponse
    }
}

enum RecallType: String, Codable {
    case multipleChoice = "Multiple Choice"
    case openEnded = "Explain in Your Words"
    case codeComprehension = "Code Comprehension"
}

struct EmotionalResponse: Codable {
    let energyLevel: Int // 1-5
    let challengeLevel: Int // 1-5
    let comment: String?
}

// MARK: - Learning Goals
struct LearningGoal: Identifiable, Codable {
    let id: UUID
    let title: String
    let targetDate: Date
    var progress: Double
    var relatedConcepts: [UUID]
    var calendarEventIdentifier: String?
    
    init(id: UUID = UUID(), title: String, targetDate: Date, progress: Double = 0.0, relatedConcepts: [UUID] = [], calendarEventIdentifier: String? = nil) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.progress = progress
        self.relatedConcepts = relatedConcepts
        self.calendarEventIdentifier = calendarEventIdentifier
    }
}

// MARK: - Performance Reports
struct PerformanceReport: Identifiable, Codable {
    let id: UUID
    let period: ReportPeriod
    let startDate: Date
    let endDate: Date
    let conceptsLearned: [Concept]
    let conceptsRetained: [Concept]
    let conceptsFaded: [Concept]
    let totalRecallAttempts: Int
    let successRate: Double
    let insights: [String]
    let emotionalTrends: EmotionalTrends
    
    init(id: UUID = UUID(), period: ReportPeriod, startDate: Date, endDate: Date, conceptsLearned: [Concept], conceptsRetained: [Concept], conceptsFaded: [Concept], totalRecallAttempts: Int, successRate: Double, insights: [String], emotionalTrends: EmotionalTrends) {
        self.id = id
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.conceptsLearned = conceptsLearned
        self.conceptsRetained = conceptsRetained
        self.conceptsFaded = conceptsFaded
        self.totalRecallAttempts = totalRecallAttempts
        self.successRate = successRate
        self.insights = insights
        self.emotionalTrends = emotionalTrends
    }
}

enum ReportPeriod: String, Codable {
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct EmotionalTrends: Codable {
    let averageEnergy: Double
    let averageChallenge: Double
    let mostEngagingTopics: [String]
    let mostChallengingTopics: [String]
}
