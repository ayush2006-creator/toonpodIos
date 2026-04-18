import SwiftUI

struct GridRevealOverlay: View {
    @EnvironmentObject var partyVM: PartyViewModel
    let onDismiss: () -> Void

    var state: GridRevealState? { partyVM.gridRevealState }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text("🎁 MYSTERY GRID")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)

                    if let s = state {
                        Text("\(s.player), pick a card!")
                            .font(.title3)
                            .foregroundColor(partyVM.color(for: s.player))

                        // Grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(s.cells.enumerated()), id: \.element.id) { idx, cell in
                                let isSelected = s.selectedIdx == idx
                                let isRevealed = s.revealedIdxs.contains(idx)

                                GridCardView(
                                    number: idx + 1,
                                    cell: isRevealed ? cell : nil,
                                    isSelected: isSelected,
                                    color: partyVM.color(for: s.player)
                                ) {
                                    guard s.phase == .pick, s.selectedIdx == nil else { return }
                                    pickCard(idx: idx)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Phase-specific content
                        switch s.phase {
                        case .pick:
                            Text("Say the number or tap a card")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        case .revealSelected, .cascade:
                            ProgressView().tint(.purple)
                        case .playerSelect:
                            playerSelectView(s: s)
                        case .result:
                            resultView(s: s)
                        }
                    }
                }
                .padding(.vertical, 32)
            }
            .background(Color(hex: "1a0533").opacity(0.97))
            .cornerRadius(24)
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func playerSelectView(s: GridRevealState) -> some View {
        VStack(spacing: 14) {
            let verb = s.result?.kind == .steal ? "steal from" :
                       s.result?.kind == .donate ? "donate to" : "skip"
            Text("Who do you want to \(verb)?")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(partyVM.players.filter { $0.name != s.player }, id: \.name) { player in
                    Button {
                        applyPlayerEffect(s: s, target: player.name)
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
    private func resultView(s: GridRevealState) -> some View {
        if let result = s.result {
            VStack(spacing: 12) {
                Text(cellResultTitle(result))
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(cellResultColor(result))
                    .multilineTextAlignment(.center)
                Text(cellResultDescription(result, s: s))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    partyVM.gridRevealState = nil
                    onDismiss()
                } label: {
                    Text("Continue")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.purple)
                        .cornerRadius(14)
                        .padding(.horizontal, 32)
                }
            }
        }
    }

    // MARK: - Actions

    private func pickCard(idx: Int) {
        guard var s = partyVM.gridRevealState else { return }
        s.selectedIdx = idx
        s.phase = .revealSelected
        s.revealedIdxs.insert(idx)
        partyVM.gridRevealState = s

        // Cascade remaining after 0.9s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            cascadeReveal(idx: idx)
        }
    }

    private func cascadeReveal(selected: Int) {
        guard var s = partyVM.gridRevealState else { return }
        s.phase = .cascade
        partyVM.gridRevealState = s

        let unrevealedIndices = s.cells.indices.filter { $0 != selected && !s.revealedIdxs.contains($0) }
        for (i, cellIdx) in unrevealedIndices.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                partyVM.gridRevealState?.revealedIdxs.insert(cellIdx)
            }
        }

        let totalDelay = Double(unrevealedIndices.count) * 0.12 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            resolveSelectedCell(idx: selected)
        }
    }

    private func cascadeReveal(idx: Int) {
        cascadeReveal(selected: idx)
    }

    private func resolveSelectedCell(idx: Int) {
        guard var s = partyVM.gridRevealState else { return }
        let cell = s.cells[idx]
        s.result = cell

        switch cell.kind {
        case .money:
            partyVM.addScore(s.player, cell.amount ?? 0)
            s.phase = .result
        case .multiplier:
            partyVM.scoreMultiplier = PartyScoreMultiplier(
                questionsLeft: cell.questions ?? 1,
                factor: cell.factor ?? 2.0
            )
            s.phase = .result
        case .extraLife:
            partyVM.partyExtraLives[s.player, default: 0] += 1
            s.phase = .result
        case .bomb:
            partyVM.deductScore(s.player, cell.amount ?? 0)
            s.phase = .result
        case .steal, .skipTurn, .donate, .loseLifeline:
            s.phase = .playerSelect
        case .question:
            // Bonus question — dismiss grid, PartyGameScreen handles it
            s.phase = .result
        }

        partyVM.gridRevealState = s
    }

    private func applyPlayerEffect(s: GridRevealState, target: String) {
        guard let result = s.result else { return }
        switch result.kind {
        case .steal:
            let amount = Int(Double(partyVM.partyScores[target] ?? 0) * 0.15)
            partyVM.transferScore(from: target, to: s.player, amount: amount)
        case .donate:
            let amount = Int(Double(partyVM.partyScores[s.player] ?? 0) * 0.10)
            partyVM.transferScore(from: s.player, to: target, amount: amount)
        case .skipTurn:
            partyVM.partySkipNextTurn[target] = true
        case .loseLifeline:
            if partyVM.partyLifelines[target]?.fiftyFifty == true {
                partyVM.partyLifelines[target]?.fiftyFifty = false
            } else if partyVM.partyLifelines[target]?.hint == true {
                partyVM.partyLifelines[target]?.hint = false
            }
        default: break
        }
        partyVM.gridRevealState?.targetPlayer = target
        partyVM.gridRevealState?.phase = .result
    }

    // MARK: - Helpers

    private func cellResultTitle(_ cell: GridCell) -> String {
        switch cell.kind {
        case .money:      return "+\(formatMoney(cell.amount ?? 0)) 💰"
        case .multiplier: return "\(Int(cell.factor ?? 2))x Multiplier! ⚡"
        case .extraLife:  return "Extra Life! 💚"
        case .question:   return "Bonus Question! 🎯"
        case .steal:      return "Steal! 🕵️"
        case .skipTurn:   return "Skip Turn! ⏭️"
        case .loseLifeline: return "Lose a Lifeline! ❌"
        case .bomb:       return "-\(formatMoney(cell.amount ?? 0)) 💣"
        case .donate:     return "Donate! 🎁"
        }
    }

    private func cellResultColor(_ cell: GridCell) -> Color {
        switch cell.kind {
        case .money, .multiplier, .extraLife, .question: return .green
        case .bomb, .loseLifeline: return .red
        default: return .yellow
        }
    }

    private func cellResultDescription(_ cell: GridCell, s: GridRevealState) -> String {
        switch cell.kind {
        case .money:      return "Added to \(s.player)'s score"
        case .multiplier: return "Next \(cell.questions ?? 1) question(s) score \(Int(cell.factor ?? 2))x"
        case .extraLife:  return "\(s.player) can survive one wrong answer"
        case .question:   return "A bonus question is coming!"
        case .steal:      return "Stole from \(s.targetPlayer ?? "")"
        case .skipTurn:   return "\(s.targetPlayer ?? "") skips next turn"
        case .loseLifeline: return "\(s.targetPlayer ?? "") lost a lifeline"
        case .bomb:       return "Deducted from \(s.player)'s score"
        case .donate:     return "\(s.player) donated to \(s.targetPlayer ?? "")"
        }
    }

    private func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000 { return "$\(amount / 1_000)k" }
        return "$\(amount)"
    }
}

