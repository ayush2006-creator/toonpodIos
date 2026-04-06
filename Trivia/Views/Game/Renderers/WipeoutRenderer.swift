import SwiftUI

struct WipeoutRenderer: View {
    let question: Question
    let currentQ: Int
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var selected: Set<String> = []
    @State private var submitted = false
    @State private var results: [String: String] = [:]

    private var correctSet: Set<String> {
        Set((question.data.correctOptions ?? "").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    private var allOptions: [String] {
        // Use wipeout dynamic options (option_1 through option_9)
        if !question.data.wipeoutOptions.isEmpty {
            return question.data.wipeoutOptions
        }
        // Fallback: use standard options
        let q = question.data
        return [q.optionA, q.optionB, q.optionC, q.optionD].compactMap { $0 }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Options grid
            ForEach(allOptions, id: \.self) { opt in
                Button {
                    toggleOption(opt)
                } label: {
                    HStack(spacing: 12) {
                        // Checkbox
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(checkboxColor(opt: opt), lineWidth: 2)
                                .frame(width: 22, height: 22)

                            if selected.contains(opt) || results[opt] == "correct" {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(checkboxFill(opt: opt))
                                    .frame(width: 22, height: 22)
                                Image(systemName: submitted ? (results[opt] == "correct" ? "checkmark" : "xmark") : "checkmark")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }

                        Text(opt)
                            .font(.body)
                            .foregroundColor(optTextColor(opt: opt))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(optBackground(opt: opt))
                    .cornerRadius(12)
                }
                .disabled(submitted)
            }

            // Lock In button
            Button {
                handleSubmit()
            } label: {
                Text("Lock In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selected.isEmpty || submitted ? Color.gray.opacity(0.3) : Color.purple)
                    .cornerRadius(12)
            }
            .disabled(selected.isEmpty || submitted)
            .padding(.top, 8)
        }
    }

    private func toggleOption(_ opt: String) {
        guard !submitted else { return }
        if selected.contains(opt) {
            selected.remove(opt)
        } else {
            selected.insert(opt)
        }
    }

    private func handleSubmit() {
        guard !submitted else { return }
        submitted = true

        var correctPicks = 0
        var wrongPicks = 0
        var newResults: [String: String] = [:]

        for opt in allOptions {
            let isCorrectOpt = correctSet.contains(opt)
            let wasSelected = selected.contains(opt)
            if wasSelected && isCorrectOpt {
                newResults[opt] = "correct"
                correctPicks += 1
            } else if wasSelected && !isCorrectOpt {
                newResults[opt] = "wrong"
                wrongPicks += 1
            } else if !wasSelected && isCorrectOpt {
                newResults[opt] = "wrong"
            } else {
                newResults[opt] = "correct"
            }
        }
        results = newResults

        let ratio = Double(max(0, correctPicks - wrongPicks)) / Double(correctSet.count)
        let partialPrize = Int(round(Double(AppConstants.prizeLadder[currentQ]) * ratio))
        let selectedNames = Array(selected).joined(separator: ", ")
        onAnswer(ratio >= 0.6, question.data.interestingFact ?? "", FinishQuestionOptions(overridePrize: partialPrize, selectedText: selectedNames.isEmpty ? "no selections" : selectedNames))
    }

    // MARK: - Styling

    private func checkboxColor(opt: String) -> Color {
        if let r = results[opt] { return r == "correct" ? .green : .red }
        return selected.contains(opt) ? .purple : Color.white.opacity(0.3)
    }

    private func checkboxFill(opt: String) -> Color {
        if let r = results[opt] { return r == "correct" ? .green : .red }
        return .purple
    }

    private func optTextColor(opt: String) -> Color {
        if let r = results[opt] { return r == "correct" ? .green : .red }
        return .white
    }

    private func optBackground(opt: String) -> Color {
        if let r = results[opt] { return r == "correct" ? Color.green.opacity(0.1) : Color.red.opacity(0.1) }
        return selected.contains(opt) ? Color.purple.opacity(0.15) : Color.white.opacity(0.06)
    }
}
