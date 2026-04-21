import SwiftUI
import AVFoundation

/// Shown after the avatar asks a question.
/// Uses the front camera + Vision to detect raised hands (wrist above mouth + shoulder).
/// Face bounding boxes are drawn live on the camera feed with player name labels.
/// Falls back to tap buttons after 15 s or when voice keyword fires.
struct BuzzInOverlay: View {
    @EnvironmentObject var partyVM: PartyViewModel

    let eligiblePlayers: [String]
    let onPlayerIdentified: (String) -> Void
    let onTimeout: () -> Void

    @StateObject private var camera = CameraHandDetector()

    @State private var showManualPicker = false
    @State private var secondsLeft: Int = 15
    @State private var detectedName: String? = nil
    @State private var confirming = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Camera feed ──
                cameraBackground

                // ── Face bounding boxes ──
                faceOverlay(geo: geo)

                // ── HUD or manual picker ──
                VStack(spacing: 0) {
                    if showManualPicker {
                        manualPickerView
                    } else {
                        cameraHUDView
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .onAppear {
            camera.playerFacePositions = partyVM.playerFacePositions
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
            if detected, !confirming { withAnimation { showManualPicker = true } }
        }
    }

    // MARK: - Camera Background

    @ViewBuilder
    private var cameraBackground: some View {
        if let layer = camera.previewLayer {
            CameraPreviewView(layer: layer)
                .overlay(Color.black.opacity(0.42))
        } else {
            Color(hex: "1a0533")
        }
    }

    // MARK: - Face Boxes Overlay

    @ViewBuilder
    private func faceOverlay(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height

        ForEach(camera.detectedFaces) { face in
            // Vision coords: origin bottom-left, y up → flip y for SwiftUI
            let cx = face.x * w
            let cy = (1 - face.y) * h
            let bw = face.width  * w
            let bh = face.height * h

            let playerName = resolvedName(for: face)
            let color = playerName.map { partyVM.color(for: $0) } ?? Color.white

            // Face rectangle
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 2)
                .frame(width: bw, height: bh)
                .position(x: cx, y: cy)

            // Name label above the box
            if let name = playerName {
                Text(name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.75))
                    .cornerRadius(5)
                    .position(x: cx, y: cy - bh / 2 - 14)
            }
        }
    }

    /// Resolves a face's detected x-position to a registered player name.
    private func resolvedName(for face: DetectedFace) -> String? {
        let positions = partyVM.playerFacePositions
        guard !positions.isEmpty else { return nil }
        return positions.min(by: { abs($0.value - face.x) < abs($1.value - face.x) })?.key
    }

    // MARK: - Camera HUD

    private var cameraHUDView: some View {
        VStack(spacing: 0) {
            Spacer()

            if let name = detectedName {
                detectedBadge(name)
            } else {
                promptBadge
            }

            // Countdown + fallback
            HStack {
                Text("\(secondsLeft)s")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                Spacer()
                Button("Tap instead") {
                    withAnimation { showManualPicker = true }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var promptBadge: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.9))
            Text("Raise your hand to buzz in!")
                .font(.title3).fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.45))
        .cornerRadius(14)
        .padding(.horizontal, 24)
    }

    private func detectedBadge(_ name: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 30))
                .foregroundColor(partyVM.color(for: name))
            Text(name.uppercased())
                .font(.system(size: 28, weight: .black))
                .foregroundColor(partyVM.color(for: name))
            Text("is buzzing in!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.65))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    // MARK: - Manual Picker

    private var manualPickerView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Who buzzed?")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                ForEach(eligiblePlayers, id: \.self) { name in
                    Button {
                        handleDetection(name)
                    } label: {
                        Text(name)
                            .font(.title2).fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(partyVM.color(for: name))
                            .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(Color.black.opacity(0.55))
    }

    // MARK: - Detection

    private func handleDetection(_ name: String) {
        guard !confirming else { return }
        confirming = true
        withAnimation { detectedName = name }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            camera.stopSession()
            onPlayerIdentified(name)
        }
    }
}
