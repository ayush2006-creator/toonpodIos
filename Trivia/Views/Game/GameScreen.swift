import SwiftUI

struct GameScreen: View {
    @EnvironmentObject var gameVM: GameViewModel
    @EnvironmentObject var avatarVM: AvatarViewModel
    @StateObject private var speechService = SpeechService.shared
    @State private var showExitAlert = false
    @State private var navigateToResults = false
    @State private var showIntro = true
    @State private var showBriefing = false
    @State private var showSwapDialog = false
    @State private var swapTopic = ""
    @State private var isSwapping = false
    @State private var showSkipButton = false
    @State private var voiceToggle = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a0533"), Color(hex: "0d001a")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if showIntro {
                IntroAnimationView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showIntro = false
                        showBriefing = true
                    }
                }
            } else if showBriefing {
                BriefingView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showBriefing = false
                    }
                }
            } else if gameVM.isLoading {
                loadingView
            } else if let error = gameVM.errorMessage {
                errorView(error)
            } else if gameVM.gameComplete {
                Color.clear.onAppear {
                    navigateToResults = true
                }
            } else if let question = gameVM.currentQuestion {
                VStack(spacing: 0) {
                    // Header with voice toggle
                    GameHeader(
                        questionNumber: gameVM.currentQ + 1,
                        totalQuestions: gameVM.totalQuestions,
                        totalWinnings: gameVM.totalWinnings,
                        voiceEnabled: $voiceToggle,
                        onExit: { showExitAlert = true }
                    )

                    // Avatar panel
                    AvatarGamePanel(avatarVM: avatarVM, speechService: speechService)

                    if gameVM.showQuestion {
                        questionView(question)
                    } else if gameVM.showFeedback, let feedback = gameVM.feedbackData {
                        feedbackView(feedback)
                    }
                }
                // Skip button overlay
                .overlay(alignment: .bottomTrailing) {
                    if showSkipButton && avatarVM.isSpeaking {
                        Button {
                            avatarVM.stopSpeaking()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "forward.fill")
                                    .font(.caption2)
                                Text("Skip")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)
                        .transition(.opacity)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToResults) {
            ResultsScreen()
        }
        .alert("Exit Game?", isPresented: $showExitAlert) {
            Button("Continue Playing", role: .cancel) { }
            Button("Exit", role: .destructive) {
                stopVoiceInput()
                avatarVM.stopSpeaking()
                gameVM.gameAborted = true
            }
        } message: {
            Text("Your progress will be saved.")
        }
        .sheet(isPresented: $showSwapDialog) {
            SwapDialogView(
                topic: $swapTopic,
                isSwapping: $isSwapping,
                onSwap: { topic in
                    Task {
                        isSwapping = true
                        gameVM.useLifeline("swap")
                        do {
                            let currentType = gameVM.currentQuestion?.type.rawValue ?? "4_options"
                            let newQuestion = try await APIService.shared.generateQuestion(
                                topic: topic,
                                difficulty: gameVM.currentLevel,
                                type: currentType,
                                category: gameVM.selectedCategory
                            )
                            gameVM.replaceCurrentQuestion(newQuestion)
                            gameVM.showQuestionUI()
                            gameVM.startTimer()
                            // Re-ask the new question
                            await runAskQuestion()
                        } catch {
                            print("[GameScreen] Swap failed: \(error)")
                        }
                        isSwapping = false
                        showSwapDialog = false
                    }
                },
                onCancel: {
                    showSwapDialog = false
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: voiceToggle) {
            avatarVM.voiceEnabled = voiceToggle
            if voiceToggle {
                speechService.requestAuthorization()
            } else {
                stopVoiceInput()
            }
        }
        .task {
            // Set avatar model from selection
            if let avatar = appAvatars.first(where: { $0.id == gameVM.selectedAvatarId }) {
                avatarVM.selectAvatar(avatar)
            }
            gameVM.resetGame(level: gameVM.currentLevel)
            await gameVM.loadQuestions()

            // Request speech auth early if voice was enabled
            speechService.requestAuthorization()

            // Run the game orchestration
            await runGameFlow()
        }
    }

    // MARK: - Game Flow Orchestration

    private func runGameFlow() async {
        guard !gameVM.gameData.isEmpty else { return }

        // 1. Briefing
        await avatarVM.runBriefing(playerName: nil)

        // Prefetch first question dialogue
        if let q = gameVM.currentQuestion {
            let text = Dialogue.formatQuestion(q, number: 1, prize: gameVM.currentPrize)
            avatarVM.prefetchDialogue(text)
        }

        // 2. Ask first question
        await runAskQuestion()
    }

    private func runAskQuestion() async {
        guard let question = gameVM.currentQuestion else { return }

        // Show skip button after delay
        showSkipButton = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSkipButton = true
        }

        // Avatar reads the question aloud
        await avatarVM.askQuestion(
            question,
            number: gameVM.currentQ + 1,
            prize: gameVM.currentPrize
        )

        showSkipButton = false

        // Start timer when avatar finishes asking
        gameVM.startTimer()

        // Start voice input if enabled
        if voiceToggle {
            startVoiceInput()
        }

        // Prefetch suspense dialogue
        avatarVM.prefetchDialogue(Dialogue.suspense(selectedText: "", elapsed: nil))
    }

    private func startVoiceInput() {
        guard speechService.isAuthorized else { return }

        // Set up transcript handler for answer matching
        speechService.onTranscript = { [weak gameVM, weak avatarVM] transcript in
            guard let gameVM, let avatarVM else { return }
            guard avatarVM.gamePhase == .waitingForAnswer else { return }
            guard !gameVM.answerRevealed else { return }

            // Show user transcript
            avatarVM.userTranscript = transcript
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if avatarVM.userTranscript == transcript {
                    avatarVM.userTranscript = ""
                }
            }

            // Get answer options for current question
            guard let question = gameVM.currentQuestion else { return }
            let options = getAnswerOptions(for: question)
            guard !options.isEmpty else { return }

            // Match answer
            Task {
                if let match = await SpeechService.shared.matchAnswer(transcript: transcript, options: options) {
                    // Find if this is the correct answer
                    let correct = getCorrectAnswer(for: question)
                    let isCorrect = match.lowercased() == correct.lowercased()
                    let fact = question.data.interestingFact ?? question.interestingFact ?? ""

                    // Stop listening during answer processing
                    SpeechService.shared.stopListening()

                    // Process the answer
                    await MainActor.run {
                        handleAnswer(isCorrect: isCorrect, fact: fact, options: FinishQuestionOptions())
                    }
                }
            }
        }

        speechService.startListening()
    }

    private func stopVoiceInput() {
        speechService.stopListening()
        speechService.onTranscript = nil
    }

    // MARK: - Answer Option Extraction

    private func getAnswerOptions(for question: Question) -> [String] {
        switch question.type {
        case .fourOptions:
            return [question.data.optionA, question.data.optionB, question.data.optionC, question.data.optionD]
                .compactMap { $0 }.filter { !$0.isEmpty }
        case .whichIs:
            return [question.data.option1 ?? question.data.optionA,
                    question.data.option2 ?? question.data.optionB]
                .compactMap { $0 }.filter { !$0.isEmpty }
        case .beforeAfterBinary:
            return ["Before", "After"]
        case .oddOneOut:
            return [question.data.option1, question.data.option2, question.data.option3, question.data.option4]
                .compactMap { $0 }.filter { !$0.isEmpty }
        default:
            return question.options ?? []
        }
    }

    private func getCorrectAnswer(for question: Question) -> String {
        question.data.correctOption ?? question.data.correctAnswer ?? question.answer ?? ""
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.purple)
            Text("Loading questions...")
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await gameVM.loadQuestions() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding()
    }

    // MARK: - Question View

    private func questionView(_ question: Question) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Prize indicator
                PrizeIndicator(prize: gameVM.currentPrize)

                // Question text
                Text(question.displayText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Hint banner
                if gameVM.hintVisible {
                    HintBanner(text: gameVM.hintText)
                }

                // Question renderer
                QuestionRenderer(
                    question: question,
                    gameVM: gameVM,
                    onAnswer: handleAnswer
                )
                .padding(.horizontal, 24)

                // Lifelines bar
                if !gameVM.answerRevealed {
                    LifelinesBar(
                        lifelines: gameVM.lifelines,
                        questionType: question.type,
                        onUse: { key in
                            if key == "swap" {
                                swapTopic = ""
                                showSwapDialog = true
                            } else {
                                gameVM.useLifeline(key)
                            }
                        }
                    )
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Feedback View

    private func feedbackView(_ feedback: FeedbackData) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Result icon
            Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(feedback.isCorrect ? .green : .red)

            // Prize won
            if feedback.totalPrize > 0 {
                VStack(spacing: 4) {
                    Text(formatMoney(feedback.totalPrize))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    if feedback.speedBonus > 0 || feedback.streakBonus > 0 {
                        HStack(spacing: 8) {
                            if feedback.speedBonus > 0 {
                                BonusPill(label: "Speed", amount: feedback.speedBonus)
                            }
                            if feedback.streakBonus > 0 {
                                BonusPill(label: "Streak", amount: feedback.streakBonus)
                            }
                        }
                    }
                }
            }

            // Fact
            if !feedback.fact.isEmpty {
                Text(feedback.fact)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Total winnings
            VStack(spacing: 4) {
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Text(formatMoney(gameVM.totalWinnings))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Spacer()

            // Prize ladder mini
            PrizeLadderMini(
                results: gameVM.results,
                currentQ: gameVM.currentQ
            )

            // Next / Results button
            Button {
                Task { await advanceToNext() }
            } label: {
                Text(gameVM.isLastQuestion ? "See Results" : "Next Question")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Answer Handler

    private func handleAnswer(isCorrect: Bool, fact: String, options: FinishQuestionOptions) {
        // Stop voice input during answer processing
        stopVoiceInput()

        gameVM.revealAnswer()
        let result = gameVM.finishQuestion(isCorrect: isCorrect, fact: fact, options: options)

        // Run the avatar reaction flow
        Task {
            // Suspense
            await avatarVM.playSuspense(
                selectedText: "",
                elapsed: result.elapsed
            )

            // Reaction with audio
            let correctAnswer = getCorrectAnswer(for: gameVM.gameData[gameVM.currentQ])
            await avatarVM.playReaction(
                isCorrect: result.isCorrect,
                fact: result.fact,
                correctAnswer: correctAnswer
            )

            // Show feedback UI
            gameVM.showFeedbackUI(data: FeedbackData(
                isCorrect: result.isCorrect,
                totalPrize: result.totalPrize,
                speedBonus: result.speedBonus,
                streakBonus: result.streakBonus,
                fact: result.fact
            ))
        }
    }

    // MARK: - Advance to Next Question

    private func advanceToNext() async {
        if gameVM.isLastQuestion {
            // Game farewell
            await avatarVM.playFarewell(wrongCount: gameVM.wrongCount)
            stopVoiceInput()
            gameVM.completeGame()
        } else {
            // Transition speech
            let lastResult = gameVM.results.last
            let nextQ = gameVM.currentQ + 1
            let nextPrize = nextQ < AppConstants.prizeLadder.count ? AppConstants.prizeLadder[nextQ] : 0

            await avatarVM.playTransition(
                totalWinnings: gameVM.totalWinnings,
                nextPrize: nextPrize,
                wasCorrect: lastResult?.correct ?? false,
                roundEarnings: lastResult?.totalPrize ?? 0,
                speedBon: lastResult?.speedBonus ?? 0,
                streakBon: lastResult?.streakBonus ?? 0
            )

            gameVM.advanceQuestion()
            gameVM.showQuestionUI()

            // Ask the next question
            await runAskQuestion()
        }
    }
}

// MARK: - Game Header

struct GameHeader: View {
    let questionNumber: Int
    let totalQuestions: Int
    let totalWinnings: Int
    @Binding var voiceEnabled: Bool
    let onExit: () -> Void

    var body: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Question counter
            Text("Q\(questionNumber)/\(totalQuestions)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()

            // Voice toggle
            Button {
                voiceEnabled.toggle()
            } label: {
                Image(systemName: voiceEnabled ? "mic.fill" : "mic.slash")
                    .font(.subheadline)
                    .foregroundColor(voiceEnabled ? .purple : .white.opacity(0.4))
            }
            .padding(.trailing, 8)

            // Winnings
            Text(formatMoney(totalWinnings))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Prize Indicator

struct PrizeIndicator: View {
    let prize: Int

    var body: some View {
        Text("Playing for \(formatMoney(prize))")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.yellow)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(20)
    }
}

// MARK: - Hint Banner

struct HintBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(12)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
}

// MARK: - Bonus Pill

struct BonusPill: View {
    let label: String
    let amount: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
            Text("+\(formatMoney(amount))")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(.green.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - Prize Ladder Mini

struct PrizeLadderMini: View {
    let results: [GameResult]
    let currentQ: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<AppConstants.prizeLadder.count, id: \.self) { i in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(dotColor(for: i))
                            .frame(width: 8, height: 8)
                        if i == currentQ {
                            Text(formatCompact(AppConstants.prizeLadder[i]))
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index < results.count {
            return results[index].correct ? .green : .red
        }
        if index == currentQ {
            return .yellow
        }
        return .white.opacity(0.2)
    }
}

// MARK: - Intro Animation

struct IntroAnimationView: View {
    let onComplete: () -> Void
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var sparkOpacity: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                        .opacity(sparkOpacity)
                        .offset(y: sparkOpacity > 0 ? CGFloat.random(in: -30...0) : 0)
                        .animation(
                            .easeOut(duration: 0.6)
                            .delay(Double(i) * 0.1),
                            value: sparkOpacity
                        )
                }
            }

            HStack(spacing: 0) {
                Text("toon")
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(.white)
                Text("TRIVIA")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.4)) {
                sparkOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                onComplete()
            }
        }
    }
}

// MARK: - Briefing View

struct BriefingView: View {
    let onComplete: () -> Void
    @State private var currentSlide = 0

    private let slides: [(icon: String, title: String, text: String)] = [
        ("questionmark.circle.fill", "15 Questions", "Answer correctly to climb the prize ladder"),
        ("timer", "Speed Matters", "Faster answers earn bigger bonuses"),
        ("flame.fill", "Build Streaks", "Consecutive correct answers multiply your score"),
        ("star.circle.fill", "Lifelines", "Use 50:50, Hint, or Swap when you're stuck"),
        ("trophy.fill", "Grand Prize", "Reach $1,000,000 to become a Trivia Champion"),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: slides[currentSlide].icon)
                    .font(.system(size: 48))
                    .foregroundColor(.purple)
                    .id(currentSlide)
                    .transition(.scale.combined(with: .opacity))

                Text(slides[currentSlide].title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(slides[currentSlide].text)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .animation(.easeInOut(duration: 0.4), value: currentSlide)

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<slides.count, id: \.self) { i in
                    Circle()
                        .fill(i == currentSlide ? Color.purple : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Button {
                if currentSlide < slides.count - 1 {
                    withAnimation { currentSlide += 1 }
                } else {
                    onComplete()
                }
            } label: {
                Text(currentSlide < slides.count - 1 ? "Next" : "Let's Play!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            Button("Skip") {
                onComplete()
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.4))
            .padding(.bottom, 24)
        }
        .onAppear { autoAdvance() }
    }

    private func autoAdvance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if currentSlide < slides.count - 1 {
                withAnimation { currentSlide += 1 }
                autoAdvance()
            }
        }
    }
}

// MARK: - Swap Dialog

struct SwapDialogView: View {
    @Binding var topic: String
    @Binding var isSwapping: Bool
    let onSwap: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "1a0533").ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title)
                    .foregroundColor(.purple)

                Text("Swap Question")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Enter a topic for your new question (optional)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                TextField("e.g. space, movies, food...", text: $topic)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)

                HStack(spacing: 16) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)

                    Button {
                        onSwap(topic)
                    } label: {
                        HStack {
                            if isSwapping {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text("Swap")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                    .disabled(isSwapping)
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 20)
        }
    }
}
