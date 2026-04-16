import SwiftUI

struct WhichIsRenderer: View {
    let question: Question
    let revealed: Bool
    var voiceSelected: String? = nil
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var locked = false
    @State private var selectedIdx: Int?

    private var options: [String] {
        let q = question.data
        if let a = q.optionA, let b = q.optionB, !a.isEmpty, !b.isEmpty {
            return [a, b]
        }
        let queryText = q.question ?? q.query ?? ""
        let afterColon = queryText.components(separatedBy: ":").dropFirst().joined(separator: ":").replacingOccurrences(of: "?", with: "").trimmingCharacters(in: .whitespaces)
        let parts = afterColon.components(separatedBy: " or ").map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.count == 2 ? parts : ["Option A", "Option B"]
    }

    private var correctAnswer: String {
        (question.data.correctAnswer ?? "").lowercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<options.count, id: \.self) { i in
                let isVoicePick = voiceSelected != nil && options[i] == voiceSelected
                let isTapPick = selectedIdx == i
                let showReveal = revealed && (selectedIdx != nil || voiceSelected != nil)

                AnswerButton(
                    text: options[i],
                    selected: (isTapPick || isVoicePick) && !showReveal,
                    correct: showReveal && isOptionCorrect(options[i]),
                    wrong: showReveal && (isTapPick || isVoicePick) && !isOptionCorrect(options[i]),
                    disabled: locked || voiceSelected != nil
                ) {
                    handleTap(i)
                }
            }
        }
    }

    private func isOptionCorrect(_ opt: String) -> Bool {
        let lower = opt.lowercased()
        return lower.contains(correctAnswer) || correctAnswer.contains(lower)
    }

    private func handleTap(_ idx: Int) {
        guard !locked else { return }
        locked = true
        selectedIdx = idx

        let chosen = options[idx]
        let wasCorrect = isOptionCorrect(chosen)
        onAnswer(wasCorrect, question.data.interestingFact ?? "", FinishQuestionOptions(selectedText: chosen))
    }
}
