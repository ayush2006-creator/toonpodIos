import RealityKit
import Foundation

// MARK: - AvatarAnimationController
//
// Works in two modes detected automatically on start():
//
//   RIGGED mode   — when named bones (Head, Jaw, RightArm…) are found in the
//                   entity hierarchy. Drives individual bones.
//
//   BONELESS mode — when the model is a single static mesh (e.g. just "Geom").
//                   Animates the whole entity with scale oscillation, position
//                   bob, and orientation tilts that read as gestures from camera.
//
// Bone name constants below only matter in rigged mode; they are ignored
// (with zero errors) when the model has no skeleton.

// MARK: - Bone name constants (edit to match your USDZ rig if it has bones)

enum BoneNames {
    static let root          = "Root"
    static let head          = "Head"
    static let neck          = "Neck"
    static let spine         = "Spine"
    static let jaw           = "Jaw"          // used by AvatarLipSyncController too

    static let rightArm      = "RightArm"
    static let rightForeArm  = "RightForeArm"
    static let rightHand     = "RightHand"
    static let leftArm       = "LeftArm"
    static let leftForeArm   = "LeftForeArm"
    static let leftHand      = "LeftHand"
    static let rightShoulder = "RightShoulder"
    static let leftShoulder  = "LeftShoulder"

    // Eyelid bones — silently ignored when absent
    static let eyelidTopLeft  = "EyelidTopLeft"
    static let eyelidTopRight = "EyelidTopRight"
}

// MARK: - Gesture enum

enum AvatarGesture: CaseIterable {
    case wave
    case pointUp
    case thumbsUp
    case shrug
    case thinkingRub
    case clap
}

// MARK: - Controller

@MainActor
final class AvatarAnimationController {

    private weak var entity: Entity?

    // Timers
    private var idleTimer:    Timer?
    private var blinkTimer:   Timer?
    private var gestureTimer: Timer?

    // Idle state
    private var idleTick: Double = 0
    private var isRunning = false

    // ── Rigged-mode state ─────────────────────────────────────────
    private var hasBones = false
    private var headRestOrientation: simd_quatf = .init(ix: 0, iy: 0, iz: 0, r: 1)

    // ── Boneless-mode state ───────────────────────────────────────
    // Base transform captured once so animations can offset from it
    private var basePosition:    SIMD3<Float>    = .zero
    private var baseScale:       SIMD3<Float>    = [1, 1, 1]
    private var baseOrientation: simd_quatf      = .init(ix: 0, iy: 0, iz: 0, r: 1)

    // MARK: - Start / Stop

    func start(with entity: Entity) {
        self.entity  = entity
        isRunning    = true

        // Detect rig type
        hasBones = entity.findEntity(named: BoneNames.head) != nil

        if hasBones {
            if let head = entity.findEntity(named: BoneNames.head) {
                headRestOrientation = head.orientation
            }
        } else {
            // Store the entity's resting transform so gestures can return to it
            basePosition    = entity.position
            baseScale       = entity.scale
            baseOrientation = entity.orientation
        }

        startIdleLoop()
        scheduleNextBlink()
    }

    func stop() {
        isRunning = false
        idleTimer?.invalidate()
        blinkTimer?.invalidate()
        gestureTimer?.invalidate()
        idleTimer    = nil
        blinkTimer   = nil
        gestureTimer = nil
    }

    // MARK: - gestureForPhase

    static func gestureForPhase(_ phase: GamePhase) -> AvatarGesture? {
        switch phase {
        case .briefing:        return .wave
        case .askingQuestion:  return .pointUp
        case .suspense:        return .thinkingRub
        case .revealingAnswer: return .thumbsUp
        case .reacting:        return .shrug
        case .gameFarewell:    return .clap
        case .explaining, .transitioning, .waitingForAnswer, .idle: return nil
        }
    }

    // MARK: - Idle Loop (30 fps)

