import SwiftUI

struct BeforeAfterRenderer: View {
    let question: Question
    let revealed: Bool
    var voiceSelected: String? = nil
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var locked = false
    @State private var selectedIdx: Int?

    private let options = ["Before", "After"]

    private var correctAnswer: String {
        (question.data.correctAnswer ?? "").lowercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { i in
                let isVoicePick = voiceSelected != nil && options[i].lowercased() == voiceSelected?.lowercased()
                let isTapPick = selectedIdx == i
                let showReveal = revealed && (selectedIdx != nil || voiceSelected != nil)

                AnswerButton(
                    text: options[i],
                    selected: (isTapPick || isVoicePick) && !showReveal,
                    correct: showReveal && options[i].lowercased() == correctAnswer,
                    wrong: showReveal && (isTapPick || isVoicePick) && options[i].lowercased() != correctAnswer,
                    disabled: locked || voiceSelected != nil
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

        let isCorrect = options[idx].lowercased() == correctAnswer
        onAnswer(isCorrect, question.data.interestingFact ?? "", FinishQuestionOptions(selectedText: options[idx]))
    }
}
