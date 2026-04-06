import SwiftUI
import RealityKit

/// Compact 3D avatar panel shown during gameplay with speaking animation and voice feedback
struct AvatarGamePanel: View {
    @ObservedObject var avatarVM: AvatarViewModel
    @ObservedObject var speechService: SpeechService

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                // Mini 3D avatar
                ZStack {
                    AvatarModelView(
                        modelName: avatarVM.modelName,
                        allowsRotation: false,
                        autoRotate: false,
                        showPlatform: false
                    )
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: avatarVM.isSpeaking ? 3 : 2)
                    )

                    // Speaking pulse animation
                    if avatarVM.isSpeaking {
                        Circle()
                            .stroke(borderColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 88, height: 88)
                            .scaleEffect(avatarVM.isSpeaking ? 1.15 : 1.0)
                            .opacity(avatarVM.isSpeaking ? 0 : 0.6)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                                value: avatarVM.isSpeaking
                            )
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    // Speaking indicator with word display
                    if avatarVM.isSpeaking {
                        SpeakingWordBubble(word: avatarVM.currentWord)
                            .offset(x: 4, y: 4)
                    }
                }

                // Dialogue bubble
                VStack(alignment: .leading, spacing: 4) {
                    if !avatarVM.currentDialogue.isEmpty {
                        DialogueBubble(text: avatarVM.currentDialogue)
                    }

                    // Game phase indicator
                    if avatarVM.gamePhase != .idle && avatarVM.gamePhase != .waitingForAnswer {
                        PhaseIndicator(phase: avatarVM.gamePhase)
                    }
                }
            }

            // Voice input section
            if avatarVM.voiceEnabled && avatarVM.gamePhase == .waitingForAnswer {
                VoiceInputBar(
                    isListening: speechService.isListening,
                    transcript: speechService.transcript
                )
            }

            // User transcript display
            if !avatarVM.userTranscript.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text("You: \(avatarVM.userTranscript)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var borderColor: Color {
        switch avatarVM.emotion {
        case .neutral: return .purple
        case .happy, .excited: return .green
        case .thinking: return .yellow
        case .sad: return .red
        case .surprised: return .orange
        }
    }
}

// MARK: - Speaking Word Bubble

struct SpeakingWordBubble: View {
    let word: String
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 3) {
            if word.isEmpty {
                // Waveform bars when speaking without word data
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(Color.purple)
                        .frame(width: 3, height: isAnimating ? CGFloat.random(in: 6...16) : 4)
                        .animation(
                            .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.08),
                            value: isAnimating
                        )
                }
            } else {
                // Show current word
                Text(word)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.purple.opacity(0.8))
        .clipShape(Capsule())
        .onAppear { isAnimating = true }
    }
}

// MARK: - Phase Indicator

struct PhaseIndicator: View {
    let phase: GamePhase

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)
            Text(phaseLabel)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .briefing: return "Greeting..."
        case .askingQuestion: return "Reading question..."
        case .suspense: return "Building suspense..."
        case .revealingAnswer: return "Revealing..."
        case .reacting: return "Reacting..."
        case .explaining: return "Explaining..."
        case .transitioning: return "Next question..."
        case .gameFarewell: return "Wrapping up..."
        case .idle, .waitingForAnswer: return ""
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .askingQuestion: return .blue
        case .suspense: return .yellow
        case .reacting: return .orange
        case .explaining: return .green
        default: return .purple
        }
    }
}

// MARK: - Voice Input Bar

struct VoiceInputBar: View {
    let isListening: Bool
    let transcript: String
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 8) {
            // Mic icon with pulse
            ZStack {
                if isListening {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                        .onAppear { pulseScale = 1.3 }
                }
                Image(systemName: isListening ? "mic.fill" : "mic.slash")
                    .font(.caption)
                    .foregroundColor(isListening ? .purple : .white.opacity(0.3))
            }
            .frame(width: 28, height: 28)

            if isListening {
                if transcript.isEmpty {
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .italic()
                } else {
                    Text(transcript)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            } else {
                Text("Voice input off")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Dialogue Bubble

struct DialogueBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .lineLimit(3)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
