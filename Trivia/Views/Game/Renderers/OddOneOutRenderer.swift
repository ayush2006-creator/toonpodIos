import SwiftUI

struct OddOneOutRenderer: View {
    let question: Question
    let revealed: Bool
    let fiftyEliminated: [Int]
    var voiceSelected: String? = nil
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var locked = false
    @State private var selectedIdx: Int?

    private var options: [String] {
        // Backend sends "option1"…"option4" (no underscore) for odd_one_out
        [question.data.option1, question.data.option2,
         question.data.option3, question.data.option4]
            .compactMap { $0 }.filter { !$0.isEmpty }
    }

    private var correctAnswer: String {
        question.data.correctAnswer ?? ""
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(options.indices, id: \.self) { i in
                let eliminated = fiftyEliminated.contains(i)
                let isVoicePick = voiceSelected != nil && options[i] == voiceSelected
                let isTapPick = selectedIdx == i
                let showReveal = revealed && (selectedIdx != nil || voiceSelected != nil)

                AnswerButton(
                    text: options[i],
                    selected: (isTapPick || isVoicePick) && !showReveal,
                    correct: showReveal && options[i] == correctAnswer,
                    wrong: showReveal && (isTapPick || isVoicePick) && options[i] != correctAnswer,
                    disabled: locked || eliminated || voiceSelected != nil,
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
