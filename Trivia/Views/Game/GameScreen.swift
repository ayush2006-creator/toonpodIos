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
                    // Header bar (winnings, Q counter, timer, exit)
                    GameHeader(
                        questionNumber: gameVM.currentQ + 1,
                        totalQuestions: gameVM.totalQuestions,
                        totalWinnings: gameVM.totalWinnings,
                        timer: String(format: "%.1fs", gameVM.elapsedTime),
                        voiceEnabled: $voiceToggle,
                        onExit: { showExitAlert = true }
                    )

                    // Large avatar panel (upper body) with floating lifelines
                    AvatarGamePanel(
                        avatarVM: avatarVM,
                        speechService: speechService,
                        lifelines: gameVM.lifelines,
                        questionType: question.type,
                        onLifeline: { key in
                            if key == "swap" {
                                swapTopic = ""
                                showSwapDialog = true
                            } else {
                                gameVM.useLifeline(key)
                            }
                        }
                    )
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.42)

                    // Question + answers below avatar
                    if gameVM.showQuestion {
                        questionView(question)
                    } else if gameVM.showFeedback, let feedback = gameVM.feedbackData {
                        feedbackView(feedback)
                    }
                }
                // Skip button overlay (bottom-right of avatar area)
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
            VStack(alignment: .leading, spacing: 16) {
                // Question text — left-aligned, large, like the web app
                Text(question.displayText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)

                // Hint banner
                if gameVM.hintVisible {
                    HintBanner(text: gameVM.hintText)
                }

                // Question renderer (answer buttons)
                QuestionRenderer(
                    question: question,
                    gameVM: gameVM,
                    onAnswer: handleAnswer
                )
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Feedback View

    private func feedbackView(_ feedback: FeedbackData) -> some View {
        FeedbackContentView(
            feedback: feedback,
            totalWinnings: gameVM.totalWinnings,
            results: gameVM.results,
            currentQ: gameVM.currentQ,
            isLastQuestion: gameVM.isLastQuestion,
            onNext: { Task { await advanceToNext() } }
        )
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

// MARK: - Game Header (web-style: WINNINGS + progress | Q counter | timer | exit)

struct GameHeader: View {
    let questionNumber: Int
    let totalQuestions: Int
    let totalWinnings: Int
    var timer: String = ""
    @Binding var voiceEnabled: Bool
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center) {
                // Left: WINNINGS label + amount
                VStack(alignment: .leading, spacing: 1) {
                    Text("WINNINGS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1)
                    Text(formatMoney(totalWinnings))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.yellow)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(0, geo.size.width * CGFloat(questionNumber) / CGFloat(max(totalQuestions, 1))),
                                height: 4
                            )
                            .animation(.easeInOut(duration: 0.4), value: questionNumber)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 8)

                Spacer()

                // Center: Q counter
                Text("Q\(questionNumber) / \(totalQuestions)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // Timer
                if !timer.isEmpty {
                    Text(timer)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                }

                // Voice toggle
                Button {
                    voiceEnabled.toggle()
                } label: {
                    Image(systemName: voiceEnabled ? "mic.fill" : "mic.slash")
                        .font(.system(size: 14))
                        .foregroundColor(voiceEnabled ? .purple : .white.opacity(0.3))
                }
                .padding(.leading, 6)

                // Exit button
                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.4))
    }

    private var timerColor: Color {
        // Parse timer string to check urgency
        if let val = Double(timer.replacingOccurrences(of: "s", with: "")), val <= 5 {
            return .red
        }
        return .green
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

// MARK: - Intro Animation (web-style: bouncy zoom-in + radial sparks + shimmer)

struct IntroAnimationView: View {
    let onComplete: () -> Void
    @State private var scale: CGFloat = 0.15
    @State private var opacity: Double = 0
    @State private var sparksLaunched = false
    @State private var shimmer = false
    @State private var fadeOut = false

    // 6 radial spark directions matching web's introSparkOut
    private let sparkDirections: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (-60, -50, .yellow),
        (65, -45, .purple),
        (-45, -70, .pink),
        (50, -65, .purple.opacity(0.7)),
        (-70, -30, .yellow.opacity(0.8)),
        (60, -55, .pink.opacity(0.8)),
    ]

    var body: some View {
        ZStack {
            // Radial sparks
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(sparkDirections[i].color)
                    .frame(width: 8, height: 8)
                    .blur(radius: 1)
                    .offset(
                        x: sparksLaunched ? sparkDirections[i].x : 0,
                        y: sparksLaunched ? sparkDirections[i].y : 0
                    )
                    .opacity(sparksLaunched ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.7)
                        .delay(0.3 + Double(i) * 0.05),
                        value: sparksLaunched
                    )
            }

            VStack(spacing: 4) {
                // Subtitle shimmer
                Text("party HOST")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(6)
                    .foregroundColor(.white.opacity(shimmer ? 0.8 : 0.4))
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: shimmer
                    )
                    .opacity(opacity)

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
                // Bouncy cubic-bezier zoom: 0.15 → 1.15 → 0.95 → 1.0
                .scaleEffect(scale)
                .opacity(opacity)
            }
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear {
            // Phase 1: Bouncy zoom in (matches web's introZoomIn)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6, blendDuration: 0.1)) {
                scale = 1.0
                opacity = 1.0
            }

            // Phase 2: Launch sparks
            withAnimation(.easeIn(duration: 0.1).delay(0.3)) {
                sparksLaunched = true
            }

            // Phase 3: Shimmer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                shimmer = true
            }

            // Phase 4: Fade out and complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeIn(duration: 0.4)) {
                    fadeOut = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                onComplete()
            }
        }
    }
}

// MARK: - Briefing View (web-style slide carousel with lifeline pop & auto-advance)

