import SwiftUI

struct PartyScoreboardView: View {
    @EnvironmentObject var partyVM: PartyViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(partyVM.players, id: \.name) { player in
                    let score = partyVM.partyScores[player.name] ?? 0
                    let isActive = partyVM.partySpeaker == player.name

                    VStack(spacing: 2) {
                        Text(player.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(isActive ? .black : .white.opacity(0.8))
                            .lineLimit(1)
                        Text(formatMoney(score))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(isActive ? .black : partyVM.color(for: player.name))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isActive
                            ? partyVM.color(for: player.name)
                            : partyVM.color(for: player.name).opacity(0.15)
                    )
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(partyVM.color(for: player.name), lineWidth: isActive ? 0 : 1)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color.black.opacity(0.3))
    }

    private func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000_000 { return String(format: "$%.1fM", Double(amount) / 1_000_000) }
        if amount >= 1_000     { return String(format: "$%dk", amount / 1_000) }
        return "$\(amount)"
    }
}
