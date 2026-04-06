import SwiftUI

struct LightningRenderer: View {
    let question: Question
    let currentQ: Int
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var idx = 0
    @State private var correctCount = 0
    @State private var subResults: [Bool] = []
    @State private var subLocked = false
    @State private var subSelectedIdx: Int?
    @State private var subResult: Bool?
    @State private var countdown = 5

    private let subQTimeLimit = 5

    private var questions: [String] {
        (question.data.questions ?? "").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private var types: [String] {
        (question.data.questionTypes ?? "").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private var answers: [String] {
        (question.data.correctAnswers ?? "").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var body: some View {
        if idx >= questions.count {
            EmptyView()
        } else {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("\u{26A1} \(idx + 1) / \(questions.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)

                    Spacer()

                    Text("\(countdown)s")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(countdown <= 2 ? .red : .white.opacity(0.7))

                    Spacer()

                    // Dot tracker
                    HStack(spacing: 4) {
                        ForEach(0..<questions.count, id: \.self) { i in
                            Circle()
                                .fill(dotColor(for: i))
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                // Sub question
                Text(questions[idx])
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)

                // Options
                HStack(spacing: 12) {
                    ForEach(0..<subOptions.count, id: \.self) { i in
                        AnswerButton(
                            text: subOptions[i],
                            correct: subResult != nil && checkCorrect(subOptions[i]),
                            wrong: subResult != nil && subSelectedIdx == i && !checkCorrect(subOptions[i]),
                            disabled: subLocked
                        ) {
                            handleSubClick(i)
                        }
                    }
                }
            }
            .onAppear { startCountdown() }
            .onChange(of: idx) { startCountdown() }
        }
    }

    private var subOptions: [String] {
        guard idx < types.count else { return [] }
        let subType = types[idx]
        if subType == "true_false" { return ["True", "False"] }
        if subType == "before_after" { return ["Before", "After"] }
        if subType == "which_is" {
            let subQ = questions[idx]
            let afterColon = subQ.components(separatedBy: ":").dropFirst().joined(separator: ":").replacingOccurrences(of: "?", with: "").trimmingCharacters(in: .whitespaces)
            let parts = afterColon.components(separatedBy: " or ").map { $0.trimmingCharacters(in: .whitespaces) }
            return parts.count == 2 ? parts : ["Option A", "Option B"]
        }
        return ["True", "False"]
    }

    private func checkCorrect(_ opt: String) -> Bool {
        guard idx < answers.count else { return false }
        let subAnswer = answers[idx].lowercased()
        let subType = idx < types.count ? types[idx] : ""
        if subType == "true_false" || subType == "before_after" {
            return opt.lowercased() == subAnswer
        }
        return opt.lowercased().contains(subAnswer) || subAnswer.contains(opt.lowercased())
    }

    private func handleSubClick(_ optIdx: Int) {
        guard !subLocked else { return }
        subLocked = true
        subSelectedIdx = optIdx

        let isCorrect = checkCorrect(subOptions[optIdx])
        subResult = isCorrect
        subResults.append(isCorrect)
        if isCorrect { correctCount += 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            advanceSubQuestion()
        }
    }

    private func advanceSubQuestion() {
        let nextIdx = idx + 1
        subLocked = false
        subSelectedIdx = nil
        subResult = nil

        if nextIdx >= questions.count {
            let prize = Int(round(Double(AppConstants.prizeLadder[currentQ]) * (Double(correctCount) / Double(questions.count))))
            onAnswer(correctCount >= 4, "Lightning round complete!", FinishQuestionOptions(
                overridePrize: prize,
                skipTimer: true,
                selectedText: "\(correctCount) out of \(questions.count) correct"
            ))
        }
        idx = nextIdx
    }

    private func startCountdown() {
        countdown = subQTimeLimit
    }

    private func dotColor(for i: Int) -> Color {
        if i < subResults.count {
            return subResults[i] ? .green : .red
        }
        if i == idx { return .yellow }
        return .white.opacity(0.2)
    }
}
