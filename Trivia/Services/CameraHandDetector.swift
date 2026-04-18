import AVFoundation
import Vision
import SwiftUI

/// Detects raised hands via the front camera and maps them to party players.
/// Vision processing runs on a background queue; only UI updates touch MainActor.
@MainActor
class CameraHandDetector: NSObject, ObservableObject {

    // MARK: - Published

    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isRunning = false
    @Published var isAuthorized = false
    @Published var detectedHandX: CGFloat? = nil   // normalized 0-1
    @Published var detectedPlayer: String? = nil

    // MARK: - Config

    /// Player names in left-to-right visual order (matching seating order).
    var players: [String] = []

    /// Called on MainActor when a raised hand is confidently assigned to a player.
    var onBuzzDetected: ((String) -> Void)?

    // MARK: - Private

    private var session: AVCaptureSession?
    private let processingQueue = DispatchQueue(label: "com.trivia.handDetect", qos: .userInteractive)
    private var lastBuzzTime: Date = .distantPast
    private let cooldown: TimeInterval = 1.5

    // MARK: - Permission & Session

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
        let queue = processingQueue
        queue.async { [weak self] in self?.buildSession() }
    }

    func stopSession() {
        session?.stopRunning()
        session = nil
        previewLayer = nil
        isRunning = false
        detectedHandX = nil
        detectedPlayer = nil
    }

    // MARK: - Session Setup (runs on processingQueue)

    nonisolated private func buildSession() {
        let s = AVCaptureSession()
        s.sessionPreset = .medium

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device),
            s.canAddInput(input)
        else { return }

        s.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        let queue = DispatchQueue(label: "com.trivia.handDetect.frames", qos: .userInteractive)
        output.setSampleBufferDelegate(self, queue: queue)

        guard s.canAddOutput(output) else { return }
        s.addOutput(output)

        let layer = AVCaptureVideoPreviewLayer(session: s)
        layer.videoGravity = .resizeAspectFill

        s.startRunning()

        Task { @MainActor [weak self] in
            self?.session = s
            self?.previewLayer = layer
            self?.isRunning = true
        }
    }

    // MARK: - Vision (runs on frame capture queue)

    nonisolated private func detectRaisedHand(in pixelBuffer: CVPixelBuffer) -> CGFloat? {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 6

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored,
                                            options: [:])
        try? handler.perform([request])

        guard let results = request.results, !results.isEmpty else { return nil }

        var bestX: CGFloat? = nil
        var bestScore: Float = 0

        for obs in results {
            guard
                let wrist    = try? obs.recognizedPoint(.wrist),
                let indexTip = try? obs.recognizedPoint(.indexTip),
                let midTip   = try? obs.recognizedPoint(.middleTip),
                wrist.confidence > 0.4,
                indexTip.confidence > 0.4
            else { continue }

            // Vision y: 0 = bottom, 1 = top. Raised hand: wrist in upper portion.
            guard wrist.location.y > 0.35 else { continue }

            // Fingertip must be above wrist (hand extended upward, not just hanging)
            guard indexTip.location.y > wrist.location.y ||
                  midTip.location.y   > wrist.location.y else { continue }

            let score = wrist.confidence + indexTip.confidence
            if score > bestScore {
                bestScore = score
                bestX = wrist.location.x
            }
        }

        return bestX
    }

    nonisolated private func playerForX(_ x: CGFloat, players: [String]) -> String? {
        guard !players.isEmpty else { return nil }
        let index = min(Int(x * CGFloat(players.count)), players.count - 1)
        return players[index]
    }

    // MARK: - Handle Detection Results (MainActor)

    private func handleHandX(_ x: CGFloat?) {
        detectedHandX = x
        guard let x else {
            detectedPlayer = nil
            return
        }

        let snapshot = players
        let player = playerForX(x, players: snapshot)
        detectedPlayer = player

        if let player,
           Date().timeIntervalSince(lastBuzzTime) > cooldown {
            lastBuzzTime = Date()
            onBuzzDetected?(player)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraHandDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handX = detectRaisedHand(in: pixelBuffer)
        Task { @MainActor [weak self] in self?.handleHandX(handX) }
    }
}
