import SwiftUI

struct PartySetupScreen: View {
    @EnvironmentObject var gameVM: GameViewModel
    @EnvironmentObject var partyVM: PartyViewModel

    @State private var playerCount: Int = 3

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a0533"), Color(hex: "0d001a")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Party Mode")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    Text("How many players?")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Player count selector
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        ForEach(2...6, id: \.self) { count in
                            Button {
                                playerCount = count
                            } label: {
                                VStack(spacing: 6) {
                                    Text("\(count)")
                                        .font(.system(size: 28, weight: .bold))
                                    Text(count == 1 ? "player" : "players")
                                        .font(.caption)
                                }
                                .foregroundColor(playerCount == count ? .white : .white.opacity(0.4))
                                .frame(width: 56, height: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(playerCount == count
                                              ? Color.purple.opacity(0.6)
                                              : Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(playerCount == count ? Color.purple : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                }

                // Info card
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(icon: "mic.fill", text: "The avatar will ask each player to say their name")
                    InfoRow(icon: "hand.raised.fill", text: "Say 'mine' or 'buzz' to answer questions")
                    InfoRow(icon: "star.fill", text: "Special rounds: Auction, Wager, Steal, Hot Seat & more")
                }
                .padding(20)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .padding(.horizontal, 24)

                // Start button
                NavigationLink(value: AppRoute.partyGame) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.3.fill")
                        Text("Start Registration")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.purple)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    partyVM.targetPlayerCount = playerCount
                    partyVM.registrationPhase = true
                    partyVM.registeredNames = []
                    gameVM.partyMode = true
                })
            }
            .padding(.top, 40)
        }
        .navigationBarBackButtonHidden(false)
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.purple)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
