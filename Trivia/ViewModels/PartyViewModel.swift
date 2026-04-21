import Foundation
import SwiftUI

@MainActor
class PartyViewModel: ObservableObject {

    // MARK: - Player Registry

    @Published var players: [PartyPlayer] = []

    // MARK: - Per-Player State

    @Published var partyScores: [String: Int] = [:]
    @Published var partyStreaks: [String: Int] = [:]
    @Published var partyLifelines: [String: Lifelines] = [:]
    @Published var partyExtraLives: [String: Int] = [:]
    @Published var partySkipNextTurn: [String: Bool] = [:]
    @Published var partyWrongPlayers: [String] = []

    // MARK: - Turn State

    @Published var partySpeaker: String? = nil
    @Published var buzzDetected: Bool = false  // keyword heard, waiting for ID tap

    // MARK: - Round / Special State

    @Published var partyRound: PartyRound? = nil
    @Published var pendingTitleCard: PartyRound? = nil
    @Published var activeSpecialRound: SpecialRoundType? = nil

    @Published var auctionState: AuctionState? = nil
    @Published var wagerAmounts: [String: Int] = [:]
    @Published var stealState: StealState? = nil
    @Published var hotSeatState: HotSeatState? = nil
    @Published var gridRevealState: GridRevealState? = nil
    @Published var eliminationState: EliminationState? = nil

    @Published var scoreMultiplier: PartyScoreMultiplier? = nil

    // MARK: - Registration Phase

    @Published var registrationPhase: Bool = true
    @Published var registeredNames: [String] = []
    @Published var targetPlayerCount: Int = 2

    /// Face x-positions (normalized 0-1) captured during voice registration.
    /// Used by CameraHandDetector to identify who raised their hand.
    @Published var playerFacePositions: [String: CGFloat] = [:]

    func registerFacePosition(_ name: String, x: CGFloat) {
        playerFacePositions[name] = x
    }

    // MARK: - Round map (0-indexed question → new PartyRound starting at that Q)

    static let roundMap: [Int: PartyRound] = [
        0:  .preparation,
        3:  .main,
        9:  .bonus,
        12: .finale,
    ]

    // MARK: - Player Colors

    static let playerColors: [Color] = [
        .purple, .blue, .green, .orange, .red, .yellow
    ]

    func color(for name: String) -> Color {
        let idx = players.firstIndex(where: { $0.name == name }) ?? 0
        return Self.playerColors[idx % Self.playerColors.count]
    }

    // MARK: - Init / Registration

    func initPlayers(_ names: [String]) {
        players = names.enumerated().map { i, name in
            PartyPlayer(id: i, faceId: i, name: name, score: 0)
        }
        for name in names {
            partyScores[name] = 0
            partyStreaks[name] = 0
            partyLifelines[name] = Lifelines()
            partyExtraLives[name] = 0
            partySkipNextTurn[name] = false
        }
        registrationPhase = false
    }

    // MARK: - Score Manipulation

    func addScore(_ name: String, _ amount: Int) {
        partyScores[name, default: 0] += amount
    }

    func deductScore(_ name: String, _ amount: Int) {
        partyScores[name, default: 0] = max(0, (partyScores[name] ?? 0) - amount)
    }

    func transferScore(from source: String, to dest: String, amount: Int) {
        let actual = min(amount, partyScores[source] ?? 0)
        deductScore(source, actual)
        addScore(dest, actual)
    }

    /// Applies active multiplier to a prize and decrements lifetime counter.
    func applyMultiplier(to prize: Int) -> Int {
        guard var m = scoreMultiplier, m.questionsLeft > 0 else { return prize }
        let boosted = Int(Double(prize) * m.factor)
        m.questionsLeft -= 1
        scoreMultiplier = m.questionsLeft > 0 ? m : nil
        return boosted
    }

    // MARK: - Streak / Scoring After Answer

