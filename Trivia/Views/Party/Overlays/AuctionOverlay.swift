import SwiftUI

struct AuctionOverlay: View {
    @EnvironmentObject var partyVM: PartyViewModel
    let onWinnerSelected: (String, Int) -> Void  // winner name, bid deducted

    @State private var phase: AuctionPhase = .bidding
    @State private var closingLabel: String = "Going once..."
    @State private var closingStep = 0

    var sortedBids: [(name: String, bid: Int)] {
        (partyVM.auctionState?.bids ?? [:])
            .map { (name: $0.key, bid: $0.value) }
            .sorted { $0.bid > $1.bid }
    }

    var topBidder: String? { sortedBids.first?.name }
    var topBid: Int { sortedBids.first?.bid ?? 0 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                HStack {
                    Text("🔨")
                        .font(.system(size: 32))
                    Text("AUCTION")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                }

                // Instruction
                Text(phase == .bidding
                     ? "Buzz in and place your bid!"
                     : (phase == .closing ? closingLabel : "SOLD!"))
                    .font(.title3)
                    .foregroundColor(.yellow)
                    .animation(.easeInOut, value: closingLabel)

                // Bid cards
                if sortedBids.isEmpty {
                    Text("Waiting for bids...")
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(sortedBids.enumerated()), id: \.element.name) { idx, entry in
                            HStack {
                                Text(idx == 0 ? "👑" : "  ")
                                Text(entry.name)
                                    .fontWeight(.bold)
                                Spacer()
                                Text(formatMoney(entry.bid))
                                    .fontWeight(.bold)
                                    .foregroundColor(.yellow)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                partyVM.color(for: entry.name)
                                    .opacity(idx == 0 ? 0.35 : 0.15)
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Sold action
                if phase == .sold, let winner = topBidder {
                    VStack(spacing: 8) {
                        Text("\(winner) wins the auction!")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        Text("Bid: \(formatMoney(topBid))")
                            .foregroundColor(.yellow)
                    }
                    .padding(.top, 8)

                    Button {
                        onWinnerSelected(winner, topBid)
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
            .padding(.vertical, 40)
            .background(Color(hex: "1a0533").opacity(0.97))
            .cornerRadius(24)
            .padding(.horizontal, 16)
        }
        .onReceive(partyVM.$auctionState) { state in
            if let state { phase = state.phase }
        }
        .onChange(of: phase) {
            if phase == .closing { startClosingSequence() }
        }
    }

    private func startClosingSequence() {
        let labels = ["Going once...", "Going twice...", "SOLD! 🔨"]
        closingStep = 0
        scheduleClose(labels: labels)
    }

    private func scheduleClose(labels: [String]) {
        guard closingStep < labels.count else { return }
        closingLabel = labels[closingStep]
        if closingStep == labels.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                partyVM.auctionState?.phase = .sold
            }
        } else {
            closingStep += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                scheduleClose(labels: labels)
            }
        }
    }

    private func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000 { return "$\(amount / 1_000)k" }
        return "$\(amount)"
    }
}
