import SwiftUI

struct ClosestNumberRenderer: View {
    let question: Question
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var userInput = ""
    @State private var submitted = false
    @State private var result: Bool?

    private var correctAnswer: String {
        question.data.correctAnswer ?? ""
    }

    var body: some View {
        VStack(spacing: 16) {
            // Number input
            HStack(spacing: 12) {
                TextField("Your guess...", text: $userInput)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .disabled(submitted)

                Button {
                    submitAnswer()
                } label: {
                    Text("Lock In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(userInput.isEmpty || submitted ? Color.gray.opacity(0.3) : Color.purple)
                        .cornerRadius(10)
                }
                .disabled(userInput.isEmpty || submitted)
            }

            if submitted {
                VStack(spacing: 8) {
                    Text("The answer is: \(correctAnswer)")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let result {
                        HStack {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? .green : .orange)
                            Text(result ? "Close enough!" : "Not quite close enough")
                                .foregroundColor(result ? .green : .orange)
                        }
                    }
                }
            }
        }
    }

    private func submitAnswer() {
        guard !submitted else { return }
        submitted = true

        guard let userNum = Double(userInput), let correctNum = Double(correctAnswer) else {
            result = false
            onAnswer(false, question.data.interestingFact ?? "", FinishQuestionOptions(selectedText: userInput))
            return
        }

        let tolerance = correctNum * 0.15 // 15% tolerance
        let isClose = abs(userNum - correctNum) <= tolerance
        result = isClose

        onAnswer(isClose, question.data.interestingFact ?? "", FinishQuestionOptions(selectedText: userInput))
    }
}
