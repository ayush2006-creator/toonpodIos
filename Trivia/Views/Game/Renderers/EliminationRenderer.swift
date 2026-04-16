import SwiftUI

struct EliminationRenderer: View {
    let question: Question
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Elimination Round")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Wait for the avatar instructions!")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(16)
    }
}
