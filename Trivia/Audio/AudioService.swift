import AVFoundation
import Foundation

@MainActor
class AudioService: ObservableObject {
    static let shared = AudioService()

    private var player: AVAudioPlayer?
    private var bgMusicPlayer: AVAudioPlayer?

    @Published var isPlaying = false
    @Published var currentWord: String = ""
    @Published var currentWordTimings: [WordTiming] = []

    /// True while audio is playing or within the grace period after playback ends.
    /// Used by SpeechService to gate mic input (echo suppression layer 1).
    var isSpeakingOrGrace: Bool {
        if isPlaying { return true }
        guard let end = speakEndTime else { return false }
        return Date().timeIntervalSince(end) < gracePeriodSeconds
    }

    /// Grace period after audio stops — blocks ASR to avoid echo (like web Layer 3)
    var gracePeriodSeconds: Double = 0.15

    /// Timestamp when last speech audio stopped playing
    private(set) var speakEndTime: Date?

    /// Recent words spoken by avatar — used for content-based echo filter (web Layer 4)
    private(set) var recentAvatarWords: Set<String> = []
    private var avatarWordTimers: [String: DispatchWorkItem] = [:]
    private let avatarWordTTL: TimeInterval = 2.0

    private var lipSyncTimer: Timer?
    private var lipSyncStartTime: Date?

    /// Completion callback fired when speech audio finishes
    var onSpeechComplete: (() -> Void)?