struct BriefingView: View {
    let onComplete: () -> Void
    @State private var currentSlide = 0
    @State private var slideDirection: Edge = .trailing

    private let slides: [(icon: String, title: String, text: String, color: Color)] = [
        ("questionmark.circle.fill", "15 Questions", "Answer correctly to climb the prize ladder", .purple),
        ("timer", "Speed Matters", "Faster answers earn bigger bonuses", .blue),
        ("flame.fill", "Build Streaks", "Consecutive correct answers multiply your score", .orange),
        ("star.circle.fill", "Lifelines", "Use 50:50, Hint, or Swap when you're stuck", .yellow),
        ("trophy.fill", "Grand Prize", "Reach $1,000,000 to become a Trivia Champion", .green),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Slide content with direction-aware transition
            VStack(spacing: 20) {
                // Icon with bounce-pop (web's briefLlPop cubic-bezier)
                Image(systemName: slides[currentSlide].icon)
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [slides[currentSlide].color, slides[currentSlide].color.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: slides[currentSlide].color.opacity(0.4), radius: 12)
                    .id("icon-\(currentSlide)")
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.92).combined(with: .opacity)
                    ))

                Text(slides[currentSlide].title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .id("title-\(currentSlide)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))

                Text(slides[currentSlide].text)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .id("text-\(currentSlide)")
                    .transition(.opacity)

                // Lifeline highlights on slide 3
                if currentSlide == 3 {
                    LifelineHighlights()
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: currentSlide)

            Spacer()

            // Progress dots with animated fill
            HStack(spacing: 8) {
                ForEach(0..<slides.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentSlide ? slides[i].color : Color.white.opacity(0.3))
                        .frame(width: i == currentSlide ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentSlide)
                }
            }

            Button {
                if currentSlide < slides.count - 1 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        currentSlide += 1
                    }
                } else {
                    onComplete()
                }
            } label: {
                Text(currentSlide < slides.count - 1 ? "Next" : "Let's Play!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [slides[currentSlide].color, slides[currentSlide].color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: slides[currentSlide].color.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.3), value: currentSlide)

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if currentSlide < slides.count - 1 {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    currentSlide += 1
                }
                autoAdvance()
            }
        }
    }
}

// MARK: - Lifeline Highlights (web-style sequential pop with glow)

struct LifelineHighlights: View {
    @State private var activeLifeline = -1

    private let lifelines: [(icon: String, name: String, color: Color)] = [
        ("circle.lefthalf.filled", "50:50", .yellow),
        ("lightbulb.fill", "Hint", .cyan),
        ("arrow.triangle.2.circlepath", "Swap", .purple),
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<lifelines.count, id: \.self) { i in
                VStack(spacing: 6) {
                    Image(systemName: lifelines[i].icon)
                        .font(.title3)
                        .foregroundColor(i == activeLifeline ? lifelines[i].color : .white.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(i == activeLifeline
                                      ? lifelines[i].color.opacity(0.2)
                                      : Color.white.opacity(0.05))
                        )
                        .overlay(
                            Circle()
                                .stroke(i == activeLifeline ? lifelines[i].color.opacity(0.6) : .clear, lineWidth: 1.5)
                        )
                        .shadow(color: i == activeLifeline ? lifelines[i].color.opacity(0.5) : .clear, radius: 8)
                        // Web's briefLlPop: scale bounce
                        .scaleEffect(i == activeLifeline ? 1.18 : (i < activeLifeline ? 0.92 : 1.0))
                        .opacity(i < activeLifeline ? 0.4 : 1.0)

                    Text(lifelines[i].name)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(i == activeLifeline ? .white : .white.opacity(0.4))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: activeLifeline)
            }
        }
        .onAppear { cycleLifelines() }
    }

    private func cycleLifelines() {
        for i in 0..<lifelines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8 + 0.3) {
                activeLifeline = i
            }
        }
        // Reset after cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(lifelines.count) * 0.8 + 0.5) {
            activeLifeline = -1
        }
    }
}

// MARK: - Feedback Content View (staggered entrance animations)

struct FeedbackContentView: View {
    let feedback: FeedbackData
    let totalWinnings: Int
    let results: [GameResult]
    let currentQ: Int
    let isLastQuestion: Bool
    let onNext: () -> Void

    @State private var showIcon = false
    @State private var showPrize = false
    @State private var showFact = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Result icon with bounce-in
            Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(feedback.isCorrect ? .green : .red)
                .shadow(color: (feedback.isCorrect ? Color.green : .red).opacity(0.4), radius: 16)
                .scaleEffect(showIcon ? 1.0 : 0.3)
                .opacity(showIcon ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showIcon)

            // Prize won
            if feedback.totalPrize > 0 {
                VStack(spacing: 4) {
                    Text(formatMoney(feedback.totalPrize))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.3), radius: 8)

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
                .scaleEffect(showPrize ? 1.0 : 0.8)
                .opacity(showPrize ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.15), value: showPrize)
            }

            // Fact
            if !feedback.fact.isEmpty {
                Text(feedback.fact)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showFact ? 1 : 0)
                    .offset(y: showFact ? 0 : 15)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: showFact)
            }

            // Total winnings
            VStack(spacing: 4) {
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Text(formatMoney(totalWinnings))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .opacity(showFact ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.4), value: showFact)

            Spacer()

            PrizeLadderMini(results: results, currentQ: currentQ)

            Button(action: onNext) {
                Text(isLastQuestion ? "See Results" : "Next Question")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .cornerRadius(12)
                    .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
            .animation(.easeOut(duration: 0.35).delay(0.5), value: showButton)
        }
        .onAppear {
            showIcon = true
            showPrize = true
            showFact = true
            showButton = true
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
