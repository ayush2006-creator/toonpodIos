import SwiftUI
import RealityKit

// MARK: - AvatarGamePanel (updated)
//
// Wires AvatarRealityView + AvatarAnimationController + AvatarLipSyncController
// together with AvatarViewModel and game phase changes.

struct AvatarGamePanel: View {
    @ObservedObject var avatarVM: AvatarViewModel
    @ObservedObject var speechService: SpeechService

    let lifelines: Lifelines
    let questionType: QuestionType
    let onLifeline: (String) -> Void

    // Controllers – created once and kept alive for the panel lifetime
    @StateObject private var panelState = AvatarPanelState()

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── 3D Avatar (upper body cropped) ─────────────────────
            AvatarRealityView(modelName: avatarVM.modelName,
                              yRotationDegrees: avatarVM.selectedAvatar.yRotationDegrees) { entity in
                // Entity loaded – hand off to controllers
                panelState.animController.start(with: entity)
                panelState.lipSyncController.attach(to: entity)
            }
            .ignoresSafeArea(edges: .top)

            // ── Bottom fade ────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color(hex: "0d001a").opacity(0.9), Color(hex: "0d001a")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
            }

            // ── Speaking waveform (bottom-left) ──────────────────
            if avatarVM.isSpeaking {
                HStack {
                    SpeakingWaveform(word: avatarVM.currentWord)
                        .padding(.leading, 16)
                        .padding(.bottom, 8)
                    Spacer()
                }
            }

            // ── Dialogue caption ──────────────────────────────────
            if !avatarVM.currentDialogue.isEmpty {
                DialogueCaption(text: avatarVM.currentDialogue, emotion: avatarVM.emotion)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: avatarVM.currentDialogue)
            }

            // ── Voice input ───────────────────────────────────────
            if avatarVM.voiceEnabled && avatarVM.gamePhase == .waitingForAnswer {
                VStack {
                    Spacer()
                    CompactVoiceBar(
                        isListening: speechService.isListening,
                        transcript: speechService.transcript
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 56)
                }
                .transition(.opacity)
            }

            // ── User transcript ───────────────────────────────────
            if !avatarVM.userTranscript.isEmpty {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text("You: \(avatarVM.userTranscript)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    Spacer().frame(height: 70)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity)
            }
        }

        // ── Floating lifelines (right side) ──────────────────────
        .overlay(alignment: .trailing) {
            FloatingLifelines(lifelines: lifelines, questionType: questionType, onUse: onLifeline)
                .padding(.trailing, 12)
        }

        // ── Phase indicator (top-left) ─────────────────────────
        .overlay(alignment: .topLeading) {
            if avatarVM.gamePhase != .idle && avatarVM.gamePhase != .waitingForAnswer {
                PhaseIndicator(phase: avatarVM.gamePhase)
                    .padding(.leading, 12)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }

        // ── Gesture wiring — fires when game phase changes ──────
        .onChange(of: avatarVM.gamePhase) { newPhase in
            if let gesture = AvatarAnimationController.gestureForPhase(newPhase) {
                panelState.animController.playGesture(gesture)
            }
        }

        // ── Lip-sync wiring — fires when new dialogue arrives ───
        .onChange(of: avatarVM.currentDialogue) { newText in
            guard !newText.isEmpty else {
                panelState.lipSyncController.stopLipSync()
                return
            }
            panelState.lipSyncController.speak(
                text: newText,
                wordTimings: AudioService.shared.currentWordTimings
            )
        }

        // ── Stop lip-sync when avatar stops speaking ─────────────
        .onChange(of: avatarVM.isSpeaking) { speaking in
            if !speaking { panelState.lipSyncController.stopLipSync() }
        }

        .animation(.easeInOut(duration: 0.3), value: avatarVM.isSpeaking)
        .animation(.easeInOut(duration: 0.3), value: avatarVM.voiceEnabled)
        .animation(.easeInOut(duration: 0.25), value: avatarVM.userTranscript.isEmpty)
    }
}

// MARK: - Panel state holder (keeps controllers alive across re-renders)

@MainActor
final class AvatarPanelState: ObservableObject {
    let animController   = AvatarAnimationController()
    let lipSyncController = AvatarLipSyncController()

    deinit {
        // Stop controllers when panel is deallocated
        Task { @MainActor [weak animController, weak lipSyncController] in
            animController?.stop()
            lipSyncController?.stopLipSync()
        }
    }
}

// MARK: - Floating Lifelines (unchanged)

struct FloatingLifelines: View {
    let lifelines: Lifelines
    let questionType: QuestionType
    let onUse: (String) -> Void

