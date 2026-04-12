import SwiftUI
import RealityKit
import Combine

// MARK: - AvatarRealityView
// Used ONLY in AvatarGamePanel (quiz screen) — NOT on the avatar selection screen.
// • Camera at y=1.15, z=1.8 (FOV 50°) → chest-to-head upper-body framing
// • Plays all baked USDZ animations on load
// • Dual directional lighting (key + warm fill)
// • Prints full entity/bone tree to Xcode console on first load
//   → search "[AvatarReality] •" to find exact jaw/eyelid bone names

struct AvatarRealityView: View {
    let modelName: String
    /// Y-axis rotation in degrees to apply after load (corrects facing direction).
    var yRotationDegrees: Float = 0
    /// Receives the loaded entity so animation / lip-sync controllers can grab it
    var onEntityLoaded: ((Entity) -> Void)?

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 1 && geo.size.height > 1 {
                #if os(iOS) || os(visionOS)
                AvatarRealityContainer(
                    modelName: modelName,
                    yRotationDegrees: yRotationDegrees,
                    onEntityLoaded: onEntityLoaded
                )
                .frame(width: geo.size.width, height: geo.size.height)
                #else
                ZStack {
                    Color.purple.opacity(0.1)
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.purple.opacity(0.5))
                }
                #endif
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - UIViewRepresentable container (iOS / visionOS only)

#if os(iOS) || os(visionOS)
struct AvatarRealityContainer: UIViewRepresentable {
    let modelName: String
    var yRotationDegrees: Float = 0
    var onEntityLoaded: ((Entity) -> Void)?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Non-AR, transparent background
        arView.cameraMode = .nonAR
        arView.environment.background = .color(.clear)
        arView.backgroundColor = .clear

        // Performance options
        arView.renderOptions = [
            .disableMotionBlur,
            .disableDepthOfField,
            .disablePersonOcclusion,
            .disableGroundingShadows,
            .disableFaceMesh,
        ]

        // ── Lighting ──────────────────────────────────────────────
        // Key / directional light (from front-top-right)
        let directional = DirectionalLight()
        directional.light.intensity = 2500
        directional.light.color = UIColor.white
        directional.look(at: [0, 0.5, 0], from: [1.5, 3.0, 2.0], relativeTo: nil)

        // Soft fill light (opposite side, warm)
        let fill = DirectionalLight()
        fill.light.intensity = 800
        fill.light.color = UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0)
        fill.look(at: [0, 0.5, 0], from: [-2.0, 2.0, -1.0], relativeTo: nil)

        let lightAnchor = AnchorEntity(world: .zero)
        lightAnchor.addChild(directional)
        lightAnchor.addChild(fill)
        arView.scene.addAnchor(lightAnchor)

        // ── Model anchor ──────────────────────────────────────────
        let anchor = AnchorEntity()
        context.coordinator.anchor = anchor
        arView.scene.addAnchor(anchor)

        loadModel(into: anchor, arView: arView, coordinator: context.coordinator)

        // ── Camera — upper-body crop, zoomed out ─────────────────
        // y=1.15, z=1.8 frames from chest to head of a 1.5-unit model.
        // Bump cameraPosition.z further (e.g. 2.2) if still too close,
        // or raise cameraPosition.y (e.g. 1.4) to cut off more of the legs.
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 50          // wider FOV = more relaxed framing
        let cameraPosition = SIMD3<Float>(0, 1.15, 1.8)
        camera.position = cameraPosition
        camera.look(at: [0, 0.95, 0], from: cameraPosition, relativeTo: nil)

        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(camera)
        arView.scene.addAnchor(cameraAnchor)

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        // No per-frame updates needed — animation controller drives entity directly
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Model loading

    private func loadModel(into anchor: AnchorEntity, arView: ARView, coordinator: Coordinator) {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "usdz")
                     ?? Bundle.main.url(forResource: modelName, withExtension: "reality")
        else {
            print("[AvatarReality] '\(modelName).usdz' not found in bundle — using placeholder")
            createPlaceholder(into: anchor, coordinator: coordinator)
            return
        }

        Task {
            do {
                let entity = try await ModelEntity(contentsOf: url)
                await MainActor.run {
                    // Auto-scale so tallest dimension = 1.5 units
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                    guard maxDim > 0 else { return }
                    let scale = 1.5 / maxDim
                    entity.scale = [scale, scale, scale]

                    // Sit on ground plane (y = 0)
                    let scaledBounds = entity.visualBounds(relativeTo: nil)
                    entity.position.y = -scaledBounds.min.y

                    // Apply per-model facing correction BEFORE handing entity to controllers
                    // so their captured baseOrientation already reflects the corrected pose.
                    if yRotationDegrees != 0 {
                        entity.orientation = simd_quatf(angle: yRotationDegrees * .pi / 180, axis: [0, 1, 0])
                        print("[AvatarReality] Applied \(yRotationDegrees)° Y-rotation to '\(modelName)'")
                    }

                    entity.generateCollisionShapes(recursive: true)
                    anchor.addChild(entity)
                    coordinator.modelEntity = entity

                    // Play every baked animation from the USDZ (idle cycles, blendshapes…)
                    for anim in entity.availableAnimations {
                        entity.playAnimation(anim.repeat(), transitionDuration: 0.3, startsPaused: false)
                    }

                    // ── Print bone/entity names for debugging ─────────────
                    print("[AvatarReality] '\'\(modelName)\'' entity tree:")
                    Self.printEntityTree(entity, indent: 0)
                    // ─────────────────────────────────────────────────────

                    print("[AvatarReality] Loaded '\(modelName)' — \(entity.availableAnimations.count) anim(s)")
                    onEntityLoaded?(entity)
                }
            } catch {
                print("[AvatarReality] Load error: \(error)")
                await MainActor.run { createPlaceholder(into: anchor, coordinator: coordinator) }
            }
        }
    }

    // MARK: - Procedural placeholder (when no USDZ)

    private func createPlaceholder(into anchor: AnchorEntity, coordinator: Coordinator) {
        let root = ModelEntity()

        func mat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, roughness: Float = 0.4) -> SimpleMaterial {
            var m = SimpleMaterial()
            m.color = .init(tint: .init(red: r, green: g, blue: b, alpha: 1))
            m.roughness = .float(roughness)
            return m
        }

        let head = ModelEntity(mesh: .generateSphere(radius: 0.25), materials: [mat(0.6, 0.4, 0.9)])
        head.name = "Head"
        head.position = [0, 1.1, 0]

        let body = ModelEntity(mesh: .generateBox(size: [0.5, 0.7, 0.3], cornerRadius: 0.08),
                               materials: [mat(0.3, 0.2, 0.6)])
        body.position = [0, 0.5, 0]

        for child in [head, body] as [ModelEntity] { root.addChild(child) }
        anchor.addChild(root)
        coordinator.modelEntity = root
        onEntityLoaded?(root)
    }

    // MARK: - Coordinator

    class Coordinator {
        var anchor: AnchorEntity?
        var modelEntity: Entity?
    }

    // MARK: - Debug helper: print full entity/bone tree to Xcode console

    /// Recursively prints every entity name in the hierarchy.
    /// After launching, search the Xcode console for "[AvatarReality]" to find
    /// the exact jaw / eyelid / arm bone names for your USDZ rig.
    static func printEntityTree(_ entity: Entity, indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        let tag = entity.name.isEmpty ? "<unnamed>" : entity.name
        print("[AvatarReality] \(prefix)• \(tag)")
        for child in entity.children {
            printEntityTree(child, indent: indent + 1)
        }
    }
}
#endif
