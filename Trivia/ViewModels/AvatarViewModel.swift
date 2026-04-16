import Foundation
import Combine

// MARK: - Avatar Definition

struct AvatarDefinition: Identifiable {
    let id: String
    let name: String
    let personality: String
    let modelFileName: String
    let voiceId: String
    let available: AvatarAvailability
    /// Y-axis rotation in degrees applied after load to correct facing direction.
    /// 0 = default (faces +Z toward camera). Try 180 if model faces away.
    let yRotationDegrees: Float

    enum AvatarAvailability {
        case everyone
        case developer
        case comingSoon
    }
}

let appAvatars: [AvatarDefinition] = [
    AvatarDefinition(
        id: "trixie",
        name: "Trixie",
        personality: "Bubbly, witty, and always ready with a fun fact. Keeps the energy high and celebrates every answer.",
        modelFileName: "female_adult_001",
        voiceId: "nova",
        available: .everyone,
        yRotationDegrees: 0
    ),
    AvatarDefinition(
        id: "nova",
        name: "Nova",
        personality: "Cool and futuristic. Drops knowledge with sleek confidence and a dash of sci-fi flair.",
        modelFileName: "real_female",
        voiceId: "shimmer",
        available: .everyone,
        yRotationDegrees: 180   // most online USDZ exports face -Z (away from camera); flip to face viewer
    ),
    AvatarDefinition(
        id: "rex",
        name: "Rex",
        personality: "Bold and competitive. Brings sports-announcer energy and isn't afraid to tease you.",
        modelFileName: "Business_Male_01",
        voiceId: "onyx",
        available: .everyone,
        yRotationDegrees: 0
    ),
    AvatarDefinition(
        id: "sage",
        name: "Sage",
        personality: "Calm and wise. Explains answers like a favorite teacher with endless patience.",
        modelFileName: "",
        voiceId: "alloy",
        available: .comingSoon,
        yRotationDegrees: 0
    ),
]

// MARK: - Game Phase

enum GamePhase: Equatable {
    case idle
    case briefing
    case askingQuestion
    case waitingForAnswer
    case suspense
    case revealingAnswer
    case reacting
    case explaining
    case transitioning
    case gameFarewell
}

// MARK: - AvatarViewModel

@MainActor
class AvatarViewModel: ObservableObject {
    @Published var isSpeaking = false
    @Published var currentDialogue = ""
    @Published var emotion: AvatarEmotion = .neutral
    @Published var selectedAvatar: AvatarDefinition = appAvatars[0]
    @Published var currentWord: String = ""
    @Published var gamePhase: GamePhase = .idle
    @Published var voiceEnabled = false

    /// The user's last spoken transcript (for display)
    @Published var userTranscript = ""

    var modelName: String { selectedAvatar.modelFileName }

    private var speakGeneration = 0
    private var speechCompletion: (() -> Void)?

    enum AvatarEmotion: String {
        case neutral, happy, excited, thinking, sad, surprised
    }

    func selectAvatar(_ avatar: AvatarDefinition) {
        selectedAvatar = avatar
    }

    // MARK: - Speaking with Audio

    /// Speaks text aloud using TTS with lip-sync and updates dialogue.
    /// Returns when audio finishes playing.
    func speakAloud(_ text: String) async {
        guard !text.isEmpty else { return }
        speakGeneration += 1
        let gen = speakGeneration

        currentDialogue = text
        isSpeaking = true

        // Bind word tracking from audio service
        let wordObserver = AudioService.shared.$currentWord
            .receive(on: RunLoop.main)
            .sink { [weak self] word in
                self?.currentWord = word
            }

        await AudioService.shared.speakWithLipSync(text: text)

        // Wait for audio to finish
        await withCheckedContinuation { continuation in
            if gen != speakGeneration {
                continuation.resume()
                return
            }

            // If audio already stopped, resume immediately
            if !AudioService.shared.isPlaying {
                continuation.resume()
                return
            }

            AudioService.shared.onSpeechComplete = {
                continuation.resume()
            }
        }

        wordObserver.cancel()

        // Only update if this speech wasn't cancelled
        if gen == speakGeneration {
            isSpeaking = false
            currentWord = ""
        }
    }

