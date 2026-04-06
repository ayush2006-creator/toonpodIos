import SwiftUI

struct FourOptionsRenderer: View {
    let question: Question
    let revealed: Bool
    let fiftyEliminated: [Int]
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var locked = false
    @State private var selectedIdx: Int?

    private let labels = ["A", "B", "C", "D"]

    private var options: [String] {
        [question.data.optionA ?? "", question.data.optionB ?? "",
         question.data.optionC ?? "", question.data.optionD ?? ""]
    }

    private var correctOption: String {
        question.data.correctOption ?? ""
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { i in
                let eliminated = fiftyEliminated.contains(i)
                let showReveal = revealed && selectedIdx != nil

                AnswerButton(
                    text: options[i],
                    optionLabel: labels[i],
                    selected: selectedIdx == i && !showReveal,
                    correct: showReveal && options[i] == correctOption,
                    wrong: showReveal && selectedIdx == i && options[i] != correctOption,
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

        let isCorrect = options[idx] == correctOption
        onAnswer(isCorrect, question.data.interestingFact ?? "", FinishQuestionOptions(selectedText: options[idx]))
    }
}