    /// Audio cache — maps text to pre-fetched audio data + timings
    private var audioCache: [String: (data: Data, timings: [WordTiming])] = [:]
    private let maxCacheSize = 60

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        #if os(iOS) || os(visionOS)
        do {
            // playAndRecord allows simultaneous mic input and audio output
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioService] Audio session error: \(error)")
        }
        #endif
    }

    // MARK: - TTS Playback (basic, no lip-sync)

    func playTTS(text: String, voice: String = "onyx") async {
        do {
            let data = try await APIService.shared.fetchTTS(text: text, voice: voice)
            try playAudioData(data)
        } catch {
            print("[AudioService] TTS playback error: \(error)")
        }
    }

    func playAudioData(_ data: Data) throws {
        player?.stop()

        // Fire any pending speech-complete callback before starting new audio.
        // This unblocks any speakAloud continuation that was waiting for the
        // previous playback to finish (prevents CheckedContinuation leaks when
        // a new speak interrupts an in-progress one).
        let pending = onSpeechComplete
        onSpeechComplete = nil
        pending?()

        player = try AVAudioPlayer(data: data)
        player?.delegate = AudioPlayerDelegate.shared
        player?.prepareToPlay()
        player?.play()
        isPlaying = true

        AudioPlayerDelegate.shared.onFinish = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handlePlaybackComplete()
            }
        }
    }

    func stopPlayback() {
        player?.stop()
        handlePlaybackComplete()
        currentWordTimings = []
        lipSyncTimer?.invalidate()
        lipSyncTimer = nil
    }

    private func handlePlaybackComplete() {
        isPlaying = false
        speakEndTime = Date()
        currentWord = ""
        lipSyncTimer?.invalidate()
        lipSyncTimer = nil
        onSpeechComplete?()
        onSpeechComplete = nil
    }

    // MARK: - Speak with Lip-Sync (Inworld TTS)

    /// Speaks text with lip-sync word timings via /api/speak.
    /// Returns the word timings array. Fires `onSpeechComplete` when audio finishes.
    @discardableResult
    func speakWithLipSync(text: String) async -> [WordTiming] {
        // Check cache first
        let cacheKey = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = audioCache[cacheKey] {
            currentWordTimings = cached.timings
            recordAvatarWords(text)
            do {
                try playAudioData(cached.data)
                startLipSyncTracking(timings: cached.timings)
                return cached.timings
            } catch {
                print("[AudioService] Cache playback failed: \(error)")
            }
        }

        do {
            let response = try await APIService.shared.speak(text: text)
            guard let audioData = response.audioData else {
                print("[AudioService] Failed to decode base64 audio from /api/speak")
                return []
            }
            let timings = response.wordTimings
            currentWordTimings = timings

            // Cache for reuse
            cacheAudio(key: cacheKey, data: audioData, timings: timings)

            recordAvatarWords(text)
            try playAudioData(audioData)
            startLipSyncTracking(timings: timings)

            return timings
        } catch {
            print("[AudioService] speakWithLipSync error: \(error)")
            // Fall back to regular TTS without lip-sync
            recordAvatarWords(text)
            await playTTS(text: text)
            return []
        }
    }

    // MARK: - Prefetch (cache TTS without playing)

    /// Pre-fetches TTS audio and caches it for instant playback later.
    func prefetch(text: String) {
        let cacheKey = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard audioCache[cacheKey] == nil else { return }

        Task {
            do {
                let response = try await APIService.shared.speak(text: text)
                guard let audioData = response.audioData else { return }
                cacheAudio(key: cacheKey, data: audioData, timings: response.wordTimings)
            } catch {
                // Prefetch failure is non-critical
            }
        }
    }

    private func cacheAudio(key: String, data: Data, timings: [WordTiming]) {
        if audioCache.count >= maxCacheSize {
            // Evict oldest entry
            if let first = audioCache.keys.first {
                audioCache.removeValue(forKey: first)
            }
        }
        audioCache[key] = (data: data, timings: timings)
    }

    // MARK: - Lip-Sync Tracking

    private func startLipSyncTracking(timings: [WordTiming]) {
        lipSyncTimer?.invalidate()
        lipSyncStartTime = Date()
        currentWord = ""

        lipSyncTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.lipSyncStartTime else { return }
                let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)

                if let active = timings.first(where: { elapsedMs >= $0.startMs && elapsedMs < $0.startMs + $0.durationMs }) {
                    if self.currentWord != active.word {
                        self.currentWord = active.word
                    }
                } else if elapsedMs > (timings.last?.startMs ?? 0) + (timings.last?.durationMs ?? 0) {
                    self.currentWord = ""
                    self.lipSyncTimer?.invalidate()
                    self.lipSyncTimer = nil
                }
            }
        }
    }

    // MARK: - Avatar Word Tracking (Echo Suppression Layer 4)

    /// Records words spoken by the avatar so ASR can filter echoes.
    private func recordAvatarWords(_ text: String) {
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 }

        for word in words {
            // Cancel previous expiry timer for this word
            avatarWordTimers[word]?.cancel()

            recentAvatarWords.insert(word)

            // Schedule removal after TTL
            let workItem = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    self?.recentAvatarWords.remove(word)
                    self?.avatarWordTimers.removeValue(forKey: word)
                }
            }
            avatarWordTimers[word] = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + avatarWordTTL, execute: workItem)
        }
    }

    /// Clears the avatar word cache. Call when the avatar finishes speaking a
    /// question so the user's answer words aren't falsely flagged as echoes.
    func clearAvatarWords() {
        avatarWordTimers.values.forEach { $0.cancel() }
        avatarWordTimers.removeAll()
        recentAvatarWords.removeAll()
    }

    /// Checks if a transcript is likely an echo of recent avatar speech (>70% word overlap).
    func isAvatarEcho(_ transcript: String) -> Bool {
        guard !recentAvatarWords.isEmpty else { return false }
        let words = transcript.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 }
        guard !words.isEmpty else { return false }

        let overlap = words.filter { recentAvatarWords.contains($0) }.count
        // Raised threshold to 0.7 so single answer words ("before", "after")
        // aren't blocked just because they appeared in the question text.
        return Double(overlap) / Double(words.count) > 0.7
    }

    // MARK: - Background Music

    func playBackgroundMusic(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        do {
            bgMusicPlayer = try AVAudioPlayer(contentsOf: url)
            bgMusicPlayer?.numberOfLoops = -1
            bgMusicPlayer?.volume = 0.15
            bgMusicPlayer?.play()
        } catch {
            print("[AudioService] Background music error: \(error)")
        }
    }

    func stopBackgroundMusic() {
        bgMusicPlayer?.stop()
        bgMusicPlayer = nil
    }
}

// MARK: - AVAudioPlayerDelegate Bridge

/// Singleton delegate to bridge AVAudioPlayerDelegate callbacks to closures.
private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