    /// Fire-and-forget speak (non-blocking, like web's say())
    func speakFireAndForget(_ text: String) {
        guard !text.isEmpty else { return }
        currentDialogue = text
        isSpeaking = true

        let wordObserver = AudioService.shared.$currentWord
            .receive(on: RunLoop.main)
            .sink { [weak self] word in
                self?.currentWord = word
            }

        Task {
            await AudioService.shared.speakWithLipSync(text: text)

            // Wait for completion via callback
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                if !AudioService.shared.isPlaying {
                    continuation.resume()
                    return
                }
                AudioService.shared.onSpeechComplete = {
                    continuation.resume()
                }
            }

            wordObserver.cancel()
            isSpeaking = false
            currentWord = ""
            currentDialogue = ""
        }
    }

    /// Speaks text with only dialogue display (no audio). For fallback/silent mode.
    func speak(_ text: String) {
        currentDialogue = text
        isSpeaking = true
    }

    func stopSpeaking() {
        speakGeneration += 1
        AudioService.shared.stopPlayback()
        isSpeaking = false
        currentDialogue = ""
        currentWord = ""
    }

    // MARK: - Prefetch

    func prefetchDialogue(_ text: String) {
        AudioService.shared.prefetch(text: text)
    }

    // MARK: - Emotions

    func setEmotion(_ emotion: AvatarEmotion) {
        self.emotion = emotion
    }

    func reactToAnswer(isCorrect: Bool) {
        emotion = isCorrect ? .excited : .sad
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.emotion = .neutral
        }
    }

    // MARK: - Game Phase Orchestration

    /// Run the full briefing → question asking phase.
    func runBriefing(playerName: String?) async {
        gamePhase = .briefing
        emotion = .happy
        let text = Dialogue.briefing(playerName: playerName)
        await speakAloud(text)
        emotion = .neutral
    }

    /// Avatar reads the question aloud.
    func askQuestion(_ question: Question, number: Int, prize: Int) async {
        gamePhase = .askingQuestion
        emotion = .thinking
        let text = Dialogue.formatQuestion(question, number: number, prize: prize)
        await speakAloud(text)
        // Clear the echo-word cache so the user's answer words (e.g. "before",
        // "after") aren't blocked just because they appeared in the question.
        AudioService.shared.clearAvatarWords()
        gamePhase = .waitingForAnswer
        emotion = .neutral
    }

    /// Avatar builds suspense after user answers.
    func playSuspense(selectedText: String, elapsed: Double?) async {
        gamePhase = .suspense
        emotion = .thinking
        let text = Dialogue.suspense(selectedText: selectedText, elapsed: elapsed)
        await speakAloud(text)
    }

    /// Avatar reacts to the answer reveal.
    func playReaction(isCorrect: Bool, fact: String, correctAnswer: String) async {
        gamePhase = .reacting
        reactToAnswer(isCorrect: isCorrect)
        let reaction = isCorrect
            ? Dialogue.correctWithFact(fact)
            : Dialogue.incorrectWithFact(fact, correctAnswer: correctAnswer)
        await speakAloud(reaction)
    }

    /// Avatar explains the answer / shares a fact.
    func playExplanation(fact: String) async {
        guard !fact.isEmpty else { return }
        gamePhase = .explaining
        emotion = .happy
        await speakAloud(fact)
        emotion = .neutral
    }

    /// Avatar transitions to the next question.
    func playTransition(totalWinnings: Int, nextPrize: Int, wasCorrect: Bool, roundEarnings: Int, speedBon: Int, streakBon: Int) async {
        gamePhase = .transitioning
        let text = Dialogue.transitionToNext(
            totalWinnings: totalWinnings,
            nextPrize: nextPrize,
            wasCorrect: wasCorrect,
            roundEarnings: roundEarnings,
            speedBon: speedBon,
            streakBon: streakBon
        )
        await speakAloud(text)
    }

    /// Avatar says goodbye at game end.
    func playFarewell(wrongCount: Int) async {
        gamePhase = .gameFarewell
        emotion = wrongCount == 0 ? .excited : .happy
        let text = Dialogue.gameComplete(wrongCount: wrongCount)
        await speakAloud(text)
        emotion = .neutral
        gamePhase = .idle
    }
}
