import SwiftUI

struct LifelinesBar: View {
    let lifelines: Lifelines
    let questionType: QuestionType
    let onUse: (String) -> Void

    private var fiftyAvailable: Bool {
        lifelines.fiftyFifty && [.fourOptions, .oddOneOut, .guessThePicture, .pictureChoice].contains(questionType)
    }

    private var hintAvailable: Bool {
        lifelines.hint && questionType != .guessThePicture
    }

    private var swapAvailable: Bool {
        lifelines.swap && ![.lightning, .guessThePicture, .wipeout].contains(questionType)
    }

    var body: some View {
        HStack(spacing: 16) {
            LifelineButton(
                icon: "divide.circle.fill",
                label: "50:50",
                available: fiftyAvailable,
                used: !lifelines.fiftyFifty
            ) {
                onUse("fiftyFifty")
            }

            LifelineButton(
                icon: "lightbulb.fill",
                label: "Hint",
                available: hintAvailable,
                used: !lifelines.hint
            ) {
                onUse("hint")
            }

            LifelineButton(
                icon: "arrow.triangle.2.circlepath",
                label: "Swap",
                available: swapAvailable,
                used: !lifelines.swap
            ) {
                onUse("swap")
            }
        }
    }
}

struct LifelineButton: View {
    let icon: String
    let label: String
    let available: Bool
    let used: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(available ? .white : .white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(available ? Color.purple.opacity(0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(available ? Color.purple.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .disabled(!available)
        .overlay(alignment: .topTrailing) {
            if used {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                    .offset(x: 4, y: -4)
            }
        }
    }
}
