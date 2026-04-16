import SwiftUI

struct FourOptionsRenderer: View {
    let question: Question
    let revealed: Bool
    let fiftyEliminated: [Int]
    var hotSeatPlayerAnswer: String? = nil
    var voiceSelected: String? = nil
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
                let isVoicePick = voiceSelected != nil && options[i] == voiceSelected
                let isTapPick = selectedIdx == i
                let isHotSeat = hotSeatPlayerAnswer != nil && options[i] == hotSeatPlayerAnswer
                // Reveal when tap or voice (or hotSeat) selected AND answer is revealed
                let showReveal = revealed && (selectedIdx != nil || voiceSelected != nil || hotSeatPlayerAnswer != nil)

                let isWrongAns = showReveal && options[i] != correctOption && (isTapPick || isVoicePick || isHotSeat)

                AnswerButton(
                    text: options[i],
                    optionLabel: labels[i],
                    selected: (isTapPick || isVoicePick || isHotSeat) && !showReveal,
                    correct: showReveal && options[i] == correctOption,
                    wrong: isWrongAns,
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

        let isCorrect = options[idx] == correctOption
        onAnswer(isCorrect, question.data.interestingFact ?? "", FinishQuestionOptions(selectedText: options[idx]))
    }
}
