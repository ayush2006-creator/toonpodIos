import Foundation
import SwiftUI

// MARK: - Party Score Multiplier

/// Active score multiplier for the next N questions (awarded by Grid Reveal).
struct PartyScoreMultiplier {
    var questionsLeft: Int
    var factor: Double
}

@MainActor
class GameViewModel: ObservableObject {
    // MARK: - Published State

    @Published var currentQ: Int = 0
    @Published var totalWinnings: Int = 0
    @Published var baseScore: Int = 0
    @Published var bonusPool: Int = 0
    @Published var streak: Int = 0
    @Published var maxStreak: Int = 0
    @Published var results: [GameResult] = []
    @Published var lifelines = Lifelines()
    @Published var gameData: [Question] = []
    @Published var questionSetId: String?

    @Published var currentLevel: Int = 1
    @Published var selectedCategory: String = "general"
    @Published var partyMode: Bool = false
    @Published var selectedAvatarId: String = "trixie"

    // Party mode scoring
    /// Active score multiplier from a Grid Reveal cell (nil = no active multiplier).
    @Published var partyScoreMultiplier: PartyScoreMultiplier?
    /// A bonus question displayed during a special round (e.g. Grid Reveal 'question' cell).
    @Published var specialRoundQuestion: Question?
    /// Active daily login streak score multiplier (1.0 = no bonus).
    @Published var loginStreakMultiplier: Double = 1.0

    @Published var showQuestion: Bool = true
    @Published var showFeedback: Bool = false
    @Published var feedbackData: FeedbackData?
    @Published var answerRevealed: Bool = false
    /// The answer text selected by voice input — used to highlight the matching button.
    @Published var voiceSelectedAnswer: String?
    @Published var hintVisible: Bool = false
    @Published var hintText: String = ""
    @Published var fiftyEliminated: [Int] = []
    @Published var lifelineUsedThisQ: Bool = false

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var gameAborted: Bool = false
    @Published var gameComplete: Bool = false

    // Lightning round state
    @Published var lightningIdx: Int = 0
    @Published var lightningCorrect: Int = 0
    @Published var lightningResults: [Bool] = []

    // Chain order state
    @Published var chainOrder: [String] = []

    // Wipeout state
    @Published var wipeoutSelected: Set<String> = []

    // Timer
    @Published var questionStartTime: Date?
    @Published var frozenElapsed: Double?
    @Published var elapsedTime: Double = 0

    private var timer: Timer?

    // MARK: - Computed Properties

    var currentQuestion: Question? {
        guard currentQ < gameData.count else { return nil }
        return gameData[currentQ]
    }

    var totalQuestions: Int { gameData.count }

    var currentPrize: Int {
        guard currentQ < AppConstants.prizeLadder.count else { return 0 }
        return AppConstants.prizeLadder[currentQ]
    }

    var isLastQuestion: Bool {
        currentQ >= gameData.count - 1
    }

    var correctCount: Int {
        results.filter(\.correct).count
    }

    var wrongCount: Int {
        results.filter { !$0.correct }.count
    }

    // MARK: - Game Lifecycle

    func resetGame(level: Int) {
        currentQ = 0
        totalWinnings = 0
        baseScore = 0
        bonusPool = 0
        streak = 0
        maxStreak = 0
        results = []
        lifelines = Lifelines()
        gameData = []
        questionSetId = nil
        currentLevel = level
        showQuestion = true
        showFeedback = false
        feedbackData = nil
        answerRevealed = false
        hintVisible = false
        hintText = ""
        fiftyEliminated = []
        lifelineUsedThisQ = false
        isLoading = false
        errorMessage = nil
        gameAborted = false
        gameComplete = false
        lightningIdx = 0
        lightningCorrect = 0
        lightningResults = []
        chainOrder = []
        wipeoutSelected = []
        frozenElapsed = nil
        elapsedTime = 0
        partyScoreMultiplier = nil
        specialRoundQuestion = nil
        _ = stopTimer()
    }

