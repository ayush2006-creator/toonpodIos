import SwiftUI

// MARK: - Party Game Screen

struct PartyGameScreen: View {
    @EnvironmentObject var gameVM: GameViewModel
    @EnvironmentObject var partyVM: PartyViewModel
    @EnvironmentObject var avatarVM: AvatarViewModel
    @StateObject private var speechService = SpeechService.shared
    @StateObject private var faceDetector = CameraFaceDetector()

    // Registration phase
    @State private var registrationComplete = false
    @State private var registeringPlayerIndex = 0
    @State private var pendingName = ""
    @State private var awaitingConfirm = false
    @State private var detectedFaceRect: CGRect? = nil

    // Game phase
    @State private var showBuzzIn = false
    @State private var showRoundCard = false
    @State private var pendingRound: PartyRound? = nil
    @State private var isMatchingAnswer = false
    @State private var navigateToResults = false
    @State private var showExitAlert = false

    // Special rounds
    @State private var showAuction = false
    @State private var showWager = false
    @State private var showSteal = false
    @State private var showHotSeat = false
    @State private var showGridReveal = false

    // Buzz flow continuation
    private let buzzWords = ["mine", "buzz", "bus", "me", "here", "buzzer"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1a0533"), Color(hex: "0d001a")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if !registrationComplete {
                registrationView
            } else {
                gameView
            }

            // Special round overlays
            if showAuction {
                AuctionOverlay { winner, bid in
                    partyVM.deductScore(winner, bid)
                    partyVM.partySpeaker = winner
                    showAuction = false
                    partyVM.auctionState = nil
                    Task { await startBuzzForAnswer(exclusive: winner) }
                }
                .environmentObject(partyVM)
                .transition(.opacity)
            }

            if showWager {
                WagerOverlay {
                    showWager = false
                    Task { await startBuzzForAnswer(exclusive: nil) }
                }
                .environmentObject(partyVM)
                .transition(.opacity)
            }

            if showSteal {
                StealOverlay {
                    showSteal = false
                    partyVM.stealState = nil
                    partyVM.activeSpecialRound = nil
                }
                .environmentObject(partyVM)
                .transition(.opacity)
            }

            if showHotSeat {
                HotSeatOverlay { isCorrect in
                    showHotSeat = false
                    partyVM.hotSeatState = nil
                    if isCorrect {
                        // Trigger grid reveal
                        let player = partyVM.partySpeaker ?? partyVM.players.first?.name ?? ""
                        partyVM.gridRevealState = GridRevealState(
                            player: player,
                            cells: partyVM.buildGridCells(ladderPrize: currentPrize)
                        )
                        withAnimation { showGridReveal = true }
                    } else {
                        partyVM.activeSpecialRound = nil
                    }
                }
                .environmentObject(partyVM)
                .transition(.opacity)
            }

            if showGridReveal {
                GridRevealOverlay {
                    showGridReveal = false
                    partyVM.gridRevealState = nil
                    partyVM.activeSpecialRound = nil
                    Task { await advanceToNext() }
                }
                .environmentObject(partyVM)
                .transition(.opacity)
            }

