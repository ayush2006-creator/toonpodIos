import SwiftUI
import RealityKit
import Combine

// MARK: - RealityKit Avatar View

/// Displays a 3D avatar model using RealityKit with idle animation and interaction.
/// Drop a `host_avatar.usdz` into the Xcode bundle to use a real model.
/// Without one, a procedural placeholder character is shown.
struct AvatarModelView: View {
    let modelName: String
    var allowsRotation: Bool = true
    var autoRotate: Bool = true
    var showPlatform: Bool = true

    @State private var rotationAngle: Float = 0
    @State private var dragOffset: Float = 0
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geo in
            // Guard against zero-size frames that cause NaN in RealityKit
            if geo.size.width > 1 && geo.size.height > 1 {
                avatar3DContent
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if autoRotate { startIdleRotation() }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    @ViewBuilder
    private var avatar3DContent: some View {
        #if os(iOS) || os(visionOS)
        Avatar3DContainer(
            modelName: modelName,
            rotationAngle: rotationAngle + dragOffset,
            showPlatform: showPlatform
        )
        .gesture(
            allowsRotation
            ? DragGesture()
                .onChanged { value in
                    dragOffset = Float(value.translation.width) * 0.01
                }
                .onEnded { _ in
                    rotationAngle += dragOffset
                    dragOffset = 0
                }
            : nil
        )
        #else
        // macOS placeholder
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.15))
            Image(systemName: "person.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple.opacity(0.5))
        }
        #endif
    }

    private func startIdleRotation() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                rotationAngle += 0.005
            }
        }
    }
}

// MARK: - RealityKit UIViewRepresentable (iOS / visionOS only)

#if os(iOS) || os(visionOS)
struct Avatar3DContainer: UIViewRepresentable {
    let modelName: String
    let rotationAngle: Float
    let showPlatform: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        // Non-AR rendering — no camera feed, just 3D content
        arView.cameraMode = .nonAR
        arView.environment.background = .color(.clear)
        arView.backgroundColor = .clear

        // Reduce simulator noise
        arView.renderOptions = [
            .disableMotionBlur,
            .disableDepthOfField,
            .disablePersonOcclusion,
            .disableGroundingShadows,
            .disableFaceMesh,
        ]

        // Scene lighting
        let directional = DirectionalLight()
        directional.light.intensity = 2000
        directional.light.color = .white
        directional.look(at: [0, 0, 0], from: [2, 4, 3], relativeTo: nil)
        let lightAnchor = AnchorEntity(world: .zero)
        lightAnchor.addChild(directional)
        arView.scene.addAnchor(lightAnchor)

        // Content anchor
        let anchor = AnchorEntity()
        context.coordinator.anchor = anchor
        arView.scene.addAnchor(anchor)

        loadModel(into: anchor, coordinator: context.coordinator)

        if showPlatform {
            addPlatform(to: anchor)
        }

        // Camera
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 40
        camera.position = [0, 0.8, 2.8]
        camera.look(at: [0, 0.5, 0], from: camera.position, relativeTo: nil)
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(camera)
        arView.scene.addAnchor(cameraAnchor)

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        guard let modelEntity = context.coordinator.modelEntity else { return }
        // Validate rotationAngle to prevent NaN
        guard rotationAngle.isFinite else { return }
        let rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
        modelEntity.orientation = rotation
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Model Loading

    private func loadModel(into anchor: AnchorEntity, coordinator: Coordinator) {
        // Try .usdz then .reality from bundle
        if let url = Bundle.main.url(forResource: modelName, withExtension: "usdz") {
            loadModelFromURL(url, into: anchor, coordinator: coordinator)
        } else if let url = Bundle.main.url(forResource: modelName, withExtension: "reality") {
            loadModelFromURL(url, into: anchor, coordinator: coordinator)
        } else {
            print("[Avatar3D] No model file '\(modelName).usdz' found in bundle — using placeholder")
            createPlaceholderAvatar(into: anchor, coordinator: coordinator)
        }
    }

    private func loadModelFromURL(_ url: URL, into anchor: AnchorEntity, coordinator: Coordinator) {
        Task {
            do {
                let entity = try await ModelEntity(contentsOf: url)
                await MainActor.run {
                    // Auto-scale to fit
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                    guard maxDim > 0 else { return }
                    let scale = 1.5 / maxDim
                    entity.scale = [scale, scale, scale]

                    // Center on ground
                    let scaledBounds = entity.visualBounds(relativeTo: nil)
                    entity.position.y = -scaledBounds.min.y

                    // Enable shadow
                    entity.generateCollisionShapes(recursive: true)

                    anchor.addChild(entity)
                    coordinator.modelEntity = entity

                    // Play embedded animations (idle, breathing, etc.)
                    for anim in entity.availableAnimations {
                        entity.playAnimation(anim.repeat())
                    }

                    print("[Avatar3D] Loaded model '\(modelName)' successfully")
                }
            } catch {
                print("[Avatar3D] Failed to load '\(modelName)': \(error)")
                await MainActor.run {
                    createPlaceholderAvatar(into: anchor, coordinator: coordinator)
                }
            }
        }
    }

