import SwiftUI

struct HiddenTimerRenderer: View {
    let question: Question
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    @State private var started = false
    @State private var buzzed = false
    @State private var startTime: Date?
    @State private var elapsed: Double = 0

    private var targetSeconds: Double {
        Double(question.data.correctAnswer ?? "10") ?? 10.0
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Target: \(Int(targetSeconds)) seconds")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.yellow)

            if !started {
                Button {
                    started = true
                    startTime = Date()
                } label: {
                    Text("Start Timer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple)
                        .cornerRadius(12)
                }
            } else if !buzzed {
                VStack(spacing: 16) {
                    Text("...")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))

                    Button {
                        buzz()
                    } label: {
                        Text("BUZZ!")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .frame(width: 150, height: 150)
                            .background(Circle().fill(Color.red))
                            .shadow(color: .red.opacity(0.5), radius: 20)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text(String(format: "%.1fs", elapsed))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(isClose ? .green : .orange)

                    Text("Target was \(Int(targetSeconds)) seconds")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))

                    Text(String(format: "Off by %.1f seconds", abs(elapsed - targetSeconds)))
                        .font(.subheadline)
                        .foregroundColor(isClose ? .green : .orange)
                }
            }
        }
    }

    private var isClose: Bool {
        abs(elapsed - targetSeconds) <= targetSeconds * 0.15
    }

    private func buzz() {
        guard let start = startTime else { return }
        buzzed = true
        elapsed = Date().timeIntervalSince(start)

        let close = isClose
        onAnswer(close, "You buzzed at \(String(format: "%.1f", elapsed))s, target was \(Int(targetSeconds))s",
                 FinishQuestionOptions(selectedText: String(format: "%.1fs", elapsed)))
    }
}
