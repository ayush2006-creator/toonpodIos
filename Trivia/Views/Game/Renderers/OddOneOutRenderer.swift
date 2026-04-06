import SwiftUI

struct OddOneOutRenderer: View {
    let question: Question
    let revealed: Bool
    let fiftyEliminated: [Int]
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var locked = false
    @State private var selectedIdx: Int?

    private var options: [String] {
        [question.data.option1 ?? "", question.data.option2 ?? "",
         question.data.option3 ?? "", question.data.option4 ?? ""]
    }

    private var correctAnswer: String {
        question.data.correctAnswer ?? ""
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { i in
                let eliminated = fiftyEliminated.contains(i)
                let showReveal = revealed && selectedIdx != nil

                AnswerButton(
                    text: options[i],
                    selected: selectedIdx == i && !showReveal,
                    correct: showReveal && options[i] == correctAnswer,
                    wrong: showReveal && selectedIdx == i && options[i] != correctAnswer,
                    disabled: locked || eliminated,
                    fiftyHidden: eliminated
                ) {
                    handleTap(i)
                }
            }
        }
    }

    private func handleTap(_ idx: Int) {
        guard !locked else { return }
        locked = true
        selectedIdx = idx

        let isCorrect = options[idx] == correctAnswer
        let fact = "The connection is: \(question.data.connection ?? "")"
        onAnswer(isCorrect, fact, FinishQuestionOptions(selectedText: options[idx]))
    }
}
