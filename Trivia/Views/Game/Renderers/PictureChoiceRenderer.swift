import SwiftUI

struct PictureChoiceRenderer: View {
    let question: Question
    let revealed: Bool
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var selected: String?

    private var options: [String] {
        question.options ?? [
            question.data.optionA ?? "",
            question.data.optionB ?? "",
            question.data.optionC ?? "",
            question.data.optionD ?? "",
        ].filter { !$0.isEmpty }
    }

    private var images: [String] {
        question.images ?? []
    }

    private var correctAnswer: String {
        question.data.correctOption ?? question.data.correctAnswer ?? question.answer ?? ""
    }

    var body: some View {
        VStack(spacing: 16) {
            // Image grid - 2x2
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    PictureOptionCard(
                        option: option,
                        imageURL: index < images.count ? images[index] : nil,
                        isSelected: selected == option,
                        isCorrect: revealed && option.lowercased() == correctAnswer.lowercased(),
                        isWrong: revealed && selected == option && option.lowercased() != correctAnswer.lowercased(),
                        isDisabled: revealed
                    ) {
                        guard !revealed, selected == nil else { return }
                        selected = option
                        let isCorrect = option.lowercased() == correctAnswer.lowercased()
                        let fact = question.data.interestingFact ?? question.interestingFact ?? ""
                        onAnswer(isCorrect, fact, FinishQuestionOptions())
                    }
                }
            }
        }
    }
}

// MARK: - Picture Option Card

struct PictureOptionCard: View {
    let option: String
    let imageURL: String?
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Image area
                if let urlString = imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 100)
                                .clipped()
                        case .failure:
                            imagePlaceholder
                        case .empty:
                            ProgressView()
                                .frame(height: 100)
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                    .cornerRadius(8)
                } else {
                    imagePlaceholder
                }

                // Option label
                Text(option)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(10)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected || isCorrect ? 2 : 1)
            )
        }
        .disabled(isDisabled)
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.05))
            .frame(height: 100)
            .overlay(
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.3))
            )
    }

    private var backgroundColor: Color {
        if isCorrect { return .green.opacity(0.15) }
        if isWrong { return .red.opacity(0.15) }
        if isSelected { return .purple.opacity(0.2) }
        return Color.white.opacity(0.05)
    }

    private var borderColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isSelected { return .purple }
        return Color.white.opacity(0.1)
    }
}