    private var fiftyAvailable: Bool {
        lifelines.fiftyFifty && [.fourOptions, .oddOneOut, .guessThePicture, .pictureChoice].contains(questionType)
    }
    private var hintAvailable: Bool {
        lifelines.hint && questionType != .guessThePicture
    }
    private var swapAvailable: Bool {
        lifelines.swap && ![.lightning, .guessThePicture, .wipeout].contains(questionType)
    }

    var body: some View {
        VStack(spacing: 14) {
            FloatingLifelineButton(label: "50:50", color: .yellow,  available: fiftyAvailable, used: !lifelines.fiftyFifty) { onUse("fiftyFifty") }
            FloatingLifelineButton(label: "Hint",  color: .cyan,    available: hintAvailable,  used: !lifelines.hint)       { onUse("hint") }
            FloatingLifelineButton(label: "Swap",  color: .purple,  available: swapAvailable,  used: !lifelines.swap)       { onUse("swap") }
        }
    }
}

struct FloatingLifelineButton: View {
    let label: String
    let color: Color
    let available: Bool
    let used: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(available ? color.opacity(0.7) : Color.white.opacity(0.15), lineWidth: 2)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.black.opacity(0.5)))

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(available ? color : .white.opacity(0.3))

                if used {
                    Circle().stroke(Color.red.opacity(0.6), lineWidth: 2).frame(width: 52, height: 52)
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red.opacity(0.6))
                        .offset(x: 18, y: -18)
                }
            }
        }
        .disabled(!available)
    }
}

// MARK: - Speaking Waveform

struct SpeakingWaveform: View {
    let word: String
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Color.purple.opacity(0.8))
                    .frame(width: 3, height: animating ? waveHeight(i) : 4)
                    .animation(
                        .easeInOut(duration: 0.3 + Double(i) * 0.05)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.07),
                        value: animating
                    )
            }
            if !word.isEmpty {
                Text(word)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .id(word)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
        .onAppear { animating = true }
    }

    private func waveHeight(_ index: Int) -> CGFloat {
        let dist = abs(Double(index) - 2.0)
        return CGFloat(14 - dist * 3)
    }
}

// MARK: - Dialogue Caption

struct DialogueCaption: View {
    let text: String
    let emotion: AvatarViewModel.AvatarEmotion

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(emotionColor.opacity(0.3), lineWidth: 1)
                    )
            )
    }

    private var emotionColor: Color {
        switch emotion {
        case .neutral:            return .white
        case .happy, .excited:    return .green
        case .thinking:           return .yellow
        case .sad:                return .red
        case .surprised:          return .orange
        }
    }
}

// MARK: - Phase Indicator

struct PhaseIndicator: View {
    let phase: GamePhase
    @State private var dotPulse = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)
                .scaleEffect(dotPulse ? 1.4 : 1.0)
                .opacity(dotPulse ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: dotPulse)
            Text(phaseLabel)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.4))
        .cornerRadius(8)
        .onAppear { dotPulse = true }
        .onChange(of: phase) { _ in dotPulse = false; dotPulse = true }
    }

    private var phaseLabel: String {
        switch phase {
        case .briefing:        return "Greeting..."
        case .askingQuestion:  return "Reading question..."
        case .suspense:        return "Building suspense..."
        case .revealingAnswer: return "Revealing..."
        case .reacting:        return "Reacting..."
        case .explaining:      return "Explaining..."
        case .transitioning:   return "Next question..."
        case .gameFarewell:    return "Wrapping up..."
        case .idle, .waitingForAnswer: return ""
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .askingQuestion:  return .blue
        case .suspense:        return .yellow
        case .reacting:        return .orange
        case .explaining:      return .green
        default:               return .purple
        }
    }
}

// MARK: - Compact Voice Bar (unchanged)

struct CompactVoiceBar: View {
    let isListening: Bool
    let transcript: String
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if isListening {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseScale)
                }
                Image(systemName: isListening ? "mic.fill" : "mic.slash")
                    .font(.caption2)
                    .foregroundColor(isListening ? .purple : .white.opacity(0.3))
            }
            .frame(width: 24, height: 24)

            if isListening {
                if transcript.isEmpty {
                    HStack(spacing: 2) {
                        Text("Listening")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                            .italic()
                        ListeningDots()
                    }
                } else {
                    Text(transcript)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
        .onAppear { pulseScale = 1.3 }
    }
}

// MARK: - Listening Dots

struct ListeningDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.purple.opacity(0.8))
                    .frame(width: 4, height: 4)
                    .opacity(animating ? 1.0 : 0.2)
                    .animation(
                        .easeInOut(duration: 0.7)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - DialogueBubble (kept for backward compat)

struct DialogueBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .lineLimit(3)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
