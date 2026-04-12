import RealityKit
import Foundation

// MARK: - AvatarLipSyncController
//
// Drives mouth animation in sync with TTS audio.
//
// RIGGED mode   — rotates the jaw bone found via SkeletonResolver.
//                 Works with MetaHuman (FACIAL_C_Jaw), Mixamo, CC4, and generic rigs.
// BONELESS mode — drives a rapid pitch oscillation on the whole entity that
//                 reads as talking from the game camera distance.
//
// Two timing paths:
//   1. Word-timing  — AudioService.currentWordTimings (server timestamps)
//   2. Character-rate fallback — ~60 ms per character

@MainActor
final class AvatarLipSyncController {

    private weak var entity: Entity?
    private var lerpTimer: Timer?

    // Jaw bone
    private var hasJaw = false
    private var jawRestOrientation: simd_quatf = .init(ix: 0, iy: 0, iz: 0, r: 1)
    private let maxJawAngle: Float = 0.44   // ~25° at openness = 1

    // Shared smooth openness  (0 = closed → 1 = fully open)
    private var targetOpenness:  Float = 0
    private var currentOpenness: Float = 0
    private let lerpRate:        Float = 0.22

    // Boneless lip-sync oscillator
    private var lipTick: Double = 0

    // Base orientation captured on attach (so lip sway is additive)
    private var baseOrientation: simd_quatf = .init(ix: 0, iy: 0, iz: 0, r: 1)

    // MARK: - Attach

    func attach(to entity: Entity) {
        self.entity     = entity
        baseOrientation = entity.orientation

        if let _ = SkeletonResolver.find(SkeletonResolver.jaw, in: entity) {
            hasJaw = true
            if let jaw = SkeletonResolver.find(SkeletonResolver.jaw, in: entity) {
                jawRestOrientation = jaw.orientation
            }
            let detectedName = SkeletonResolver.detectedName(SkeletonResolver.jaw, in: entity) ?? "?"
            print("[LipSync] ✅ Jaw bone found: '\(detectedName)'")
        } else {
            hasJaw = false
            print("[LipSync] ⚠️ No jaw bone found — boneless lip-sync active")
        }
    }

    // MARK: - Speak

    func speak(text: String, wordTimings: [WordTiming]) {
        stopLipSync()
        startLerpLoop()

        if wordTimings.isEmpty {
            scheduleCharacterRate(text: text)
        } else {
            scheduleWordTimings(wordTimings)
        }
    }

    // MARK: - Stop

    func stopLipSync() {
        lerpTimer?.invalidate()
        lerpTimer      = nil
        targetOpenness = 0
        lipTick        = 0
    }

    // MARK: - 30 fps lerp loop

    private func startLerpLoop() {
        lerpTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tickLerp() }
        }
    }

    private func tickLerp() {
        guard let entity else { return }
        currentOpenness += (targetOpenness - currentOpenness) * lerpRate

        if hasJaw {
            applyJawRotation(entity: entity)
        } else {
            applyBonelessLipSync(entity: entity)
        }
    }

    // MARK: - Word-timing scheduler

    private func scheduleWordTimings(_ timings: [WordTiming]) {
        for timing in timings {
            let delay      = Double(timing.startMs) / 1000.0
            let closeDelay = delay + Double(timing.durationMs) / 1000.0 * 0.85

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.targetOpenness = Self.opennessForWord(timing.word)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay) { [weak self] in
                self?.targetOpenness = 0
            }
        }
    }

    // MARK: - Character-rate fallback (~60 ms / char)

    private func scheduleCharacterRate(text: String) {
        let msPerChar: Double = 60
        var offset: Double   = 0

        for char in text {
            let delay      = offset
            let closeDelay = delay + msPerChar * 0.7
            DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000.0) { [weak self] in
                self?.targetOpenness = Self.opennessForCharacter(char)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay / 1000.0) { [weak self] in
                self?.targetOpenness = 0
            }
            offset += msPerChar
        }
        let total = msPerChar * Double(text.count) + 300
        DispatchQueue.main.asyncAfter(deadline: .now() + total / 1000.0) { [weak self] in
            self?.stopLipSync()
        }
    }

    // MARK: - Openness heuristic

    private static func opennessForWord(_ word: String) -> Float {
        guard let first = word.lowercased().first else { return 0.15 }
        return opennessForCharacter(first)
    }

    private static func opennessForCharacter(_ ch: Character) -> Float {
        let c = ch.lowercased().first ?? ch
        switch c {
        case "a", "e":                   return 0.90
        case "i":                        return 0.55
        case "o":                        return 0.70
        case "u", "w":                   return 0.35
        case "b", "m", "p":              return 0.00
        case "t", "d", "n", "l":         return 0.30
        case "f", "v":                   return 0.15
        case "s", "z":                   return 0.20
        case "r":                        return 0.25
        case "k", "g", "h":              return 0.40
        case " ", ".", ",", "!", "?":    return 0.00
        default:                         return 0.15
        }
    }

    // MARK: - Jaw bone application (rigged)

    private func applyJawRotation(entity: Entity) {
        guard let jaw = SkeletonResolver.find(SkeletonResolver.jaw, in: entity) else { return }
        let angle = currentOpenness * maxJawAngle
        jaw.orientation = simd_quatf(angle: angle, axis: [1, 0, 0]) * jawRestOrientation
    }

    // MARK: - Boneless lip-sync application

    // Drives a rapid pitch oscillation proportional to openness.
    // Idle loop only touches entity.scale so orientation is safe to own here.
    private func applyBonelessLipSync(entity: Entity) {
        if currentOpenness < 0.02 {
            entity.orientation = baseOrientation
            lipTick = 0
            return
        }
        lipTick += 1.0 / 30.0
        // 6 Hz pitch micro-movement — reads as talking from game camera distance.
        let wobble = Float(sin(lipTick * 6.0 * .pi)) * currentOpenness * 0.04
        entity.orientation = simd_quatf(angle: wobble, axis: [1, 0, 0]) * baseOrientation
    }
}