// MARK: - Grid Card

private struct GridCardView: View {
    let number: Int
    let cell: GridCell?
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let cell {
                    // Revealed back
                    VStack(spacing: 4) {
                        Text(cellIcon(cell))
                            .font(.system(size: 24))
                        Text(cellLabel(cell))
                            .font(.system(size: 9, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(cellColor(cell).opacity(0.3))
                    .cornerRadius(10)
                } else {
                    // Face-down
                    Text("\(number)")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(isSelected ? .black : .white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isSelected ? color : Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.white.opacity(0.15), lineWidth: 1.5)
            )
        }
    }

    private func cellIcon(_ cell: GridCell) -> String {
        switch cell.kind {
        case .money:       return "💰"
        case .multiplier:  return "⚡"
        case .extraLife:   return "💚"
        case .question:    return "🎯"
        case .steal:       return "🕵️"
        case .skipTurn:    return "⏭️"
        case .loseLifeline: return "❌"
        case .bomb:        return "💣"
        case .donate:      return "🎁"
        }
    }

    private func cellLabel(_ cell: GridCell) -> String {
        switch cell.kind {
        case .money:       return formatMoney(cell.amount ?? 0)
        case .multiplier:  return "\(Int(cell.factor ?? 2))x × \(cell.questions ?? 1)Q"
        case .extraLife:   return "Extra Life"
        case .question:    return "Bonus Q"
        case .steal:       return "Steal 15%"
        case .skipTurn:    return "Skip Turn"
        case .loseLifeline: return "Lose Lifeline"
        case .bomb:        return "-\(formatMoney(cell.amount ?? 0))"
        case .donate:      return "Donate 10%"
        }
    }

    private func cellColor(_ cell: GridCell) -> Color {
        switch cell.kind {
        case .money, .multiplier, .extraLife, .question: return .green
        case .bomb, .loseLifeline: return .red
        default: return .yellow
        }
    }

    private func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000 { return "$\(amount / 1_000)k" }
        return "$\(amount)"
    }
}
