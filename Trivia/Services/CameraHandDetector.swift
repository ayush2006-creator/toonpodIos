import AVFoundation
import Vision
import SwiftUI

// MARK: - Supporting types

private struct FrameResult {
    let hands:  [VNHumanHandPoseObservation]
    let bodies: [VNHumanBodyPoseObservation]
    let faces:  [VNFaceObservation]
}

struct DetectedFace: Identifiable {
    let id = UUID()
    /// Normalized Vision coordinates (origin bottom-left, y up).
    let x: CGFloat       // midX of bounding box
    let y: CGFloat       // midY of bounding box
    let width: CGFloat
    let height: CGFloat
}

// MARK: - CameraHandDetector

/// Detects raised hands using anatomical landmarks:
///   • Wrist must be above the nearest face's mouth (face bbox bottom)
///   • Wrist must be above the shoulder (from body pose, fallback 0.30)
///
/// Player identity is resolved by matching the nearest face's x-position
/// against pre-registered face positions captured during voice registration.
@MainActor
class CameraHandDetector: NSObject, ObservableObject {

    // MARK: - Published

    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isRunning    = false
    @Published var isAuthorized = false

    /// All faces visible in the current frame (for overlay rendering).
    @Published var detectedFaces: [DetectedFace] = []

    /// Normalized x-position of the most recently detected raised wrist.
    @Published var detectedHandX: CGFloat? = nil

    // MARK: - Config

    /// Player name → face x-position registered during voice registration.
    /// Set this from partyVM.playerFacePositions before starting.
    var playerFacePositions: [String: CGFloat] = [:]

    /// Fallback: ordered player names for zone-split when no face positions registered.
    var players: [String] = []

    /// Called on MainActor when a raised hand is confidently assigned to a player.
    var onBuzzDetected: ((String) -> Void)?

    // MARK: - Private

    private var session: AVCaptureSession?
    private let frameQueue = DispatchQueue(label: "com.trivia.camera.frames", qos: .userInteractive)
    private var lastBuzzTime: Date = .distantPast
    private let cooldown: TimeInterval = 1.5

    /// Latest face observations — accessed from background to avoid per-frame MainActor hops.
    private var latestFaces: [VNFaceObservation] = []

    // MARK: - Session Lifecycle

