import Foundation

enum AppConstants {
    static let appVersion = "v41"
    static let serverURL = "https://toonpod-trivia.onrender.com"

    static let prizeLadder: [Int] = [
        500, 1_000, 2_000, 5_000, 10_000,
        20_000, 30_000, 50_000, 70_000, 100_000,
        200_000, 300_000, 450_000, 700_000, 1_000_000,
    ]

    static let levelNames: [String] = [
        "Beginner", "Easy", "Casual", "Medium", "Challenging",
        "Hard", "Expert", "Master", "Champion", "Legend",
    ]

    static let gamesToUnlock = 10
    static let sparksPerGame = 100
    static let initialSparks = 5000

    static let gamesPerLevel: [String: Int] = [
        "general": 10,
        "pop_culture": 5,
        "sports": 5,
        "music": 5,
        "history": 5,
        "food_drink": 5,
    ]

    static func getGamesToUnlock(category: String) -> Int {
        let total = gamesPerLevel[category] ?? 5
        return Int(ceil(Double(total) / 2.0))
    }

    static let adBreakQuestions: [Int] = [4, 9, 13]
    static let binaryQuestionTypes: [QuestionType] = [.whichIs, .beforeAfterBinary]

    // MARK: - Daily Login Streak

    /// Sparks awarded for each streak tier on daily login (threshold, sparks)
    static let streakDailyRewards: [(Int, Int)] = [
        (30, 20), (14, 14), (7, 10), (5, 8), (3, 5), (2, 3), (1, 2),
    ]

    /// Score multiplier tiers based on active login streak (threshold, multiplier)
    static let streakMultipliers: [(Int, Double)] = [
        (30, 1.5), (14, 1.35), (7, 1.2), (5, 1.1), (3, 1.05),
    ]

    /// Milestone titles earned at streak thresholds (threshold, title)
    static let streakMilestones: [(Int, String)] = [
        (7, "Dedicated"), (14, "Committed"), (30, "Devoted"),
        (60, "Unstoppable"), (100, "Legend"), (200, "Mythic"), (365, "Immortal"),
    ]

    // MARK: - Skip Buttons

    static let enableSkipButtons = true
    static let skipButtonDelayMs = 1500
}

// MARK: - Categories

struct TriviaCategory: Identifiable {
    let id = UUID()
    let slug: String
    let name: String
    let desc: String
    let emoji: String
    let available: Bool
}

let triviaCategories: [TriviaCategory] = [
    .init(slug: "general", name: "General Trivia", desc: "A mix of everything", emoji: "🎲", available: true),
    .init(slug: "pop_culture", name: "Pop Culture", desc: "Movies, TV, celebrities", emoji: "🎬", available: true),
    .init(slug: "sports", name: "Sports", desc: "NFL, NBA, MLB & more", emoji: "🏆", available: true),
    .init(slug: "music", name: "Music", desc: "80s, 90s, 2000s hits", emoji: "🎵", available: true),
    .init(slug: "history", name: "History", desc: "US & world history", emoji: "🏛️", available: true),
    .init(slug: "food_drink", name: "Food & Drink", desc: "Cuisine, cocktails & more", emoji: "🍕", available: true),
]
