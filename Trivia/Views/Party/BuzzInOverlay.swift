import SwiftUI
import AVFoundation

/// Shown after the avatar asks a question.
/// Uses the front camera + Vision hand-pose detection to identify who raised their hand.
/// Falls back to tap buttons after 15 s if no hand is detected.
struct BuzzInOverlay: View {
    @EnvironmentObject var partyVM: PartyViewModel

    let eligiblePlayers: [String]
    let onPlayerIdentified: (String) -> Void
    let onTimeout: () -> Void

    // MARK: - Camera detector

    @StateObject private var camera = CameraHandDetector()

    // MARK: - State

    @State private var showManualPicker = false
    @State private var secondsLeft: Int = 15
    @State private var detectedName: String? = nil   // highlight name before confirming
    @State private var confirming = false             // brief pause before auto-confirming

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        ZStack {
            // Camera background (fills the overlay area)
            cameraLayer

            // Overlay content
            VStack(spacing: 0) {
                if showManualPicker {
                    manualPickerView
                } else {
                    cameraHUDView
                }
            }
        }
        .onAppear {
            camera.players = eligiblePlayers
            camera.onBuzzDetected = { name in
                guard eligiblePlayers.contains(name), !confirming else { return }
                handleDetection(name)
            }
            camera.requestPermissionAndStart()
        }
        .onDisappear { camera.stopSession() }
        .onReceive(timer) { _ in
            guard !showManualPicker, !confirming else { return }
            secondsLeft -= 1
            if secondsLeft <= 0 { withAnimation { showManualPicker = true } }
        }
        .onChange(of: partyVM.buzzDetected) { detected in
            // Also triggered by voice keyword detection in PartyGameScreen
            if detected, !showManualPicker { withAnimation { showManualPicker = true } }
        }
    }

    // MARK: - Camera Layer

    @ViewBuilder
    private var cameraLayer: some View {
        if let layer = camera.previewLayer {
            CameraPreviewView(layer: layer)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    // Semi-dark tint so UI remains readable
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.45))
                )
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "1a0533").opacity(0.97))
        }
    }

    // MARK: - Camera HUD (waiting for hand raise)

    private var cameraHUDView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Detected player highlight
            if let name = detectedName {
                detectedBadge(name)
            } else {
                promptBadge
            }

            // Player zone labels across the bottom
            playerZoneBar

            // Timer + fallback
            HStack {
                Text("\(secondsLeft)s")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Button("Tap instead") {
                    withAnimation { showManualPicker = true }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var promptBadge: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.9))
            Text("Raise your hand to buzz in!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private func detectedBadge(_ name: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundColor(partyVM.color(for: name))
            Text(name.uppercased())
                .font(.system(size: 32, weight: .black))
                .foregroundColor(partyVM.color(for: name))
            Text("is buzzing in!")
                .font(.title3)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
        )
        .padding(.horizontal, 24)
    }

    // Player name labels positioned proportionally across the bottom of the frame
    private var playerZoneBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(eligiblePlayers, id: \.self) { name in
                    let isDetected = camera.detectedPlayer == name

                    VStack(spacing: 4) {
                        // Hand indicator dot
                        Circle()
                            .fill(isDetected
                                  ? partyVM.color(for: name)
                                  : partyVM.color(for: name).opacity(0.3))
                            .frame(width: isDetected ? 14 : 8, height: isDetected ? 14 : 8)
                            .animation(.easeInOut(duration: 0.2), value: isDetected)

                        Text(name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isDetected ? partyVM.color(for: name) : .white.opacity(0.5))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(width: geo.size.width)
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
    }

    // MARK: - Manual Picker (fallback / voice-triggered)

    private var manualPickerView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Who buzzed?")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                ForEach(eligiblePlayers, id: \.self) { name in
                    Button {
                        onPlayerIdentified(name)
                    } label: {
                        Text(name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(partyVM.color(for: name))
                            .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Detection Logic

    private func handleDetection(_ name: String) {
        confirming = true
        withAnimation { detectedName = name }

        // Brief visual confirmation (0.8 s), then auto-confirm
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            camera.stopSession()
            onPlayerIdentified(name)
        }
    }
}
