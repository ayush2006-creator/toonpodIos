import SwiftUI

struct AnswerButton: View {
    let text: String
    var optionLabel: String? = nil
    var selected: Bool = false
    var correct: Bool = false
    var wrong: Bool = false
    var disabled: Bool = false
    var fiftyHidden: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let label = optionLabel {
                    Text(label)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(labelColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(labelBackground))
                }

                Text(text)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()

                if correct {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if wrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .disabled(disabled)
        .opacity(fiftyHidden ? 0.2 : 1)
        .animation(.easeInOut(duration: 0.3), value: correct)
        .animation(.easeInOut(duration: 0.3), value: wrong)
        .animation(.easeInOut(duration: 0.3), value: selected)
    }

    private var backgroundColor: Color {
        if correct { return Color.green.opacity(0.2) }
        if wrong { return Color.red.opacity(0.2) }
        if selected { return Color.purple.opacity(0.3) }
        return Color.white.opacity(0.08)
    }

    private var borderColor: Color {
        if correct { return .green }
        if wrong { return .red }
        if selected { return .purple }
        return Color.white.opacity(0.15)
    }

    private var textColor: Color {
        if correct { return .green }
        if wrong { return .red }
        if fiftyHidden { return .white.opacity(0.3) }
        return .white
    }

    private var labelColor: Color {
        if correct { return .green }
        if wrong { return .red }
        if selected { return .white }
        return .white.opacity(0.7)
    }

    private var labelBackground: Color {
        if correct { return .green.opacity(0.2) }
        if wrong { return .red.opacity(0.2) }
        if selected { return .purple }
        return Color.white.opacity(0.1)
    }
}
