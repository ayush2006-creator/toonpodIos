import SwiftUI

struct WagerOverlay: View {
    @EnvironmentObject var partyVM: PartyViewModel
    let onAllWagersIn: () -> Void

    var sortedWagers: [(name: String, amount: Int)] {
        partyVM.wagerAmounts
            .map { (name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    var allPlacedWagers: Bool {
        partyVM.players.allSatisfy { partyVM.wagerAmounts[$0.name] != nil }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                HStack {
                    Text("🎲")
                        .font(.system(size: 32))
                    Text("WAGER ROUND")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                }

                Text("Buzz in and say your wager amount!")
                    .font(.subheadline)
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)

                // Wager cards
                if sortedWagers.isEmpty {
                    Text("Waiting for wagers...")
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 10) {
                        ForEach(sortedWagers, id: \.name) { entry in
                            HStack {
                                Text(entry.name)
                                    .fontWeight(.bold)
                                Spacer()
                                Text(formatMoney(entry.amount))
                                    .fontWeight(.bold)
                                    .foregroundColor(.yellow)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(partyVM.color(for: entry.name).opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Progress
                Text("\(sortedWagers.count) / \(partyVM.players.count) wagered")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))

                // Continue when all wagered
                if allPlacedWagers {
                    Button {
                        onAllWagersIn()
                    } label: {
                        Text("Ask the Question")
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
            .padding(.vertical, 40)
            .background(Color(hex: "1a0533").opacity(0.97))
            .cornerRadius(24)
            .padding(.horizontal, 16)
        }
    }

    private func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000 { return "$\(amount / 1_000)k" }
        return "$\(amount)"
    }
}