    private func startIdleLoop() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tickIdle() }
        }
    }

    private func tickIdle() {
        guard let entity, isRunning else { return }
        idleTick += 1.0 / 30.0

        if hasBones {
            tickIdleBoned(entity)
        } else {
            tickIdleBoneless(entity)
        }
    }

    // Rigged: animate individual bones
    private func tickIdleBoned(_ entity: Entity) {
        let breath = Float(sin(idleTick * 0.4 * .pi))
        if let root = entity.findEntity(named: BoneNames.root) {
            root.scale = [1.0 + breath * 0.012, 1.0 + breath * 0.008, 1.0 + breath * 0.012]
        }
        let bobZ = Float(sin(idleTick * 0.18 * .pi)) * 0.012
        let bobY = Float(sin(idleTick * 0.25 * .pi)) * 0.006
        if let head = entity.findEntity(named: BoneNames.head) {
            let tilt = simd_quatf(angle: bobZ, axis: [1, 0, 0])
            let roll = simd_quatf(angle: bobY, axis: [0, 0, 1])
            head.orientation = headRestOrientation * tilt * roll
        }
    }

    // Boneless: only touch scale + position.y so gestures (orientation) and
    // lip-sync (orientation) can run independently without fighting this loop.
    private func tickIdleBoneless(_ entity: Entity) {
        // Subtle breathing — ±1.5% scale, slow 4-second cycle.
        // Looks like a still model gently breathing rather than bouncing.
        let breath = Float(sin(idleTick * 0.25 * .pi))  // 4 s cycle
        entity.scale = SIMD3<Float>(
            baseScale.x * (1.0 + breath * 0.015),
            baseScale.y * (1.0 + breath * 0.008),
            baseScale.z * (1.0 + breath * 0.015)
        )
        // No position bob or orientation change here — both are owned by
        // lip-sync and gesture systems respectively.
    }

    // MARK: - Eye Blink (silently skipped on boneless models)

    private func scheduleNextBlink() {
        guard isRunning else { return }
        let delay = Double.random(in: 2.5...6.0)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performBlink()
                if Int.random(in: 0..<5) == 0 { self?.performBrowRaise() }
                self?.scheduleNextBlink()
            }
        }
    }

    private func performBlink() {
        guard hasBones, let entity else { return }
        let angle: Float = .pi / 2.2
        rotateBone(BoneNames.eyelidTopLeft,  in: entity, angle:  angle, axis: [1, 0, 0])
        rotateBone(BoneNames.eyelidTopRight, in: entity, angle: -angle, axis: [1, 0, 0])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self, weak entity] in
            guard let self, let entity else { return }
            self.rotateBone(BoneNames.eyelidTopLeft,  in: entity, angle: 0, axis: [1, 0, 0])
            self.rotateBone(BoneNames.eyelidTopRight, in: entity, angle: 0, axis: [1, 0, 0])
        }
    }

    private func performBrowRaise() {
        guard let head = entity?.findEntity(named: BoneNames.head) else { return }
        let rest = head.orientation
        let tilt = simd_quatf(angle: -0.08, axis: [1, 0, 0]) * rest
        head.move(to: Transform(scale: head.scale, rotation: tilt, translation: head.position),
                  relativeTo: head.parent, duration: 0.15)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak head, rest] in
            head?.move(to: Transform(scale: head?.scale ?? [1,1,1], rotation: rest,
                                     translation: head?.position ?? .zero),
                       relativeTo: head?.parent, duration: 0.2)
        }
    }

    // MARK: - Gesture dispatcher

    func playGesture(_ gesture: AvatarGesture) {
        guard let entity, isRunning else { return }
        gestureTimer?.invalidate()

        if hasBones {
            playGestureBoned(gesture, entity: entity)
        } else {
            playGestureBoneless(gesture, entity: entity)
        }
    }

    // MARK: - Rigged gestures

    private func playGestureBoned(_ gesture: AvatarGesture, entity: Entity) {
        switch gesture {
        case .wave:        playWave(entity)
        case .pointUp:     playPointUp(entity)
        case .thumbsUp:    playThumbsUp(entity)
        case .shrug:       playShrug(entity)
        case .thinkingRub: playThinkingRub(entity)
        case .clap:        playClap(entity)
        }
    }

    private func playWave(_ entity: Entity) {
        guard let arm = entity.findEntity(named: BoneNames.rightArm),
              let foreArm = entity.findEntity(named: BoneNames.rightForeArm) else { return }
        let restArm = arm.orientation; let restFore = foreArm.orientation
        arm.move(to: Transform(scale: arm.scale,
                               rotation: simd_quatf(angle: -.pi / 2.2, axis: [0, 0, 1]) * restArm,
                               translation: arm.position), relativeTo: arm.parent, duration: 0.3)
        var delay = 0.3
        for angle: Float in [0.3, -0.3, 0.3, -0.3, 0.0] {
            let t = delay
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak foreArm, restFore] in
                foreArm?.move(to: Transform(scale: foreArm?.scale ?? [1,1,1],
                                            rotation: simd_quatf(angle: angle, axis: [1,0,0]) * restFore,
                                            translation: foreArm?.position ?? .zero),
                              relativeTo: foreArm?.parent, duration: 0.25)
            }
            delay += 0.25
        }
        gestureTimer = Timer.scheduledTimer(withTimeInterval: delay + 0.3, repeats: false) { [weak arm, restArm] _ in
            arm?.move(to: Transform(scale: arm?.scale ?? [1,1,1], rotation: restArm,
                                    translation: arm?.position ?? .zero), relativeTo: arm?.parent, duration: 0.3)
        }
    }

    private func playPointUp(_ entity: Entity) {
        guard let arm = entity.findEntity(named: BoneNames.rightArm) else { return }
        let rest = arm.orientation
        arm.move(to: Transform(scale: arm.scale, rotation: simd_quatf(angle: -.pi/1.8, axis:[0,0,1]) * rest,
                               translation: arm.position), relativeTo: arm.parent, duration: 0.35)
        restoreAfter(duration: 1.2, entity: arm, restOrientation: rest)
    }

    private func playThumbsUp(_ entity: Entity) {
        guard let arm = entity.findEntity(named: BoneNames.rightArm) else { return }
        let rest = arm.orientation
        arm.move(to: Transform(scale: arm.scale, rotation: simd_quatf(angle: -.pi/3.0, axis:[0,0,1]) * rest,
                               translation: arm.position), relativeTo: arm.parent, duration: 0.3)
        restoreAfter(duration: 1.0, entity: arm, restOrientation: rest)
    }

    private func playShrug(_ entity: Entity) {
        guard let r = entity.findEntity(named: BoneNames.rightShoulder),
              let l = entity.findEntity(named: BoneNames.leftShoulder) else { return }
        let rR = r.orientation; let lR = l.orientation
        r.move(to: Transform(scale: r.scale, rotation: simd_quatf(angle: -.pi/6, axis:[0,0,1]) * rR, translation: r.position), relativeTo: r.parent, duration: 0.3)
        l.move(to: Transform(scale: l.scale, rotation: simd_quatf(angle:  .pi/6, axis:[0,0,1]) * lR, translation: l.position), relativeTo: l.parent, duration: 0.3)
        gestureTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak r, weak l, rR, lR] _ in
            Task { @MainActor in
                r?.move(to: Transform(scale: r?.scale ?? [1,1,1], rotation: rR, translation: r?.position ?? .zero), relativeTo: r?.parent, duration: 0.3)
                l?.move(to: Transform(scale: l?.scale ?? [1,1,1], rotation: lR, translation: l?.position ?? .zero), relativeTo: l?.parent, duration: 0.3)
            }
        }
    }

    private func playThinkingRub(_ entity: Entity) {
        guard let arm = entity.findEntity(named: BoneNames.rightArm),
              let fore = entity.findEntity(named: BoneNames.rightForeArm) else { return }
        let rA = arm.orientation; let rF = fore.orientation
        arm.move(to:  Transform(scale: arm.scale,  rotation: simd_quatf(angle: -.pi/3.5, axis:[0,0,1]) * rA,  translation: arm.position),  relativeTo: arm.parent,  duration: 0.35)
        fore.move(to: Transform(scale: fore.scale, rotation: simd_quatf(angle: -.pi/2.4, axis:[0,1,0]) * rF,  translation: fore.position), relativeTo: fore.parent, duration: 0.35)
        restoreAfter(duration: 1.8, entity: arm,  restOrientation: rA)
        restoreAfter(duration: 1.8, entity: fore, restOrientation: rF)
    }

    private func playClap(_ entity: Entity) {
        guard let rArm = entity.findEntity(named: BoneNames.rightArm),
              let lArm = entity.findEntity(named: BoneNames.leftArm) else { return }
        let rR = rArm.orientation; let lR = lArm.orientation
        for i in 0..<3 {
            let t = Double(i) * 0.35; let a = t + 0.18
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak rArm, weak lArm, rR, lR] in
                rArm?.move(to: Transform(scale: rArm?.scale ?? [1,1,1], rotation: simd_quatf(angle: -.pi/4, axis:[0,0,1]) * rR, translation: rArm?.position ?? .zero), relativeTo: rArm?.parent, duration: 0.15)
                lArm?.move(to: Transform(scale: lArm?.scale ?? [1,1,1], rotation: simd_quatf(angle:  .pi/4, axis:[0,0,1]) * lR, translation: lArm?.position ?? .zero), relativeTo: lArm?.parent, duration: 0.15)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + a) { [weak rArm, weak lArm, rR, lR] in
                rArm?.move(to: Transform(scale: rArm?.scale ?? [1,1,1], rotation: rR, translation: rArm?.position ?? .zero), relativeTo: rArm?.parent, duration: 0.15)
                lArm?.move(to: Transform(scale: lArm?.scale ?? [1,1,1], rotation: lR, translation: lArm?.position ?? .zero), relativeTo: lArm?.parent, duration: 0.15)
            }
        }
    }

    // MARK: - Boneless gestures (whole-entity tilts)

    private func playGestureBoneless(_ gesture: AvatarGesture, entity: Entity) {
        let rest = baseOrientation
        // Gestures only touch `orientation` — idle loop uses scale+position,
        // so there is no frame-by-frame conflict.
        var angle:    Float          = 0
        var axis:     SIMD3<Float>   = [0, 1, 0]
        var holdSecs: Double         = 1.2

        switch gesture {
        case .wave:
            animateRockBoneless(entity: entity, axis: [0, 0, 1], peakAngle: 0.22, reps: 3)
            return
        case .pointUp:
            angle = -0.18; axis = [1, 0, 0]; holdSecs = 1.4   // lean back ~10°
        case .thumbsUp:
            angle =  0.15; axis = [1, 0, 0]; holdSecs = 1.2   // lean forward ~9°
        case .shrug:
            animateRockBoneless(entity: entity, axis: [0, 0, 1], peakAngle: 0.10, reps: 1)
            return
        case .thinkingRub:
            angle =  0.18; axis = [0, 0, 1]; holdSecs = 1.8   // tilt right ~10°
        case .clap:
            animateRockBoneless(entity: entity, axis: [1, 0, 0], peakAngle: 0.12, reps: 3)
            return
        }

        let target = simd_quatf(angle: angle, axis: axis) * rest
        entity.move(
            to: Transform(scale: entity.scale, rotation: target, translation: entity.position),
            relativeTo: entity.parent, duration: 0.35, timingFunction: .easeInOut
        )
        gestureTimer = Timer.scheduledTimer(withTimeInterval: holdSecs, repeats: false) { [weak self, weak entity, rest] _ in
            Task { @MainActor in
                entity?.move(
                    to: Transform(scale: entity?.scale ?? [1,1,1], rotation: rest,
                                  translation: entity?.position ?? .zero),
                    relativeTo: entity?.parent, duration: 0.35, timingFunction: .easeOut
                )
                self?.gestureTimer = nil
            }
        }
    }

    private func animateRockBoneless(entity: Entity, axis: SIMD3<Float>, peakAngle: Float, reps: Int) {
        let rest = baseOrientation
        var delay: Double = 0
        let step:  Double = 0.25
        for i in 0..<(reps * 2) {
            let d = delay
            let a: Float = (i % 2 == 0) ? peakAngle : -peakAngle
            DispatchQueue.main.asyncAfter(deadline: .now() + d) { [weak entity, rest] in
                let q = simd_quatf(angle: a, axis: axis) * rest
                entity?.move(
                    to: Transform(scale: entity?.scale ?? [1,1,1], rotation: q,
                                  translation: entity?.position ?? .zero),
                    relativeTo: entity?.parent, duration: step, timingFunction: .easeInOut
                )
            }
            delay += step
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) { [weak entity, rest] in
            entity?.move(
                to: Transform(scale: entity?.scale ?? [1,1,1], rotation: rest,
                              translation: entity?.position ?? .zero),
                relativeTo: entity?.parent, duration: 0.3, timingFunction: .easeOut
            )
        }
    }

    // MARK: - Helpers

    private func rotateBone(_ name: String, in root: Entity, angle: Float, axis: SIMD3<Float>) {
        guard let bone = root.findEntity(named: name) else { return }
        let rest = bone.orientation
        let target = angle == 0 ? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                                : simd_quatf(angle: angle, axis: axis) * rest
        bone.move(to: Transform(scale: bone.scale, rotation: target, translation: bone.position),
                  relativeTo: bone.parent, duration: 0.06)
    }

    private func restoreAfter(duration: Double, entity: Entity, restOrientation: simd_quatf) {
        gestureTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak entity, restOrientation] _ in
            Task { @MainActor in
                entity?.move(to: Transform(scale: entity?.scale ?? [1,1,1],
                                           rotation: restOrientation,
                                           translation: entity?.position ?? .zero),
                             relativeTo: entity?.parent, duration: 0.3)
            }
        }
    }
}
