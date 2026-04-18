import SwiftUI

struct HotSeatOverlay: View {
    @EnvironmentObject var partyVM: PartyViewModel
    let onDismiss: (Bool) -> Void  // passes isCorrect for grid reveal trigger

    var state: HotSeatState? { partyVM.hotSeatState }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("🔥 HOT SEAT")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.orange)

                if let s = state {
                    switch s.phase {
                    case .announce:
                        announceView(player: s.player)
                    case .sabotage:
                        sabotageView(s: s)
                    case .loading:
                        loadingView
                    case .question:
                        questionView(s: s)
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
    private func announceView(player: String) -> some View {
        VStack(spacing: 16) {
            Text(player)
                .font(.system(size: 40, weight: .black))
                .foregroundColor(partyVM.color(for: player))
            Text("is in the Hot Seat!")
                .font(.title2)
                .foregroundColor(.white)
            Text("Others: say an amount to sabotage and raise the difficulty!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Image(systemName: "mic.fill")
                .font(.system(size: 36))
                .foregroundColor(.purple)
        }
    }

    @ViewBuilder
    private func sabotageView(s: HotSeatState) -> some View {
        VStack(spacing: 16) {
            Text("Sabotage Pool")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.red)
            let total = s.sabotage.values.reduce(0, +)
            Text(formatMoney(total))
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.yellow)
            if !s.sabotage.isEmpty {
                VStack(spacing: 6) {
                    ForEach(s.sabotage.sorted(by: { $0.value > $1.value }), id: \.key) { name, amount in
                        HStack {
                            Text(name).foregroundColor(.white)
                            Spacer()
                            Text(formatMoney(amount)).foregroundColor(.red).fontWeight(.bold)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            Text("Say 'ready' when sabotage is complete")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5).tint(.orange)
            Text("Generating a tough question...")
                .foregroundColor(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private func questionView(s: HotSeatState) -> some View {
        VStack(spacing: 16) {
            Text("\(s.player), answer this!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            if let text = s.questionText {
                Text(text)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            let labels = ["A", "B", "C", "D"]
            VStack(spacing: 8) {
                ForEach(Array(s.options.enumerated()), id: \.offset) { i, opt in
                    let isAnswer = s.playerAnswer == opt
                    HStack {
                        Text(labels[i]).fontWeight(.bold).frame(width: 24)
                        Text(opt)
                        Spacer()
                    }
                    .foregroundColor(isAnswer ? .yellow : .white)
                    .padding(10)
                    .background(isAnswer ? Color.yellow.opacity(0.15) : Color.white.opacity(0.07))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)

            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundColor(.purple)
        }
    }

    @ViewBuilder
    private func resultView(s: HotSeatState) -> some View {
        let correct = s.isCorrect == true
        let pool = s.sabotage.values.reduce(0, +)
        VStack(spacing: 16) {
            Text(correct ? "✅ Correct!" : "❌ Wrong!")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(correct ? .green : .red)

            if let correctOpt = s.correctOption {
                HStack {
                    Text("Answer:")
                        .foregroundColor(.white.opacity(0.5))
                    Text(correctOpt)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }

            if pool > 0 {
                let recipient = correct ? s.player : (partyVM.lowestScoringPlayer ?? "")
                Text(correct
                     ? "\(s.player) wins the \(formatMoney(pool)) sabotage pool!"
                     : "\(recipient) receives the \(formatMoney(pool)) pool.")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Show options reveal
            let labels = ["A", "B", "C", "D"]
            VStack(spacing: 6) {
                ForEach(Array(s.options.enumerated()), id: \.offset) { i, opt in
                    let isCorrectOpt = opt == s.correctOption
                    let isPlayerAns = opt == s.playerAnswer
                    HStack {
                        Text(labels[i]).fontWeight(.bold).frame(width: 24)
                        Text(opt)
                        Spacer()
                        if isCorrectOpt { Image(systemName: "checkmark").foregroundColor(.green) }
                        if isPlayerAns && !isCorrectOpt { Image(systemName: "xmark").foregroundColor(.red) }
                    }
                    .foregroundColor(isCorrectOpt ? .green : (isPlayerAns ? .red : .white.opacity(0.6)))
                    .padding(8)
                    .background(isCorrectOpt ? Color.green.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            // Apply sabotage pool
            if pool > 0 {
                if correct {
                    partyVM.addScore(s.player, pool)
                } else if let underdog = partyVM.lowestScoringPlayer {
                    partyVM.addScore(underdog, pool)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onDismiss(correct)
            }
        }
    }

    private func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000 { return "$\(amount / 1_000)k" }
        return "$\(amount)"
    }
}
