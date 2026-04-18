import SwiftUI

struct EliminationView: View {
    @EnvironmentObject var partyVM: PartyViewModel

    private static let categoryPrompts = [
        "Name a country in Europe",
        "Name an animal that starts with B",
        "Name a famous scientist",
        "Name a US state",
        "Name a sport played with a ball",
        "Name a type of fruit",
        "Name a car brand",
        "Name a planet in our solar system",
        "Name a musical instrument",
        "Name a US President",
    ]

    var state: EliminationState? { partyVM.eliminationState }

    var body: some View {
        ZStack {
            Color(hex: "0d001a").ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                Text("MILLION DOLLAR SURVIVAL")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)

                // Player status grid
                if let s = state {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3),
                              spacing: 10) {
                        ForEach(partyVM.players, id: \.name) { player in
                            let isActive = s.activePlayers.contains(player.name)
                            let isEliminated = s.justEliminated == player.name
                            VStack(spacing: 4) {
                                Text(isActive ? "✓" : "✗")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(isActive ? .green : .red)
                                Text(player.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(isActive ? .white : .white.opacity(0.3))
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                isEliminated
                                    ? Color.red.opacity(0.3)
                                    : (isActive ? Color.green.opacity(0.1) : Color.white.opacity(0.04))
                            )
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider().background(Color.white.opacity(0.1))

                    // Current prompt
                    if let prompt = s.prompt {
                        Text(prompt)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Current turn banner
                    if let turn = s.currentTurn {
                        Text("YOUR TURN, \(turn.uppercased())")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(partyVM.color(for: turn))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(partyVM.color(for: turn).opacity(0.15))
                            .cornerRadius(10)
                    }

                    // Used answers
                    if !s.usedAnswers.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Used:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(s.usedAnswers, id: \.self) { answer in
                                        Text(answer)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Active player count
                    Text("\(s.activePlayers.count) player\(s.activePlayers.count == 1 ? "" : "s") remaining")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))

                    Spacer()

                    Image(systemName: "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.purple)
                        .padding(.bottom, 20)
                }
            }
        }
    }
}
