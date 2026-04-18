import AVFoundation
import Vision
import SwiftUI

/// Detects faces via the front camera for party registration.
/// Vision processing runs on a background queue; only UI updates touch MainActor.
@MainActor
class CameraFaceDetector: NSObject, ObservableObject {

    // MARK: - Published

    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isRunning = false
    @Published var isAuthorized = false

    /// Normalized face rect in SwiftUI coordinate space (origin top-left, 0..1).
    @Published var currentFaceRect: CGRect? = nil

    // MARK: - Callback

    /// Fires on MainActor when a face has been continuously present for ~1.5 s.
    var onFaceStabilized: ((CGRect) -> Void)?

    // MARK: - Private

    private var session: AVCaptureSession?
    private let processingQueue = DispatchQueue(label: "com.trivia.faceDetect", qos: .userInteractive)
    private var stableTimer: Timer?
    private let stabilityCooldown: TimeInterval = 1.5
    private var lastFiredTime: Date = .distantPast
    private let refireDelay: TimeInterval = 3.0

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
        currentFaceRect = nil
        stableTimer?.invalidate()
        stableTimer = nil
        lastFiredTime = .distantPast
    }

    /// Resets the refire cooldown so the same face can trigger stabilization again.
    func resetRefireTimer() {
        lastFiredTime = .distantPast
        stableTimer?.invalidate()
        stableTimer = nil
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
        let queue = DispatchQueue(label: "com.trivia.faceDetect.frames", qos: .userInteractive)
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

    nonisolated private func detectFace(in pixelBuffer: CVPixelBuffer) -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )
        try? handler.perform([request])

        guard let obs = request.results?.first else { return nil }

        // Vision: origin bottom-left, y increases upward
        // SwiftUI: origin top-left, y increases downward
        let v = obs.boundingBox
        return CGRect(
            x: v.origin.x,
            y: 1.0 - v.origin.y - v.height,
            width: v.width,
            height: v.height
        )
    }

    // MARK: - Handle Results (MainActor)

    private func handleFaceRect(_ rect: CGRect?) {
        currentFaceRect = rect

        guard let rect else {
            stableTimer?.invalidate()
            stableTimer = nil
            return
        }

        guard Date().timeIntervalSince(lastFiredTime) > refireDelay else { return }
        guard stableTimer == nil else { return }

        stableTimer = Timer.scheduledTimer(withTimeInterval: stabilityCooldown, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.stableTimer = nil
                self.lastFiredTime = Date()
                self.onFaceStabilized?(rect)
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraFaceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let faceRect = detectFace(in: pixelBuffer)
        Task { @MainActor [weak self] in self?.handleFaceRect(faceRect) }
    }
}
