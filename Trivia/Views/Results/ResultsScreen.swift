import SwiftUI

struct ResultsScreen: View {
    @EnvironmentObject var gameVM: GameViewModel
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var didSaveScore = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a0533"), Color(hex: "0d001a")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(headerEmoji)
                            .font(.system(size: 64))

                        Text(Dialogue.gameComplete(wrongCount: gameVM.wrongCount))
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 24)

                    // Total winnings
                    VStack(spacing: 4) {
                        Text("Total Winnings")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                        Text(formatMoney(gameVM.totalWinnings))
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                            )
                    }

                    // Stats grid - 2 rows
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatBox(label: "Correct", value: "\(gameVM.correctCount)/\(gameVM.totalQuestions)", color: .green)
                            StatBox(label: "Max Streak", value: "\(gameVM.maxStreak)", color: .orange)
                            StatBox(label: "Accuracy", value: "\(accuracy)%", color: .purple)
                        }

                        HStack(spacing: 12) {
                            StatBox(label: "Fastest", value: fastestTime, color: .cyan)
                            StatBox(label: "Avg Time", value: avgTime, color: .blue)
                            StatBox(label: "Wrong", value: "\(gameVM.wrongCount)", color: .red)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Sparks consumed
                    if gameVM.totalQuestions > 0 {
                        HStack(spacing: 6) {
                            Text("\u{26A1}")
                            Text("-\(sparksConsumed) sparks used")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Results ladder
                    ResultsLadder(results: gameVM.results)

                    // Share buttons
                    ShareButtonsRow(
                        winnings: gameVM.totalWinnings,
                        correct: gameVM.correctCount,
                        total: gameVM.totalQuestions,
                        maxStreak: gameVM.maxStreak
                    )

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            gameVM.resetGame(level: gameVM.currentLevel)
                            Task { await gameVM.loadQuestions() }
                        } label: {
                            Text("Play Again")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Back to Levels")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            guard !didSaveScore else { return }
            didSaveScore = true

            let mode: String
            if gameVM.communityGameId != nil { mode = "community" }
            else if gameVM.partyMode          { mode = "party" }
            else                              { mode = "solo" }

            let data = ScoreData(
                level: gameVM.currentLevel,
                winnings: gameVM.totalWinnings,
                correct: gameVM.correctCount,
                totalQs: gameVM.totalQuestions,
                maxStreak: gameVM.maxStreak,
                gameMode: mode
            )
            await auth.saveScore(
                data: data,
                questionSetId: gameVM.questionSetId,
                category: gameVM.selectedCategory
            )
            if let cid = gameVM.communityGameId {
                await auth.recordCommunityPlay(
                    gameId: cid,
                    winnings: gameVM.totalWinnings,
                    correct: gameVM.correctCount
                )
            }
        }
    }

    // MARK: - Computed

    private var headerEmoji: String {
        if gameVM.wrongCount == 0 { return "\u{1F3C6}" }
        if gameVM.wrongCount <= 3 { return "\u{1F389}" }
        return "\u{1F44F}"
    }

    private var accuracy: Int {
        guard gameVM.totalQuestions > 0 else { return 0 }
        return Int(round(Double(gameVM.correctCount) / Double(gameVM.totalQuestions) * 100))
    }

    private var fastestTime: String {
        let times = gameVM.results.map(\.timeTaken).filter { $0 < 900 }
        guard let fastest = times.min() else { return "--" }
        return String(format: "%.1fs", fastest)
    }

    private var avgTime: String {
        let times = gameVM.results.map(\.timeTaken).filter { $0 < 900 }
        guard !times.isEmpty else { return "--" }
        let avg = times.reduce(0, +) / Double(times.count)
        return String(format: "%.1fs", avg)
    }

    private var sparksConsumed: Int {
        guard gameVM.totalQuestions > 0 else { return 0 }
        return Int(round(Double(gameVM.results.count) / Double(gameVM.totalQuestions) * Double(AppConstants.sparksPerGame)))
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Results Ladder

struct ResultsLadder: View {
    let results: [GameResult]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                HStack(spacing: 12) {
                    // Question number
                    Text("Q\(index + 1)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 30)

                    // Type badge
                    Text(typeLabel(result.type))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 80, alignment: .leading)

                    Spacer()

                    // Time taken
                    if result.timeTaken < 900 {
                        Text(String(format: "%.1fs", result.timeTaken))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Prize
                    if result.correct {
                        Text("+\(formatMoney(result.totalPrize))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    // Result icon
                    Image(systemName: result.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(result.correct ? .green : .red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(
                    result.correct ? Color.green.opacity(0.05) : Color.red.opacity(0.05)
                )
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Share Buttons

struct ShareButtonsRow: View {
    let winnings: Int
    let correct: Int
    let total: Int
    let maxStreak: Int

    private var shareText: String {
        "I won \(formatMoney(winnings)) on toonTRIVIA! \(correct)/\(total) correct with a \(maxStreak) streak \u{1F525}"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Share button
            ShareLink(item: shareText) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }

            // Copy button
            Button {
                UIPasteboard.general.string = shareText
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
}
