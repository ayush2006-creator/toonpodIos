import SwiftUI

struct RoundTitleCard: View {
    let round: PartyRound
    var subtitle: String? = nil
    let onDismiss: () -> Void

    @State private var phase: AnimPhase = .enter

    private enum AnimPhase { case enter, hold, exit }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(round.rawValue)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .multilineTextAlignment(.center)

                if let sub = subtitle {
                    Text(sub)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .scaleEffect(phase == .hold ? 1.0 : (phase == .enter ? 0.7 : 1.1))
            .opacity(phase == .hold ? 1.0 : 0)
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        withAnimation(.spring(duration: 0.5)) { phase = .hold }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeIn(duration: 0.4)) { phase = .exit }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onDismiss()
            }
        }
    }
}
