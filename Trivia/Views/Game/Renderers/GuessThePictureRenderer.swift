import SwiftUI

struct GuessThePictureRenderer: View {
    let question: Question
    let revealed: Bool
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var locked = false
    @State private var selectedIdx: Int?
    @State private var clueIndex = 0

    private var clues: [String] {
        question.data.clues ?? question.hints ?? []
    }

    private var correctAnswer: String {
        question.data.name ?? question.answer ?? question.data.correctAnswer ?? ""
    }

    private var options: [String] {
        question.options ?? [question.data.optionA ?? "", question.data.optionB ?? "",
                             question.data.optionC ?? "", question.data.optionD ?? ""].filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Clues revealed progressively
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0...min(clueIndex, clues.count - 1), id: \.self) { i in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text(clues[i])
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)

            // Reveal next clue button
            if clueIndex < clues.count - 1 && !locked {
                Button {
                    withAnimation { clueIndex += 1 }
                } label: {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("Reveal Next Clue")
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(8)
                }
            }

            // Answer options
            if !options.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<options.count, id: \.self) { i in
                        let showReveal = revealed && selectedIdx != nil

                        AnswerButton(
                            text: options[i],
                            selected: selectedIdx == i && !showReveal,
                            correct: showReveal && options[i].lowercased() == correctAnswer.lowercased(),
                            wrong: showReveal && selectedIdx == i && options[i].lowercased() != correctAnswer.lowercased(),
                            disabled: locked
                        ) {
                            handleTap(i)
                        }
                    }
                }
            }
        }
    }

    private func handleTap(_ idx: Int) {
        guard !locked else { return }
        locked = true
        selectedIdx = idx

        let chosen = options[idx]
        let isCorrect = chosen.lowercased() == correctAnswer.lowercased()
        onAnswer(isCorrect, question.data.interestingFact ?? question.interestingFact ?? "", FinishQuestionOptions(selectedText: chosen))
    }
}