    // MARK: - Procedural Placeholder Avatar

    private func createPlaceholderAvatar(into anchor: AnchorEntity, coordinator: Coordinator) {
        let root = ModelEntity()

        // Head
        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.25),
            materials: [makeMaterial(r: 0.6, g: 0.4, b: 0.9, roughness: 0.3, metallic: 0.1)]
        )
        head.position = [0, 1.1, 0]

        // Body
        let body = ModelEntity(
            mesh: .generateBox(size: [0.5, 0.7, 0.3], cornerRadius: 0.08),
            materials: [makeMaterial(r: 0.3, g: 0.2, b: 0.6, roughness: 0.4)]
        )
        body.position = [0, 0.5, 0]

        // Eyes
        let eyeMat = makeMaterial(r: 1, g: 1, b: 1, roughness: 0.1, metallic: 0.8)
        let leftEye = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [eyeMat])
        leftEye.position = [-0.08, 1.15, 0.22]
        let rightEye = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [eyeMat])
        rightEye.position = [0.08, 1.15, 0.22]

        // Pupils
        let pupilMat = makeMaterial(r: 0.1, g: 0.05, b: 0.2)
        let leftPupil = ModelEntity(mesh: .generateSphere(radius: 0.025), materials: [pupilMat])
        leftPupil.position = [-0.08, 1.15, 0.25]
        let rightPupil = ModelEntity(mesh: .generateSphere(radius: 0.025), materials: [pupilMat])
        rightPupil.position = [0.08, 1.15, 0.25]

        // Smile
        let smile = ModelEntity(
            mesh: .generateBox(size: [0.15, 0.02, 0.02], cornerRadius: 0.01),
            materials: [makeMaterial(r: 0.9, g: 0.3, b: 0.5)]
        )
        smile.position = [0, 1.0, 0.23]

        for child in [head, body, leftEye, rightEye, leftPupil, rightPupil, smile] as [ModelEntity] {
            root.addChild(child)
        }

        anchor.addChild(root)
        coordinator.modelEntity = root

        // Idle bobbing
        addIdleBob(to: root)
    }

    private func addIdleBob(to entity: ModelEntity) {
        var upTransform = entity.transform
        upTransform.translation.y += 0.03
        entity.move(to: upTransform, relativeTo: entity.parent, duration: 1.5)

        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in
                let goingUp = entity.transform.translation.y < 0.015
                var target = entity.transform
                target.translation.y = goingUp ? 0.03 : 0
                entity.move(to: target, relativeTo: entity.parent, duration: 1.5)
            }
        }
    }

    // MARK: - Platform

    private func addPlatform(to anchor: AnchorEntity) {
        // Base disc
        let platform = ModelEntity(
            mesh: .generateCylinder(height: 0.05, radius: 0.6),
            materials: [makeMaterial(r: 0.15, g: 0.1, b: 0.3, a: 0.8, roughness: 0.2, metallic: 0.6)]
        )
        platform.position = [0, -0.025, 0]
        anchor.addChild(platform)

        // Glow ring
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: 0.65),
            materials: [makeMaterial(r: 0.5, g: 0.3, b: 1.0, a: 0.4, roughness: 0.0, metallic: 1.0)]
        )
        ring.position = [0, -0.005, 0]
        anchor.addChild(ring)
    }

    // MARK: - Helpers

    private func makeMaterial(
        r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1,
        roughness: Float = 0.5, metallic: Float = 0.0
    ) -> SimpleMaterial {
        var mat = SimpleMaterial()
        mat.color = .init(tint: .init(red: r, green: g, blue: b, alpha: a))
        mat.roughness = .float(roughness)
        mat.metallic = .float(metallic)
        return mat
    }

    class Coordinator {
        var anchor: AnchorEntity?
        var modelEntity: Entity?
    }
}
#endif

// MARK: - Avatar Speaking Indicator

struct AvatarSpeakingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(Color.purple)
                    .frame(width: 4, height: isAnimating ? CGFloat.random(in: 8...20) : 6)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: "0d001a").ignoresSafeArea()
        AvatarModelView(modelName: "host_avatar")
            .frame(height: 400)
    }
}