            // Round title card
            if showRoundCard, let round = pendingRound {
                RoundTitleCard(round: round) {
                    withAnimation { showRoundCard = false }
                    pendingRound = nil
                }
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToResults) {
            ResultsScreen()
        }
        .alert("Exit Party?", isPresented: $showExitAlert) {
            Button("Continue", role: .cancel) { }
            Button("Exit", role: .destructive) {
                speechService.stopListening()
                avatarVM.stopSpeaking()
                gameVM.gameAborted = true
            }
        } message: {
            Text("All progress will be lost.")
        }
        .task {
            if let avatar = appAvatars.first(where: { $0.id == gameVM.selectedAvatarId }) {
                avatarVM.selectAvatar(avatar)
            }
            gameVM.resetGame(level: gameVM.currentLevel)
            await gameVM.loadQuestions()
            speechService.requestAuthorization()

            if partyVM.registrationPhase {
                await runCameraRegistration()
            } else {
                registrationComplete = true
                await runPartyFlow()
            }
        }
    }

    // MARK: - Registration View

    private var registrationView: some View {
        ZStack {
            // Camera feed or dark fallback
            if let layer = faceDetector.previewLayer {
                CameraPreviewView(layer: layer)
                    .ignoresSafeArea()
            } else {
                Color(hex: "1a0533").ignoresSafeArea()
            }

            // Face bounding box + floating name label
            GeometryReader { geo in
                if let faceRect = detectedFaceRect {
                    let px = CGRect(
                        x: faceRect.origin.x * geo.size.width,
                        y: faceRect.origin.y * geo.size.height,
                        width: faceRect.width * geo.size.width,
                        height: faceRect.height * geo.size.height
                    )

                    Rectangle()
                        .strokeBorder(Color.green, lineWidth: 2)
                        .frame(width: px.width, height: px.height)
                        .position(x: px.midX, y: px.midY)
                        .animation(.easeOut(duration: 0.1), value: faceRect)

                    let label = pendingName.isEmpty
                        ? "Player \(registeringPlayerIndex + 1)"
                        : pendingName
                    let labelColor: Color = pendingName.isEmpty ? .green : .yellow

                    Text(label)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(labelColor)
                        .cornerRadius(8)
                        .position(x: px.midX, y: max(px.minY - 24, 24))
                        .animation(.easeOut(duration: 0.1), value: faceRect)
                }
            }

            // Bottom HUD
            VStack {
                Spacer()
                registrationHUD
            }
        }
    }

    private var registrationHUD: some View {
        VStack(spacing: 10) {
            Text("Player \(registeringPlayerIndex + 1) of \(partyVM.targetPlayerCount)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            if !pendingName.isEmpty {
                Text("I heard: \"\(pendingName)\"")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }

            if !partyVM.registeredNames.isEmpty {
                HStack(spacing: 14) {
                    ForEach(Array(partyVM.registeredNames.enumerated()), id: \.offset) { i, name in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(PartyViewModel.playerColors[i % 6])
                                .frame(width: 8, height: 8)
                            Text(name)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(PartyViewModel.playerColors[i % 6])
                        }
                    }
                }
            }

            if speechService.isListening {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 14))
                    Text(speechService.transcript.isEmpty ? "Listening..." : speechService.transcript)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Game View

    @ViewBuilder
    private var gameView: some View {
        if gameVM.isLoading {
            ProgressView().tint(.purple)
        } else if let error = gameVM.errorMessage {
            Text(error).foregroundColor(.red)
        } else if gameVM.gameComplete {
            Color.clear.onAppear { navigateToResults = true }
        } else if let question = gameVM.currentQuestion {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { showExitAlert = true } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.title3)
                    }
                    Spacer()
                    Text("Q\(gameVM.currentQ + 1) / \(gameVM.totalQuestions)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(String(format: "%.1fs", gameVM.elapsedTime))
                        .font(.caption)
                        .foregroundColor(.purple)
                        .monospacedDigit()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                // Scoreboard
                PartyScoreboardView()
                    .environmentObject(partyVM)

                // Avatar
                AvatarGamePanel(
                    avatarVM: avatarVM,
                    speechService: speechService,
                    lifelines: partyVM.partySpeaker.flatMap { partyVM.partyLifelines[$0] } ?? Lifelines(),
                    questionType: question.type,
                    onLifeline: { key in
                        if let speaker = partyVM.partySpeaker {
                            switch key {
                            case "fiftyFifty": partyVM.partyLifelines[speaker]?.fiftyFifty = false
                            case "hint":       partyVM.partyLifelines[speaker]?.hint = false
                            default: break
                            }
                        }
                        gameVM.useLifeline(key)
                    }
                )
                .frame(maxHeight: UIScreen.main.bounds.height * 0.36)

                // Current speaker badge
                if let speaker = partyVM.partySpeaker {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(partyVM.color(for: speaker))
                            .frame(width: 8, height: 8)
                        Text("\(speaker) is answering")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                    .padding(.top, 4)
                }

                // Question + answers
                if gameVM.showQuestion && !showBuzzIn {
                    questionView(question)
                } else if gameVM.showFeedback, let feedback = gameVM.feedbackData {
                    FeedbackContentView(
                        feedback: feedback,
                        totalWinnings: partyVM.sortedPlayers.first?.score ?? 0,
                        results: gameVM.results,
                        currentQ: gameVM.currentQ,
                        isLastQuestion: gameVM.isLastQuestion,
                        onNext: { Task { await advanceToNext() } }
                    )
                }

                // Buzz-in overlay (inline, not full-screen)
                if showBuzzIn {
                    BuzzInOverlay(
                        eligiblePlayers: partyVM.eligiblePlayers(),
                        onPlayerIdentified: { name in
                            partyVM.partySpeaker = name
                            partyVM.buzzDetected = false
                            showBuzzIn = false
                            startVoiceForAnswer()
                        },
                        onTimeout: {
                            // Show question for tap
                            showBuzzIn = false
                        }
                    )
                    .environmentObject(partyVM)
                    .frame(maxHeight: 320)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Question View

    private func questionView(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(question.displayText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)

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

    // MARK: - Camera Registration Flow

    private func runCameraRegistration() async {
        faceDetector.requestPermissionAndStart()
        await avatarVM.speakAloud("Welcome to Party Mode! Step up one at a time to register.")
        await registerNextFacePlayer()
    }

    private func waitForFaceDetection() async -> CGRect {
        return await withCheckedContinuation { continuation in
            var resumed = false
            faceDetector.onFaceStabilized = { rect in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: rect)
            }
        }
    }

    private func registerNextFacePlayer() async {
        guard registeringPlayerIndex < partyVM.targetPlayerCount else {
            faceDetector.stopSession()
            partyVM.initPlayers(partyVM.registeredNames)
            registrationComplete = true
            await runPartyFlow()
            return
        }

        await avatarVM.speakAloud("Player \(registeringPlayerIndex + 1), step in front of the camera.")
        let faceRect = await waitForFaceDetection()
        detectedFaceRect = faceRect

        await avatarVM.speakAloud("I see you! Say your name.")
        let name = await captureVoiceName()
        pendingName = name

        await avatarVM.speakAloud("I heard \(name). Say yes to confirm or no to try again.")
        let confirmed = await captureYesNo()

        if confirmed {
            partyVM.registeredNames.append(name)
            registeringPlayerIndex += 1
        }
        detectedFaceRect = nil
        pendingName = ""
        faceDetector.resetRefireTimer()
        await registerNextFacePlayer()
    }

    private func captureVoiceName() async -> String {
        return await withCheckedContinuation { continuation in
            var resumed = false
            speechService.onTranscript = { transcript in
                guard !resumed, !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                resumed = true
                speechService.stopListening()
                continuation.resume(returning: transcript.trimmingCharacters(in: .whitespaces).capitalized)
            }
            speechService.startListening()
        }
    }

    private func captureYesNo() async -> Bool {
        return await withCheckedContinuation { continuation in
            var resumed = false
            speechService.onTranscript = { transcript in
                guard !resumed else { return }
                let lower = transcript.lowercased()
                if lower.contains("yes") || lower.contains("yeah") || lower.contains("correct") || lower.contains("right") {
                    resumed = true
                    speechService.stopListening()
                    continuation.resume(returning: true)
                } else if lower.contains("no") || lower.contains("nope") || lower.contains("wrong") {
                    resumed = true
                    speechService.stopListening()
                    continuation.resume(returning: false)
                }
            }
            speechService.startListening()
        }
    }

    // MARK: - Party Game Flow

    private func runPartyFlow() async {
        guard !gameVM.gameData.isEmpty else { return }
        await avatarVM.runBriefing(playerName: nil)
        await runPartyQuestion()
    }

    private func runPartyQuestion() async {
        guard let question = gameVM.currentQuestion else { return }

        // Check round transition
        if let newRound = partyVM.checkRoundTransition(questionIndex: gameVM.currentQ) {
            pendingRound = newRound
            withAnimation { showRoundCard = true }
            // Wait for card to dismiss
            while showRoundCard { try? await Task.sleep(nanoseconds: 100_000_000) }
        }

        // Check special round before question
        if let specialStr = AppConstants.partySpecialRounds[gameVM.currentQ] {
            await runPreQuestionSpecial(specialStr, question: question)
        }

        partyVM.clearWrongPlayers()
        partyVM.clearSkipFlags()

        // Pre-warm embeddings
        let opts = getAnswerOptions(for: question)
        if !opts.isEmpty { APIService.shared.precomputeEmbeddings(options: opts) }

        // Avatar asks question
        await avatarVM.askQuestion(question, number: gameVM.currentQ + 1, prize: currentPrize)
        gameVM.startTimer()

        // Start buzz-in
        await startBuzzForAnswer(exclusive: nil)
    }

    private func runPreQuestionSpecial(_ type: String, question: Question) async {
        switch type {
        case "auction":
            partyVM.auctionState = AuctionState()
            withAnimation { showAuction = true }
            await avatarVM.speakAloud("Auction time! Players, buzz in and bid to answer this question exclusively.")
            await runAuctionBidding()
        case "wager":
            partyVM.wagerAmounts = [:]
            withAnimation { showWager = true }
            await avatarVM.speakAloud("Wager round! Buzz in and tell me how much you want to wager.")
            await runWageringPhase()
        default: break
        }
    }

    // MARK: - Auction Logic

    private func runAuctionBidding() async {
        let maxRounds = 6
        var currentHigh = 0

        for _ in 0..<maxRounds {
            let bidder = await waitForBuzz(timeoutSeconds: 10)
            guard let bidder else { break }

            await avatarVM.speakAloud("\(bidder), what's your bid?")
            if let bid = await captureMoneyAmount(maxAmount: partyVM.partyScores[bidder] ?? 0) {
                if bid > currentHigh {
                    currentHigh = bid
                    partyVM.auctionState?.bids[bidder] = bid
                    await avatarVM.speakAloud("\(bidder) bids \(formatMoney(bid))!")
                } else {
                    await avatarVM.speakAloud("Bid must be higher than \(formatMoney(currentHigh)).")
                }
            }
        }

        // Closing phase
        partyVM.auctionState?.phase = .closing
        try? await Task.sleep(nanoseconds: 4_000_000_000) // 4s for closing animation
        partyVM.auctionState?.phase = .sold
    }

    // MARK: - Wager Logic

    private func runWageringPhase() async {
        for player in partyVM.players {
            await avatarVM.speakAloud("\(player.name), how much do you wager?")
            let max = partyVM.partyScores[player.name] ?? 0
            if let amount = await captureMoneyAmount(maxAmount: max) {
                partyVM.wagerAmounts[player.name] = amount
            }
        }
    }

    // MARK: - Buzz-In Flow

    private func startBuzzForAnswer(exclusive: String?) async {
        if let exclusive {
            partyVM.partySpeaker = exclusive
            startVoiceForAnswer()
            return
        }

        partyVM.buzzDetected = false
        withAnimation { showBuzzIn = true }
        await listenForBuzzKeyword()
    }

    private func listenForBuzzKeyword() async {
        return await withCheckedContinuation { continuation in
            var resumed = false
            speechService.onTranscript = { transcript in
                guard !resumed else { return }
                let lower = transcript.lowercased()
                if self.buzzWords.contains(where: { lower.contains($0) }) {
                    resumed = true
                    // Immediately show "Who buzzed?" picker in overlay
                    DispatchQueue.main.async { self.partyVM.buzzDetected = true }
                    continuation.resume()
                }
            }
            speechService.startListening()
        }
    }

    private func startVoiceForAnswer() {
        speechService.onTranscript = { transcript in
            guard !self.isMatchingAnswer else { return }
            guard let question = self.gameVM.currentQuestion else { return }

            let options = self.getAnswerOptions(for: question)
            guard !options.isEmpty else { return }

            self.isMatchingAnswer = true
            Task {
                defer { self.isMatchingAnswer = false }
                if let match = await SpeechService.shared.matchAnswer(transcript: transcript, options: options) {
                    guard !self.gameVM.answerRevealed else { return }
                    let isCorrect = self.isAnswerCorrect(match: match, question: question)
                    let fact = question.data.interestingFact ?? ""
                    SpeechService.shared.stopListening()
                    await MainActor.run {
                        self.gameVM.voiceSelectedAnswer = match
                        self.handleAnswer(isCorrect: isCorrect, fact: fact,
                                          options: FinishQuestionOptions(selectedText: match))
                    }
                }
            }
        }
        speechService.startListening()
    }

    // MARK: - Answer Handler

    private func handleAnswer(isCorrect: Bool, fact: String, options: FinishQuestionOptions) {
        speechService.stopListening()
        speechService.onTranscript = nil
        isMatchingAnswer = false
        showBuzzIn = false

        let speaker = partyVM.partySpeaker ?? ""
        let prize = partyVM.applyMultiplier(to: currentPrize)

        gameVM.revealAnswer()
        let result = gameVM.finishQuestion(isCorrect: isCorrect, fact: fact, options: options)

        // Party scoring
        if isCorrect {
            partyVM.addScore(speaker, prize)
            partyVM.recordCorrect(speaker)

            // Settle wagers
            if !partyVM.wagerAmounts.isEmpty {
                for (name, wager) in partyVM.wagerAmounts {
                    partyVM.addScore(name, wager)
                }
                partyVM.wagerAmounts = [:]
            }
        } else {
            partyVM.recordWrong(speaker)
            partyVM.addWrongPlayer(speaker)

            // Settle wagers (deduct)
            if !partyVM.wagerAmounts.isEmpty {
                for (name, wager) in partyVM.wagerAmounts {
                    partyVM.deductScore(name, wager)
                }
                partyVM.wagerAmounts = [:]
            }

            // Check pass: non-binary type, other eligible players exist
            let isBinary = AppConstants.binaryQuestionTypes.contains(gameVM.currentQuestion?.type ?? .fourOptions)
            let eligible = partyVM.eligiblePlayers()
            if !isBinary && !eligible.isEmpty {
                Task { await runPassAttempt() }
                return
            }
        }

        // Check steal trigger after correct answer
        if isCorrect, let thief = partyVM.checkStealTrigger() {
            Task {
                await runSteelRound(thief: thief)
            }
            return
        }

        // Check hot seat trigger (closest_number / hidden_timer)
        let qType = gameVM.currentQuestion?.type
        if isCorrect && (qType == .closestNumber || qType == .hiddenTimer) {
            Task { await runHotSeatRound(winner: speaker) }
            return
        }

        Task {
            await avatarVM.playSuspense(selectedText: options.selectedText ?? "", elapsed: result.elapsed)
            let correctAns = gameVM.currentQuestion.map { getCorrectAnswer(for: $0) } ?? ""
            await avatarVM.playReaction(isCorrect: isCorrect, fact: result.fact, correctAnswer: correctAns)
            gameVM.showFeedbackUI(data: FeedbackData(
                isCorrect: result.isCorrect,
                totalPrize: result.totalPrize,
                speedBonus: result.speedBonus,
                streakBonus: result.streakBonus,
                fact: result.fact
            ))
        }
    }

    // MARK: - Pass Mechanics

    private func runPassAttempt() async {
        await avatarVM.speakAloud("Who else wants to try? Buzz in!")
        withAnimation { showBuzzIn = true }
        await listenForBuzzKeyword()
    }

    // MARK: - Steal Round

    private func runSteelRound(thief: String) async {
        partyVM.stealState = StealState(thief: thief)
        partyVM.activeSpecialRound = .steal
        withAnimation { showSteal = true }

        await avatarVM.speakAloud("\(thief) is on a streak! Say yes to steal or no to pass.")

        // Listen for yes/no
        let wants = await captureYesNo()
        if !wants {
            partyVM.stealState?.result = .fail
            partyVM.stealState?.phase = .result
            return
        }

        // Generate bonus question
        partyVM.stealState?.phase = .question
        do {
            let q = try await APIService.shared.generateQuestion(
                topic: "general", difficulty: 7, type: "4_options")
            partyVM.stealState?.question = q
            partyVM.stealState?.correctOption = q.data.correctOption

            await avatarVM.speakAloud(q.displayText)
            let opts = [q.data.optionA, q.data.optionB, q.data.optionC, q.data.optionD]
                .compactMap { $0 }.filter { !$0.isEmpty }

            // Listen for answer
            if let match = await captureVoiceMatch(against: opts, attempts: 2) {
                let correct = match.lowercased() == (q.data.correctOption ?? "").lowercased()
                if correct {
                    partyVM.stealState?.phase = .target
                    await avatarVM.speakAloud("Correct! \(thief), who do you steal from? Say a name.")
                    // Target selection handled by StealOverlay taps
                } else {
                    // Fail: transfer 25% to underdog
                    let thiefsScore = partyVM.partyScores[thief] ?? 0
                    let penalty = thiefsScore / 4
                    if let underdog = partyVM.lowestScoringPlayer, underdog != thief {
                        partyVM.transferScore(from: thief, to: underdog, amount: penalty)
                        partyVM.stealState?.amount = penalty
                    }
                    partyVM.partyStreaks[thief] = 0
                    partyVM.stealState?.result = .fail
                    partyVM.stealState?.phase = .result
                }
            }
        } catch {
            showSteal = false
            partyVM.stealState = nil
        }
    }

    // MARK: - Hot Seat Round

    private func runHotSeatRound(winner: String) async {
        partyVM.hotSeatState = HotSeatState(player: winner)
        partyVM.activeSpecialRound = .hotSeat
        withAnimation { showHotSeat = true }

        await avatarVM.speakAloud("\(winner) is in the HOT SEAT! Others, say an amount to sabotage!")
        partyVM.hotSeatState?.phase = .sabotage

        // Collect sabotage for 8s
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        let pool = partyVM.hotSeatState?.sabotage.values.reduce(0, +) ?? 0

        // Calculate difficulty
        let baseDiff = 5
        let sabotageBonus = min(3, pool / 2000)
        let difficulty = min(10, baseDiff + sabotageBonus)

        partyVM.hotSeatState?.phase = .loading
        await avatarVM.speakAloud("Generating a difficulty \(difficulty) question...")

        do {
            let q = try await APIService.shared.generateQuestion(
                topic: "general", difficulty: difficulty, type: "4_options")
            partyVM.hotSeatState?.questionText = q.displayText
            partyVM.hotSeatState?.options = [q.data.optionA, q.data.optionB, q.data.optionC, q.data.optionD]
                .compactMap { $0 }.filter { !$0.isEmpty }
            partyVM.hotSeatState?.correctOption = q.data.correctOption
            partyVM.hotSeatState?.phase = .question

            await avatarVM.speakAloud(q.displayText)
            let opts = partyVM.hotSeatState?.options ?? []
            if let match = await captureVoiceMatch(against: opts, attempts: 2) {
                partyVM.hotSeatState?.playerAnswer = match
                let isCorrect = match.lowercased() == (q.data.correctOption ?? "").lowercased()
                partyVM.hotSeatState?.isCorrect = isCorrect
                partyVM.hotSeatState?.phase = .result
            }
        } catch {
            showHotSeat = false
            partyVM.hotSeatState = nil
            await advanceToNext()
        }
    }

    // MARK: - Advance to Next Question

    private func advanceToNext() async {
        if gameVM.isLastQuestion {
            await avatarVM.playFarewell(wrongCount: gameVM.wrongCount)
            gameVM.completeGame()
        } else {
            partyVM.partySpeaker = nil
            partyVM.activeSpecialRound = nil
            partyVM.clearWrongPlayers()
            gameVM.voiceSelectedAnswer = nil

            let lastResult = gameVM.results.last
            let nextQ = gameVM.currentQ + 1
            let nextPrize = nextQ < AppConstants.partyPrizeLadder.count
                ? AppConstants.partyPrizeLadder[nextQ] : currentPrize
            await avatarVM.playTransition(
                totalWinnings: partyVM.sortedPlayers.first?.score ?? 0,
                nextPrize: nextPrize,
                wasCorrect: lastResult?.correct ?? false,
                roundEarnings: lastResult?.totalPrize ?? 0,
                speedBon: lastResult?.speedBonus ?? 0,
                streakBon: lastResult?.streakBonus ?? 0
            )
            gameVM.advanceQuestion()
            gameVM.showQuestionUI()
            await runPartyQuestion()
        }
    }

    // MARK: - Voice Capture Helpers

    private func waitForBuzz(timeoutSeconds: Int) async -> String? {
        return await withCheckedContinuation { continuation in
            var resumed = false
            let timeout = DispatchWorkItem {
                guard !resumed else { return }
                resumed = true
                speechService.stopListening()
                continuation.resume(returning: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeoutSeconds), execute: timeout)

            speechService.onTranscript = { transcript in
                guard !resumed else { return }
                let lower = transcript.lowercased()
                if self.buzzWords.contains(where: { lower.contains($0) }) {
                    timeout.cancel()
                    resumed = true
                    speechService.stopListening()
                    continuation.resume(returning: partyVM.eligiblePlayers().first)
                }
            }
            speechService.startListening()
        }
    }

    private func captureMoneyAmount(maxAmount: Int) async -> Int? {
        return await withCheckedContinuation { continuation in
            var resumed = false
            speechService.onTranscript = { transcript in
                guard !resumed else { return }
                if let amount = parseMoneyAmount(transcript, max: maxAmount) {
                    resumed = true
                    speechService.stopListening()
                    continuation.resume(returning: amount)
                }
            }
            // Timeout after 8s
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if !resumed {
                    resumed = true
                    speechService.stopListening()
                    continuation.resume(returning: nil)
                }
            }
            speechService.startListening()
        }
    }

    private func captureVoiceMatch(against options: [String], attempts: Int) async -> String? {
        for _ in 0..<attempts {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                var resumed = false
                let timeout = DispatchWorkItem {
                    guard !resumed else { return }
                    resumed = true
                    speechService.stopListening()
                    continuation.resume(returning: nil)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)

                speechService.onTranscript = { transcript in
                    guard !resumed else { return }
                    Task {
                        if let match = await SpeechService.shared.matchAnswer(
                            transcript: transcript, options: options) {
                            timeout.cancel()
                            resumed = true
                            speechService.stopListening()
                            continuation.resume(returning: match)
                        }
                    }
                }
                speechService.startListening()
            }
            if let r = result { return r }
        }
        return nil
    }

    // MARK: - Money Parsing

    private func parseMoneyAmount(_ transcript: String, max: Int) -> Int? {
        let lower = transcript.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        if lower.contains("all in") || lower.contains("everything") { return max }
        if lower.contains("nothing") || lower.contains("zero") || lower.contains("pass") { return 0 }

        // e.g. "5k", "5000", "five thousand"
        let wordMap: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
            "hundred": 100, "thousand": 1000, "k": 1000, "grand": 1000,
        ]
        var value = 0
        for (word, num) in wordMap {
            if lower.contains(word) { value += num }
        }
        if value > 0 { return min(value, max) }

        // Numeric
        let digits = lower.components(separatedBy: .whitespaces).compactMap { part -> Int? in
            let cleaned = part.replacingOccurrences(of: "k", with: "000")
            return Int(cleaned)
        }.first
        return digits.map { min($0, max) }
    }

    // MARK: - Correctness Helpers (mirrors GameScreen)

    private var currentPrize: Int {
        let idx = gameVM.currentQ
        let ladder = AppConstants.partyPrizeLadder
        return idx < ladder.count ? ladder[idx] : ladder.last ?? 100_000
    }

    private func getAnswerOptions(for question: Question) -> [String] {
        switch question.type {
        case .fourOptions, .pictureChoice:
            return [question.data.optionA, question.data.optionB,
                    question.data.optionC, question.data.optionD]
                .compactMap { $0 }.filter { !$0.isEmpty }
        case .whichIs:
            let fromFields = [question.data.optionA, question.data.optionB]
                .compactMap { $0 }.filter { !$0.isEmpty }
            if fromFields.count == 2 { return fromFields }
            return question.data.whichIsOptionsFromQuery
        case .beforeAfterBinary:
            return ["Before", "After"]
        case .oddOneOut:
            return [question.data.option1, question.data.option2,
                    question.data.option3, question.data.option4]
                .compactMap { $0 }.filter { !$0.isEmpty }
        default:
            return question.options ?? []
        }
    }

    private func getCorrectAnswer(for question: Question) -> String {
        question.data.correctOption ?? question.data.correctAnswer ?? question.answer ?? ""
    }

    private func isAnswerCorrect(match: String, question: Question) -> Bool {
        let matchLower = match.lowercased()
        let data = question.data
        switch question.type {
        case .fourOptions, .pictureChoice:
            return matchLower == (data.correctOption ?? "").lowercased()
        case .whichIs:
            let correct = (data.correctAnswer ?? "").lowercased()
            return matchLower.contains(correct) || correct.contains(matchLower)
        default:
            let correct = (data.correctOption ?? data.correctAnswer ?? question.answer ?? "").lowercased()
            return matchLower == correct
        }
    }

    private func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000_000 { return String(format: "$%.1fM", Double(amount) / 1_000_000) }
        if amount >= 1_000 { return "$\(amount / 1_000)k" }
        return "$\(amount)"
    }
}