    func requestPermissionAndStart() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor [weak self] in
                self?.isAuthorized = granted
                if granted { self?.startSession() }
            }
        }
    }

    func startSession() {
        guard session == nil else { return }
        frameQueue.async { [weak self] in self?.buildSession() }
    }

    func stopSession() {
        session?.stopRunning()
        session = nil
        previewLayer  = nil
        isRunning     = false
        detectedFaces = []
        detectedHandX = nil
        latestFaces   = []
    }

    /// Returns the x-position of the most prominent face in the current frame.
    /// Call this immediately after a player confirms their name during registration.
    func captureFacePosition() -> CGFloat? {
        detectedFaces.first?.x
    }

    // MARK: - Session Setup (background)

    nonisolated private func buildSession() {
        let s = AVCaptureSession()
        s.sessionPreset = .medium

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video, position: .front),
            let input  = try? AVCaptureDeviceInput(device: device),
            s.canAddInput(input)
        else { return }

        s.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: frameQueue)
        guard s.canAddOutput(output) else { return }
        s.addOutput(output)

        let layer = AVCaptureVideoPreviewLayer(session: s)
        layer.videoGravity = .resizeAspectFill

        s.startRunning()

        Task { @MainActor [weak self] in
            self?.session     = s
            self?.previewLayer = layer
            self?.isRunning   = true
        }
    }

    // MARK: - Vision (background queue)

    nonisolated private func detectFrame(in pixelBuffer: CVPixelBuffer) -> FrameResult {
        let handReq = VNDetectHumanHandPoseRequest()
        handReq.maximumHandCount = 6

        let bodyReq = VNDetectHumanBodyPoseRequest()
        let faceReq = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored,
                                            options: [:])
        try? handler.perform([handReq, bodyReq, faceReq])

        return FrameResult(
            hands:  handReq.results ?? [],
            bodies: bodyReq.results ?? [],
            faces:  faceReq.results ?? []
        )
    }

    /// Returns (wristX, playerName) if a raised hand is confidently detected.
    nonisolated private func findRaisedHand(
        in result: FrameResult,
        playerFacePositions: [String: CGFloat],
        players: [String]
    ) -> (wristX: CGFloat, playerName: String)? {

        guard !result.faces.isEmpty else { return nil }

        // ── Shoulder Y: highest shoulder from body pose, fallback 0.30 ──
        let shoulderY: CGFloat = result.bodies.first.flatMap { body -> CGFloat? in
            let lS = try? body.recognizedPoint(.leftShoulder)
            let rS = try? body.recognizedPoint(.rightShoulder)
            return [lS, rS]
                .compactMap { p -> CGFloat? in
                    guard let p, p.confidence > 0.3 else { return nil }
                    return p.location.y
                }
                .max()
        } ?? 0.30

        // ── Check each hand ──
        for handObs in result.hands {
            guard
                let wrist    = try? handObs.recognizedPoint(.wrist),
                let indexTip = try? handObs.recognizedPoint(.indexTip),
                wrist.confidence > 0.4, indexTip.confidence > 0.35
            else { continue }

            let wx = wrist.location.x
            let wy = wrist.location.y

            // Find the face nearest in x to this wrist
            guard let nearestFace = result.faces.min(by: {
                abs($0.boundingBox.midX - wx) < abs($1.boundingBox.midX - wx)
            }) else { continue }

            // Mouth ≈ bottom edge of face bounding box (Vision origin = bottom-left)
            let mouthY = nearestFace.boundingBox.origin.y

            // Raised-hand conditions:
            //   1. Wrist is above the mouth
            //   2. Wrist is above the shoulder
            //   3. Fingertip points upward (hand extended, not horizontal)
            guard wy > mouthY,
                  wy > shoulderY,
                  indexTip.location.y > wrist.location.y
            else { continue }

            // ── Identify player ──
            let faceX = nearestFace.boundingBox.midX
            let name  = nearestPlayer(faceX: faceX,
                                      positions: playerFacePositions,
                                      fallbackPlayers: players,
                                      wristX: wx)
            guard let name else { continue }

            return (wristX: wx, playerName: name)
        }

        return nil
    }

    /// Resolves a face x-position to a player name.
    /// Uses registered face positions if available; falls back to zone-split.
    nonisolated private func nearestPlayer(
        faceX: CGFloat,
        positions: [String: CGFloat],
        fallbackPlayers: [String],
        wristX: CGFloat
    ) -> String? {
        if !positions.isEmpty {
            return positions.min(by: { abs($0.value - faceX) < abs($1.value - faceX) })?.key
        }
        // Zone fallback
        guard !fallbackPlayers.isEmpty else { return nil }
        let index = min(Int(wristX * CGFloat(fallbackPlayers.count)), fallbackPlayers.count - 1)
        return fallbackPlayers[index]
    }

    // MARK: - Main-actor update

    private func applyFrameResult(_ result: FrameResult) {
        // Update face overlays
        detectedFaces = result.faces.map { f in
            DetectedFace(
                x:      f.boundingBox.midX,
                y:      f.boundingBox.midY,
                width:  f.boundingBox.width,
                height: f.boundingBox.height
            )
        }
        latestFaces = result.faces

        // Snapshot config for nonisolated call
        let positions = playerFacePositions
        let pList     = players

        guard let hit = findRaisedHand(in: result,
                                       playerFacePositions: positions,
                                       players: pList) else {
            detectedHandX = nil
            return
        }

        detectedHandX = hit.wristX

        guard Date().timeIntervalSince(lastBuzzTime) > cooldown else { return }
        lastBuzzTime = Date()
        onBuzzDetected?(hit.playerName)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraHandDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let result = detectFrame(in: pixelBuffer)
        Task { @MainActor [weak self] in self?.applyFrameResult(result) }
    }
}