    func recordCorrect(_ name: String) {
        partyStreaks[name, default: 0] += 1
    }

    func recordWrong(_ name: String) {
        partyStreaks[name, default: 0] = 0
    }

    // MARK: - Wrong Players (Pass Mechanics)

    func addWrongPlayer(_ name: String) {
        if !partyWrongPlayers.contains(name) {
            partyWrongPlayers.append(name)
        }
    }

    func clearWrongPlayers() {
        partyWrongPlayers = []
    }

    // MARK: - Eligible Players

    /// Players who have not already answered wrong on this question and are not skipping.
    func eligiblePlayers() -> [String] {
        players.map(\.name).filter { name in
            !partyWrongPlayers.contains(name) &&
            !(partySkipNextTurn[name] ?? false)
        }
    }

    /// Consume the skip-turn flag for all players (called at start of each question).
    func clearSkipFlags() {
        for key in partySkipNextTurn.keys {
            partySkipNextTurn[key] = false
        }
    }

    // MARK: - Steal Trigger

    func checkStealTrigger() -> String? {
        let threshold = players.count >= 4
            ? AppConstants.stealStreakThresholdLarge
            : AppConstants.stealStreakThreshold
        return partyStreaks.first(where: { $0.value >= threshold })?.key
    }

    // MARK: - Lowest / Highest Scoring Player

    var lowestScoringPlayer: String? {
        players.map(\.name).min(by: { (partyScores[$0] ?? 0) < (partyScores[$1] ?? 0) })
    }

    var highestScoringPlayer: String? {
        players.map(\.name).max(by: { (partyScores[$0] ?? 0) < (partyScores[$1] ?? 0) })
    }

    // MARK: - Sorted Leaderboard

    var sortedPlayers: [(name: String, score: Int)] {
        players.map { p in (name: p.name, score: partyScores[p.name] ?? 0) }
               .sorted { $0.score > $1.score }
    }

    // MARK: - Grid Cell Builder

    func buildGridCells(ladderPrize: Int) -> [GridCell] {
        var cells: [GridCell] = [
            // Money cells
            GridCell(kind: .money, amount: ladderPrize),
            GridCell(kind: .money, amount: ladderPrize / 2),
            GridCell(kind: .money, amount: ladderPrize / 4),
            // Multiplier
            GridCell(kind: .multiplier, factor: Double.random(in: 0...1) > 0.5 ? 3.0 : 2.0,
                     questions: Int.random(in: 1...2)),
            // Bonus items
            GridCell(kind: .extraLife),
            GridCell(kind: .question),
            // Risk items
            GridCell(kind: .steal),
            GridCell(kind: .skipTurn),
            GridCell(kind: .loseLifeline),
            GridCell(kind: .bomb, amount: ladderPrize / 5),
            GridCell(kind: .donate, amount: ladderPrize / 10),
            // Extra money
            GridCell(kind: .money, amount: ladderPrize / 3),
        ]
        cells.shuffle()
        return cells
    }

    // MARK: - Round Transition

    func checkRoundTransition(questionIndex: Int) -> PartyRound? {
        guard let newRound = Self.roundMap[questionIndex],
              newRound != partyRound else { return nil }
        partyRound = newRound
        return newRound
    }

    // MARK: - Reset

    func reset() {
        players = []
        partyScores = [:]
        partyStreaks = [:]
        partyLifelines = [:]
        partyExtraLives = [:]
        partySkipNextTurn = [:]
        partyWrongPlayers = []
        partySpeaker = nil
        buzzDetected = false
        partyRound = nil
        pendingTitleCard = nil
        activeSpecialRound = nil
        auctionState = nil
        wagerAmounts = [:]
        stealState = nil
        hotSeatState = nil
        gridRevealState = nil
        eliminationState = nil
        scoreMultiplier = nil
        registrationPhase = true
        registeredNames = []
        playerFacePositions = [:]
    }
}
