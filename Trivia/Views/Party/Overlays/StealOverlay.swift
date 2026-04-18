import SwiftUI

struct StealOverlay: View {
    @EnvironmentObject var partyVM: PartyViewModel
    let onDismiss: () -> Void

    var state: StealState? { partyVM.stealState }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("💰 STEAL ROUND")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)

                if let s = state {
                    switch s.phase {
                    case .offer:
                        offerView(thief: s.thief)
                    case .question:
                        questionView(s: s)
                    case .target:
                        targetView(thief: s.thief)
                    case .result:
                        resultView(s: s)
                    }
                }
            }
            .padding(.vertical, 40)
            .background(Color(hex: "1a0533").opacity(0.97))
            .cornerRadius(24)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func offerView(thief: String) -> some View {
        VStack(spacing: 16) {
            Text("🔥 \(thief) is on a streak!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            Text("Say 'yes' to steal from another player or 'no' to pass.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Image(systemName: "mic.fill")
                .font(.system(size: 36))
                .foregroundColor(.purple)
        }
    }

    @ViewBuilder
    private func questionView(s: StealState) -> some View {
        VStack(spacing: 16) {
            Text("Answer this bonus question to steal!")
                .font(.subheadline)
                .foregroundColor(.yellow)
            if let q = s.question {
                Text(q.displayText)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                let opts = [q.data.optionA, q.data.optionB, q.data.optionC, q.data.optionD]
                    .compactMap { $0 }.filter { !$0.isEmpty }
                VStack(spacing: 8) {
                    ForEach(Array(opts.enumerated()), id: \.offset) { i, opt in
                        let label = ["A","B","C","D"][i]
                        let isCorrect = s.correctOption != nil && opt == s.correctOption
                        HStack {
                            Text(label)
                                .fontWeight(.bold)
                                .frame(width: 24)
                            Text(opt)
                            Spacer()
                        }
                        .foregroundColor(isCorrect ? .green : .white)
                        .padding(10)
                        .background(
                            isCorrect ? Color.green.opacity(0.2) : Color.white.opacity(0.07)
                        )
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 24)
            } else {
                ProgressView().tint(.purple)
            }
        }
    }

    @ViewBuilder
    private func targetView(thief: String) -> some View {
        VStack(spacing: 16) {
            Text("✅ Correct! Who do you steal from?")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.green)
            Text("Say a player's name.")
                .foregroundColor(.white.opacity(0.7))
            VStack(spacing: 10) {
                ForEach(partyVM.players.filter { $0.name != thief }, id: \.name) { player in
                    Button {
                        executeSteal(thief: thief, victim: player.name)
                    } label: {
                        HStack {
                            Text(player.name).fontWeight(.bold)
                            Spacer()
                            Text(formatMoney(partyVM.partyScores[player.name] ?? 0))
                                .foregroundColor(.yellow)
                        }
                        .foregroundColor(.white)
                        .padding(12)
                        .background(partyVM.color(for: player.name).opacity(0.25))
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func resultView(s: StealState) -> some View {
        let success = s.result == .success
        VStack(spacing: 16) {
            Text(success ? "💸 Steal Successful!" : "❌ Wrong Answer!")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(success ? .green : .red)
            if success, let victim = s.victim {
                Text("\(s.thief) stole \(formatMoney(s.amount)) from \(victim)!")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            } else {
                let underdog = partyVM.lowestScoringPlayer ?? ""
                Text("\(s.thief) lost \(formatMoney(s.amount)) to \(underdog).")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            // Show correct answer if available
            if let correct = s.correctOption {
                HStack {
                    Text("Answer:")
                        .foregroundColor(.white.opacity(0.5))
                    Text(correct)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { onDismiss() }
        }
    }

    private func executeSteal(thief: String, victim: String) {
        let victimScore = partyVM.partyScores[victim] ?? 0
        let amount = victimScore / 2
        partyVM.stealState?.victim = victim
        partyVM.stealState?.amount = amount
        partyVM.stealState?.result = .success
        partyVM.transferScore(from: victim, to: thief, amount: amount)
        partyVM.stealState?.phase = .result
    }

    private func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000 { return "$\(amount / 1_000)k" }
        return "$\(amount)"
    }
}
