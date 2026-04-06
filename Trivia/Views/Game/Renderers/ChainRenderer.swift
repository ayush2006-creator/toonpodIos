import SwiftUI

struct ChainRenderer: View {
    let question: Question
    let currentQ: Int
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var chainOrder: [String] = []
    @State private var submitted = false
    @State private var resultMap: [String: String] = [:]

    private var items: [String] {
        (question.data.givenOptions ?? "").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private var correctSeq: [String] {
        (question.data.correctSequence ?? "").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    @State private var shuffled: [String] = []

    var body: some View {
        VStack(spacing: 12) {
            // Items
            ForEach(sortedItems, id: \.self) { item in
                let pos = chainOrder.firstIndex(of: item)
                let isOrdered = pos != nil

                Button {
                    handleClick(item)
                } label: {
                    HStack(spacing: 12) {
                        // Position number
                        ZStack {
                            Circle()
                                .fill(itemCircleColor(item: item, isOrdered: isOrdered))
                                .frame(width: 32, height: 32)
                            if submitted, let result = resultMap[item], result == "wrong" {
                                Text("\((correctSeq.firstIndex(of: item) ?? 0) + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            } else if let p = pos {
                                Text("\(p + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }

                        Text(item)
                            .font(.body)
                            .foregroundColor(itemTextColor(item: item))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(itemBackground(item: item, isOrdered: isOrdered))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(itemBorder(item: item, isOrdered: isOrdered), lineWidth: 1)
                    )
                }
                .disabled(submitted)
            }

            // Instructions
            Text("Tap items in chronological order (tap again to undo)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
        }
        .onAppear {
            shuffled = items.shuffled()
        }
    }

    private var sortedItems: [String] {
        let ordered = chainOrder.filter { shuffled.contains($0) }
        let unordered = shuffled.filter { !chainOrder.contains($0) }
        return ordered + unordered
    }

    private func handleClick(_ item: String) {
        guard !submitted else { return }

        if let idx = chainOrder.firstIndex(of: item) {
            chainOrder = Array(chainOrder.prefix(idx))
        } else {
            chainOrder.append(item)

            // Auto-add last item
            if chainOrder.count == items.count - 1 {
                if let remaining = items.first(where: { !chainOrder.contains($0) }) {
                    chainOrder.append(remaining)
                }
            }

            // Auto-submit when complete
            if chainOrder.count == items.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    submitChain()
                }
            }
        }
    }

    private func submitChain() {
        guard !submitted else { return }
        submitted = true

        var correctCount = 0
        var newResultMap: [String: String] = [:]

        for (playerPos, item) in chainOrder.enumerated() {
            let correctPos = correctSeq.firstIndex(of: item) ?? -1
            if playerPos == correctPos {
                newResultMap[item] = "correct"
                correctCount += 1
            } else {
                newResultMap[item] = "wrong"
            }
        }
        resultMap = newResultMap

        let isCorrect = correctCount == correctSeq.count
        let ratio = Double(correctCount) / Double(correctSeq.count)
        let partialPrize = Int(round(Double(AppConstants.prizeLadder[currentQ]) * ratio))
        let fact = (question.data.interestingFact ?? "") +
            (isCorrect ? "" : "\n\nCorrect order: \(correctSeq.joined(separator: " -> "))")
        onAnswer(isCorrect, fact, FinishQuestionOptions(overridePrize: partialPrize, selectedText: chainOrder.joined(separator: " then ")))
    }

    // MARK: - Styling helpers

    private func itemCircleColor(item: String, isOrdered: Bool) -> Color {
        if let result = resultMap[item] {
            return result == "correct" ? .green : .red
        }
        return isOrdered ? .purple : Color.white.opacity(0.1)
    }

    private func itemTextColor(item: String) -> Color {
        if let result = resultMap[item] {
            return result == "correct" ? .green : .red
        }
        return .white
    }

    private func itemBackground(item: String, isOrdered: Bool) -> Color {
        if let result = resultMap[item] {
            return result == "correct" ? Color.green.opacity(0.15) : Color.red.opacity(0.15)
        }
        return isOrdered ? Color.purple.opacity(0.2) : Color.white.opacity(0.06)
    }

    private func itemBorder(item: String, isOrdered: Bool) -> Color {
        if let result = resultMap[item] {
            return result == "correct" ? .green.opacity(0.5) : .red.opacity(0.5)
        }
        return isOrdered ? .purple.opacity(0.5) : Color.white.opacity(0.1)
    }
}