    func loadQuestions() async {
        isLoading = true
        errorMessage = nil

        print("[GameVM] Loading questions: level=\(currentLevel), category=\(selectedCategory)")

        do {
            let playedIds = StorageService.shared.getPlayedSetIds(level: currentLevel, category: selectedCategory)
            let excludeSets = playedIds.completed + playedIds.partial
            let response = try await APIService.shared.fetchQuestions(
                level: currentLevel,
                category: selectedCategory,
                excludeSets: excludeSets
            )

            print("[GameVM] Loaded \(response.questions.count) questions, setId=\(response.setId ?? "nil")")

            gameData = response.questions
            questionSetId = response.setId
            isLoading = false

            if gameData.isEmpty {
                errorMessage = "No questions returned from server"
                print("[GameVM] ERROR: Empty questions array")
                return
            }

            // Start the timer for the first question
            startTimer()

            StorageService.shared.recordGameStarted(
                level: currentLevel,
                category: selectedCategory,
                setId: questionSetId
            )
        } catch {
            print("[GameVM] ERROR loading questions: \(error)")
            if let decodingError = error as? DecodingError {
                print("[GameVM] Decoding detail: \(decodingError)")
            }
            errorMessage = "Failed to load questions: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Timer

    func startTimer() {
        questionStartTime = Date()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.questionStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    func stopTimer() -> Double {
        timer?.invalidate()
        timer = nil
        guard let start = questionStartTime else { return 999 }
        let elapsed = Date().timeIntervalSince(start)
        questionStartTime = nil
        return elapsed
    }

    func freezeTimer() {
        guard let start = questionStartTime else { return }
        frozenElapsed = Date().timeIntervalSince(start)
        timer?.invalidate()
        timer = nil
        questionStartTime = nil
    }

    // MARK: - Answer Processing

    func finishQuestion(isCorrect: Bool, fact: String, options: FinishQuestionOptions = FinishQuestionOptions()) -> FinishQuestionResult {
        let elapsed = options.skipTimer ? 999 : (frozenElapsed ?? (questionStartTime.map { Date().timeIntervalSince($0) } ?? 999))
        let qIdx = currentQ
        let ladderPrize = qIdx < AppConstants.prizeLadder.count ? AppConstants.prizeLadder[qIdx] : 0

        var prizeWon = 0
        var speedBon = 0
        var streakBon = 0
        var loginStreakBon = 0

        if isCorrect {
            if let override = options.overridePrize {
                prizeWon = override
            } else {
                prizeWon = Int(round(Double(ladderPrize) * (options.prizeMultiplier ?? 1.0)))
            }
            baseScore += prizeWon
            streak += 1
            maxStreak = max(maxStreak, streak)
            if !options.skipTimer {
                speedBon = ScoringService.calcSpeedBonus(prize: prizeWon, elapsed: elapsed)
            }
            streakBon = ScoringService.calcStreakBonus(prize: prizeWon, streak: streak)
            loginStreakBon = ScoringService.calcLoginStreakBonus(prize: prizeWon, multiplier: loginStreakMultiplier)
            bonusPool += speedBon + streakBon + loginStreakBon
        } else {
            streak = 0
        }

        let totalPrize = prizeWon + speedBon + streakBon + loginStreakBon
        totalWinnings = baseScore + bonusPool

        // In party mode, apply the active score multiplier to the winning scorer's prize
        // (mirrors web's `effectivePrize = mul ? totalPrize * mul.factor : totalPrize`).
        // Note: full party score tracking (partyScores dict) is handled by the party
        // orchestrator; this just decrements the multiplier lifetime counter.
        if partyMode, let mul = partyScoreMultiplier, isCorrect {
            let left = mul.questionsLeft - 1
            partyScoreMultiplier = left > 0 ? PartyScoreMultiplier(questionsLeft: left, factor: mul.factor) : nil
        }

        let result = GameResult(
            correct: isCorrect,
            totalPrize: totalPrize,
            basePrize: prizeWon,
            speedBonus: speedBon,
            streakBonus: streakBon,
            loginStreakBonus: loginStreakBon,
            timeTaken: elapsed,
            type: gameData[qIdx].type,
            position: gameData[qIdx].position,
            ladderPrize: ladderPrize,
            scoredBy: nil
        )
        results.append(result)

        timer?.invalidate()
        timer = nil
        questionStartTime = nil

        return FinishQuestionResult(
            isCorrect: isCorrect,
            totalPrize: totalPrize,
            speedBonus: speedBon,
            streakBonus: streakBon,
            loginStreakBonus: loginStreakBon,
            fact: fact,
            elapsed: elapsed
        )
    }

    // MARK: - Question Flow

    func showQuestionUI() {
        showQuestion = true
        showFeedback = false
        hintVisible = false
        hintText = ""
        answerRevealed = false
        voiceSelectedAnswer = nil
    }

    func showFeedbackUI(data: FeedbackData) {
        showQuestion = false
        showFeedback = true
        feedbackData = data
    }

    func advanceQuestion() {
        currentQ += 1
        fiftyEliminated = []
        lifelineUsedThisQ = false
        frozenElapsed = nil
        chainOrder = []
        wipeoutSelected = []
        lightningIdx = 0
        lightningCorrect = 0
        lightningResults = []
        answerRevealed = false
        voiceSelectedAnswer = nil
    }

    func revealAnswer() {
        answerRevealed = true
    }

    // MARK: - Lifelines

    func useLifeline(_ key: String) {
        lifelineUsedThisQ = true
        switch key {
        case "fiftyFifty":
            lifelines.fiftyFifty = false
            applyFiftyFifty()
        case "hint":
            lifelines.hint = false
            applyHint()
        case "swap":
            lifelines.swap = false
        default:
            break
        }
    }

    private func applyFiftyFifty() {
        guard let q = currentQuestion else { return }

        var opts: [String] = []
        var correct = ""

        if q.type == .fourOptions {
            opts = [q.data.optionA ?? "", q.data.optionB ?? "", q.data.optionC ?? "", q.data.optionD ?? ""]
            correct = q.data.correctOption ?? ""
        } else if q.type == .oddOneOut {
            opts = [q.data.option1 ?? "", q.data.option2 ?? "", q.data.option3 ?? "", q.data.option4 ?? ""]
            correct = q.data.correctAnswer ?? ""
        }

        guard opts.count == 4, !correct.isEmpty else { return }

        var wrongIndices = opts.enumerated().compactMap { $0.element != correct ? $0.offset : nil }
        wrongIndices.shuffle()
        fiftyEliminated = Array(wrongIndices.prefix(2))
    }

    private func applyHint() {
        guard let q = currentQuestion else { return }
        let hint = q.data.hint ?? q.hints?.first ?? q.data.interestingFact ?? q.interestingFact ?? ""
        if !hint.isEmpty {
            hintVisible = true
            hintText = hint
        } else {
            hintVisible = true
            hintText = "No hint available."
        }
    }

    func replaceCurrentQuestion(_ question: Question) {
        guard currentQ < gameData.count else { return }
        gameData[currentQ] = question
    }

    // MARK: - Party Score Multiplier Helpers

    func setPartyScoreMultiplier(_ multiplier: PartyScoreMultiplier?) {
        partyScoreMultiplier = multiplier
    }

    func decrementMultiplier() {
        guard let mul = partyScoreMultiplier else { return }
        let left = mul.questionsLeft - 1
        partyScoreMultiplier = left > 0 ? PartyScoreMultiplier(questionsLeft: left, factor: mul.factor) : nil
    }

    func setSpecialRoundQuestion(_ question: Question?) {
        specialRoundQuestion = question
    }

    // MARK: - Game Completion

    func completeGame() {
        gameComplete = true
        StorageService.shared.recordGamePlayed(
            level: currentLevel,
            category: selectedCategory,
            winnings: totalWinnings,
            setId: questionSetId
        )
    }
}
