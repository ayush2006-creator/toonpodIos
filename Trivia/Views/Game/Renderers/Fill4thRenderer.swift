import SwiftUI

struct Fill4thRenderer: View {
    let question: Question
    var revealed: Bool = false
    var voiceAnswer: String? = nil
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var userInput = ""
    @State private var submitted = false
    @State private var isCorrect: Bool?

    private var items: [String] {
        let q = question.data
        return [q.option1, q.option2, q.option3]
            .compactMap { $0 }.filter { !$0.isEmpty }
    }

    private var connection: String {
        question.data.connection ?? ""
    }

    // For voice answers: local correctness check used only for display coloring.
    // Actual scoring comes from the server result passed via handleAnswer in GameScreen.
    private var voiceAnswerCorrect: Bool {
        guard let va = voiceAnswer else { return false }
        let answer = va.lowercased().trimmingCharacters(in: .whitespaces)
        let correct = (question.data.correctAnswer ?? "").lowercased()
        if !correct.isEmpty && (answer == correct || correct.contains(answer) || answer.contains(correct)) {
            return true
        }
        let samples = (question.data.sampleAnswers ?? "").lowercased()
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return samples.contains { !$0.isEmpty && answer.contains($0) }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Show the 3 given items
            HStack(spacing: 8) {
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

            // Voice answer display
            if let va = voiceAnswer {
                let correct = revealed ? voiceAnswerCorrect : nil as Bool?
                HStack(spacing: 10) {
                    if let c = correct {
                        Image(systemName: c ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(c ? .green : .red)
                    } else {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.purple)
                    }
                    Text(va)
                        .fontWeight(.semibold)
                        .foregroundColor(revealed ? (voiceAnswerCorrect ? .green : .red) : .white)
                    if revealed && !voiceAnswerCorrect {
                        Text("· \(question.data.correctAnswer ?? "")")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    revealed
                        ? (voiceAnswerCorrect ? Color.green : Color.red).opacity(0.12)
                        : Color.purple.opacity(0.12)
                )
                .cornerRadius(10)
            } else {
                // Manual text input
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
        .onChange(of: voiceAnswer) { answer in
            guard let answer, !answer.isEmpty, !submitted else { return }
            submitted = true
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
