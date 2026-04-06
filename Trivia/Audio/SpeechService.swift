import Foundation
import Speech
import AVFoundation

/// iOS speech recognition service with echo suppression.
/// Mirrors the web app's 4-layer echo suppression architecture.
@MainActor
class SpeechService: ObservableObject {
    static let shared = SpeechService()

    @Published var isListening = false
    @Published var transcript = ""
    @Published var isAuthorized = false

    /// Callback when a final transcript is recognized
    var onTranscript: ((String) -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                self?.isAuthorized = (status == .authorized)
                if status != .authorized {
                    print("[SpeechService] Authorization denied: \(status.rawValue)")
                }
            }
        }
    }

    // MARK: - Start Listening

    /// Begins continuous speech recognition.
    /// Call `stopListening()` to end, or it auto-restarts on silence/error.
    func startListening() {
        guard isAuthorized else {
            print("[SpeechService] Not authorized for speech recognition")
            return
        }
        guard speechRecognizer?.isAvailable == true else {
            print("[SpeechService] Speech recognizer not available")
            return
        }
        guard !isListening else { return }

        // Cancel any existing task
        cancelRecognition()

        do {
            try startRecognitionSession()
            isListening = true
        } catch {
            print("[SpeechService] Failed to start: \(error)")
        }
    }

    /// Stops speech recognition and releases resources.
    func stopListening() {
        cancelRecognition()
        isListening = false
        transcript = ""
    }

    // MARK: - Flush (Echo Suppression Layer 2)

    /// Abort and restart recognition to flush Chrome-like buffer after avatar speech.
    func flushAndRestart() {
        guard isListening else { return }
        cancelRecognition()
        // Brief delay before restart (like web's restartAfterAbortMs = 50ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.isListening else { return }
            do {
                try self.startRecognitionSession()
            } catch {
                print("[SpeechService] Flush restart failed: \(error)")
                self.isListening = false
            }
        }
    }

    // MARK: - Answer Matching

    /// Matches transcript against answer options using local fuzzy matching.
    /// Falls back to server API if no match found.
    func matchAnswer(transcript: String, options: [String]) async -> String? {
        // Layer 1: Block during avatar speech
        if AudioService.shared.isSpeakingOrGrace {
            return nil
        }

        // Layer 4: Content-based echo filter
        if AudioService.shared.isAvatarEcho(transcript) {
            print("[SpeechService] Blocked echo: \(transcript)")
            return nil
        }

        // Local fuzzy matching first
        if let local = fuzzyMatch(transcript: transcript, options: options) {
            return local
        }

        // Server fallback
        do {
            return try await APIService.shared.matchAnswer(transcript: transcript, options: options)
        } catch {
            return nil
        }
    }

    // MARK: - Local Fuzzy Matching

    private func fuzzyMatch(transcript: String, options: [String]) -> String? {
        let t = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        // Exact match
        for opt in options {
            if opt.lowercased() == t { return opt }
        }

        // Substring match
        for opt in options {
            let low = opt.lowercased()
            if low.contains(t) || t.contains(low) { return opt }
        }

        // Letter label match (A, B, C, D, option A, etc.)
        let labels = ["a", "b", "c", "d"]
        for (i, label) in labels.enumerated() {
            if i < options.count {
                if t == label || t == "option \(label)" || t == "letter \(label)" {
                    return options[i]
                }
            }
        }

        // Binary answer matching
        let binaryTrue = ["before", "true", "yes", "first"]
        let binaryFalse = ["after", "false", "no", "second"]
        if options.count == 2 {
            if binaryTrue.contains(t) { return options[0] }
            if binaryFalse.contains(t) { return options[1] }
        }

        // Edit distance matching for longer transcripts
        var bestMatch: String?
        var bestScore = 0
        for opt in options {
            let score = wordOverlapScore(t, opt.lowercased())
            if score > bestScore {
                bestScore = score
                bestMatch = opt
            }
        }
        if bestScore >= 2 { return bestMatch }

        return nil
    }

    private func wordOverlapScore(_ a: String, _ b: String) -> Int {
        let aWords = Set(a.components(separatedBy: .whitespaces).filter { $0.count > 1 })
        let bWords = Set(b.components(separatedBy: .whitespaces).filter { $0.count > 1 })
        return aWords.intersection(bWords).count
    }

    // MARK: - Recognition Session

    private func startRecognitionSession() throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Remove existing tap if any
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    let text = result.bestTranscription.formattedString

                    // Layer 1: Block during avatar speech
                    if AudioService.shared.isSpeakingOrGrace {
                        return
                    }

                    // Layer 4: Content echo filter
                    if AudioService.shared.isAvatarEcho(text) {
                        return
                    }

                    self.transcript = text

                    if result.isFinal {
                        self.onTranscript?(text)
                        self.transcript = ""

                        // Auto-restart for continuous listening
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if self.isListening {
                                self.cancelRecognition()
                                do {
                                    try self.startRecognitionSession()
                                } catch {
                                    print("[SpeechService] Auto-restart failed: \(error)")
                                }
                            }
                        }
                    }
                }

                if let error {
                    print("[SpeechService] Recognition error: \(error.localizedDescription)")
                    // Auto-restart on error (like web's restartAfterErrorMs = 300ms)
                    if self.isListening {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.cancelRecognition()
                            do {
                                try self.startRecognitionSession()
                            } catch {
                                print("[SpeechService] Error restart failed: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }

    private func cancelRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
}
