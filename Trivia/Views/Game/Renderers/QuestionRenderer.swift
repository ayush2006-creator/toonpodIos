import SwiftUI

/// Routes to the correct question type renderer
struct QuestionRenderer: View {
    let question: Question
    @ObservedObject var gameVM: GameViewModel
    let onAnswer: (Bool, String, FinishQuestionOptions) -> Void

    var body: some View {
        switch question.type {
        case .fourOptions:
            FourOptionsRenderer(
                question: question,
                revealed: gameVM.answerRevealed,
                fiftyEliminated: gameVM.fiftyEliminated,
                onAnswer: onAnswer
            )
        case .whichIs:
            WhichIsRenderer(
                question: question,
                revealed: gameVM.answerRevealed,
                onAnswer: onAnswer
            )
        case .beforeAfterBinary:
            BeforeAfterRenderer(
                question: question,
                revealed: gameVM.answerRevealed,
                onAnswer: onAnswer
            )
        case .oddOneOut:
            OddOneOutRenderer(
                question: question,
                revealed: gameVM.answerRevealed,
                fiftyEliminated: gameVM.fiftyEliminated,
                onAnswer: onAnswer
            )
        case .lightning:
            LightningRenderer(
                question: question,
                currentQ: gameVM.currentQ,
                onAnswer: onAnswer
            )
        case .beforeAfterChain:
            ChainRenderer(
                question: question,
                currentQ: gameVM.currentQ,
                onAnswer: onAnswer
            )
        case .wipeout:
            WipeoutRenderer(
                question: question,
                currentQ: gameVM.currentQ,
                onAnswer: onAnswer
            )
        case .fill4th:
            Fill4thRenderer(
                question: question,
                onAnswer: onAnswer
            )
        case .closestNumber:
            ClosestNumberRenderer(
                question: question,
                onAnswer: onAnswer
            )
        case .guessThePicture:
            GuessThePictureRenderer(
                question: question,
                revealed: gameVM.answerRevealed,
                onAnswer: onAnswer
            )
        case .hiddenTimer:
            HiddenTimerRenderer(
                question: question,
                onAnswer: onAnswer
            )
        case .pictureChoice:
            PictureChoiceRenderer(
                question: question,
                revealed: gameVM.answerRevealed,
                onAnswer: onAnswer
            )
        }
    }
}
