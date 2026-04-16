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
    @Published var isAvailable: Bool = false
    @Published var lastError: String = ""

    /// Callback when a final transcript is recognized
    var onTranscript: ((String) -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Set when startListening() is called but recognizer wasn't ready yet.
    /// The delegate will auto-start when availability flips to true.
    private var wantsToListen = false
    private var transcriptDebounceTimer: Timer?

    /// Bridge delegate (SFSpeechRecognizerDelegate is not @MainActor).
    private lazy var recognizerDelegate = SpeechRecognizerDelegate { [weak self] available in
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isAvailable = available
            print("[SpeechService] Availability changed → \(available)")
            if available && self.wantsToListen && !self.isListening {
                self.attemptStart()
            }
        }
    }

    init() {
        speechRecognizer?.delegate = recognizerDelegate
        isAvailable = speechRecognizer?.isAvailable == true
    }

    // MARK: - Authorization

    func requestAuthorization() {
        #if os(iOS) || os(visionOS)
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        #endif

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAuthorized = (status == .authorized)
                print("[SpeechService] Authorization status: \(status.rawValue)")
                // If we were waiting for auth to start, try now
                if status == .authorized && self.wantsToListen && !self.isListening {
                    self.attemptStart()
                }
            }
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        wantsToListen = true
        isAvailable = speechRecognizer?.isAvailable == true

        guard isAuthorized else {
            lastError = "not authorized"
            print("[SpeechService] Not authorized — will start when auth granted")
            return
        }
        guard !isListening else { return }

        // Do NOT gate on isAvailable — the property can stay false even when
        // the recognizer works fine (e.g. iOS 18 server-side check delay).
        // Just attempt to start; the recognition task will error if truly broken.
        attemptStart()
    }

    func stopListening() {
        wantsToListen = false
        transcriptDebounceTimer?.invalidate()
        transcriptDebounceTimer = nil
        cancelRecognition()
        isListening = false
        transcript = ""
        lastError = ""
    }

    // MARK: - Internal start

    private func attemptStart() {
        guard isAuthorized, !isListening else { return }
        cancelRecognition()

        do {
            try startRecognitionSession()
            isListening = true
            lastError = ""
            print("[SpeechService] ✅ Mic started")
        } catch {
            lastError = error.localizedDescription
            print("[SpeechService] Failed to start: \(error)")
        }
    }

    // MARK: - Flush (Echo Suppression Layer 2)

    func flushAndRestart() {
        guard isListening else { return }
        cancelRecognition()
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

    func matchAnswer(transcript: String, options: [String]) async -> String? {
        if AudioService.shared.isSpeakingOrGrace {
            print("[SpeechService] matchAnswer blocked: avatar speaking/grace")
            return nil
        }
        if AudioService.shared.isAvatarEcho(transcript) {
            print("[SpeechService] matchAnswer blocked: echo '\(transcript)'")
            return nil
        }
        if let local = fuzzyMatch(transcript: transcript, options: options) {
            print("[SpeechService] Local match: '\(local)' for transcript '\(transcript)'")
            return local
        }
        print("[SpeechService] No local match for '\(transcript)' in \(options) — calling API")
        do {
            let result = try await APIService.shared.matchAnswer(transcript: transcript, options: options)
            print("[SpeechService] API match result: \(result ?? "nil")")
            return result
        } catch {
            print("[SpeechService] API match error: \(error)")
            return nil
        }
    }

    // MARK: - Local Fuzzy Matching

    /// Natural-language filler prefixes ASR commonly produces — strip before matching.
    private let fillerPrefixes = [
        "i think it's", "i think its", "i think the answer is", "i think",
        "i believe it's", "i believe its", "i believe",
        "i'll go with", "i'll say", "i'll choose", "i'll pick",
        "i would say", "i would go with",
        "my answer is", "my guess is",
        "the answer is", "the answer would be",
        "it's", "its", "it is",
        "i choose", "i pick", "i say",
        "option", "letter", "number",
        "definitely", "probably", "maybe",
    ]

    private func stripFiller(_ text: String) -> String {
        var t = text
        // Try stripping each prefix (longest first to avoid partial stripping)
        for prefix in fillerPrefixes.sorted(by: { $0.count > $1.count }) {
            if t.hasPrefix(prefix + " ") {
                t = String(t.dropFirst(prefix.count + 1)).trimmingCharacters(in: .whitespaces)
            } else if t == prefix {
                t = ""
            }
        }
        return t
    }

    private func fuzzyMatch(transcript: String, options: [String]) -> String? {
        let raw = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        // Try both the raw transcript and the filler-stripped version
        let candidates = [raw, stripFiller(raw)].filter { !$0.isEmpty }

        for t in candidates {
            // 1. Exact match
            for opt in options { if opt.lowercased() == t { return opt } }

            // 2. Substring match (option contains transcript or vice-versa)
            for opt in options {
                let low = opt.lowercased()
                if low.contains(t) || t.contains(low) { return opt }
            }
        }

        // 3. Letter label: "a" / "b" / "c" / "d" (raw or stripped)
        let labels = ["a", "b", "c", "d"]
        for t in candidates {
            for (i, label) in labels.enumerated() where i < options.count {
                if t == label || t == "option \(label)" || t == "letter \(label)"
                    || t == "\(label)." || t.hasPrefix("\(label) ") {
                    return options[i]
                }
            }
        }

        // 4. Binary / true-false / before-after shortcuts
        let binaryTrue  = ["before", "true", "yes", "first", "one"]
        let binaryFalse = ["after", "false", "no", "second", "two"]
        if options.count == 2 {
            for t in candidates {
                if binaryTrue.contains(t)  { return options[0] }
                if binaryFalse.contains(t) { return options[1] }
            }
        }

        // 5. Word overlap (requires ≥ 2 shared meaningful words)
        var bestMatch: String?
        var bestScore = 0
        for t in candidates {
            for opt in options {
                let score = wordOverlapScore(t, opt.lowercased())
                if score > bestScore { bestScore = score; bestMatch = opt }
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
                    if AudioService.shared.isSpeakingOrGrace { return }
                    if AudioService.shared.isAvatarEcho(text) { return }

                    self.transcript = text

                    if result.isFinal {
                        // isFinal is reliable — fire immediately
                        self.transcriptDebounceTimer?.invalidate()
                        self.transcriptDebounceTimer = nil
                        self.onTranscript?(text)
                        self.transcript = ""

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            guard self.isListening else { return }
                            self.cancelRecognition()
                            do { try self.startRecognitionSession() }
                            catch { print("[SpeechService] Auto-restart failed: \(error)") }
                        }
                    } else {
                        // Debounce: treat stable partial as final after 0.8s of silence.
                        // On real devices isFinal often never fires before the session errors.
                        // Use capturedText (locked at schedule time) — do NOT re-read self.transcript
                        // at fire time. stopListening() clears self.transcript which would silently
                        // discard a valid answer if it races with the timer Task dispatch.
                        let capturedText = text
                        self.transcriptDebounceTimer?.invalidate()
                        self.transcriptDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                            Task { @MainActor [weak self] in
                                guard let self, !capturedText.isEmpty else { return }
                                print("[SpeechService] Debounce fired: '\(capturedText)' | handler=\(self.onTranscript != nil)")
                                self.onTranscript?(capturedText)
                                self.transcript = ""
                            }
                        }
                    }
                }

                if let error {
                    let code = (error as NSError).code
                    print("[SpeechService] Recognition error \(code): \(error.localizedDescription)")
                    // code 1110 = no speech detected — normal, just restart
                    guard self.isListening else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.cancelRecognition()
                        do { try self.startRecognitionSession() }
                        catch { print("[SpeechService] Error restart failed: \(error)") }
                    }
                }
            }
        }
    }

    private func cancelRecognition() {
        // NOTE: intentionally NOT cancelling transcriptDebounceTimer here.
        // A session error (e.g. 1101 audio interruption) will trigger cancelRecognition + restart,
        // but the user's recognized partial should still fire after the debounce delay.
        // Only stopListening() (explicit voice-off) should discard the pending answer.
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

// MARK: - Delegate bridge (SFSpeechRecognizerDelegate is not @MainActor)

private class SpeechRecognizerDelegate: NSObject, SFSpeechRecognizerDelegate {
    private let onAvailabilityChange: (Bool) -> Void

    init(_ onChange: @escaping (Bool) -> Void) {
        self.onAvailabilityChange = onChange
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        onAvailabilityChange(available)
    }
}
