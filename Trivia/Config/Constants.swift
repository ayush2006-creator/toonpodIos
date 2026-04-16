import Foundation

enum AppConstants {
    static let appVersion = "v301"
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

    static let adBreakQuestions: [Int] = [4, 9]
    static let postQuestionAdBreaks: [Int] = [13]
    static let binaryQuestionTypes: [QuestionType] = [.whichIs, .beforeAfterBinary]

    // MARK: - Party Mode

    /// Prize ladder for party mode (flat amounts per question position).
    /// Single-player mode uses prizeLadder instead.
    static let partyPrizeLadder: [Int] = [
        100_000, 100_000, 100_000,  // Q1–3: Fast Start
        150_000,                    // Q4: Hot Seat Showdown
        100_000, 150_000,           // Q5–6: Auction
        100_000,                    // Q7: Wipeout
        100_000,                    // Q8: Risk Wager
        100_000,                    // Q9: Pressure Point
        150_000,                    // Q10: Power Grid
        100_000, 150_000,           // Q11–12: Power Play
        150_000, 150_000,           // Q13–14: Final Buildup
        250_000,                    // Q15: Survival — per-elimination award
    ]

    /// Question indices (0-based) where closest_number winner triggers the hot seat round.
    static let hotSeatAfterClosest: [Int] = [3] // Q4 (index 3)

    /// Correct-answer streak required to be eligible for the steal round.
    static let stealStreakThreshold = 3
    /// Reduced threshold when 4+ players are in the game.
    static let stealStreakThresholdLarge = 2

    /// Special round types keyed by 0-indexed question position.
    static let partySpecialRounds: [Int: String] = [
        5: "auction",  // Q6
        7: "wager",    // Q8
    ]

    /// Question indices before which the avatar offers a bribe opportunity.
    static let partyBribeBefore: [Int] = [4, 8, 12]

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
