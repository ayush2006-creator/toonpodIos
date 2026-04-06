import SwiftUI

struct Fill4thRenderer: View {
    let question: Question
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var userInput = ""
    @State private var submitted = false
    @State private var isCorrect: Bool?

    private var items: [String] {
        let q = question.data
        return [q.option1 ?? q.optionA ?? "", q.option2 ?? q.optionB ?? "", q.option3 ?? q.optionC ?? ""]
            .filter { !$0.isEmpty }
    }

    private var connection: String {
        question.data.connection ?? ""
    }

    var body: some View {
        VStack(spacing: 16) {
            // Show the 3 items
            HStack(spacing: 12) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.3))
                        .cornerRadius(8)
                }
                Text("?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }

            if !connection.isEmpty {
                Text("Connection: \(connection)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            // Input field
            HStack(spacing: 12) {
                TextField("Type the 4th item...", text: $userInput)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .disabled(submitted)

                Button {
                    submitAnswer()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(userInput.isEmpty || submitted ? .gray : .purple)
                }
                .disabled(userInput.isEmpty || submitted)
            }

            if let result = isCorrect {
                HStack {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result ? .green : .red)
                    Text(result ? "Correct!" : "The answer was: \(question.data.correctAnswer ?? "")")
                        .foregroundColor(result ? .green : .red)
                }
            }
        }
    }

    private func submitAnswer() {
        guard !submitted else { return }
        submitted = true

        let correct = (question.data.correctAnswer ?? "").lowercased()
        let answer = userInput.trimmingCharacters(in: .whitespaces).lowercased()
        let result = answer == correct || correct.contains(answer) || answer.contains(correct)
        isCorrect = result

        onAnswer(result, question.data.interestingFact ?? "", FinishQuestionOptions(selectedText: userInput))
    }
}
