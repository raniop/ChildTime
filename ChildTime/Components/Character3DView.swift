import SwiftUI
import SceneKit

/// A 3D character rendered with SceneKit.
///
/// Phase 1 of the move to real game-style avatars: this shows a procedural
/// PLACEHOLDER model built from primitives so the whole pipeline (camera,
/// lighting, idle animation, SwiftUI embedding) is proven and verifiable in the
/// app. Real `.usdz` models drop in later by passing `modelName` — the rest of
/// the scene (camera/lights/animation) stays identical.
struct Character3DView: UIViewRepresentable {
    /// Bundled `.usdz`/`.scn` resource name (with extension). When nil, the
    /// procedural placeholder character is shown.
    var modelName: String? = nil
    /// Primary body tint for the placeholder.
    var bodyColor: Color = AppColor.companionBody
    var animated: Bool = true
    /// Let the child drag left/right to spin the character a full 360°.
    var interactive: Bool = true
    /// Frame just the head + shoulders (for small circular avatars) instead of
    /// the full body.
    var portrait: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var spinNode: SCNNode?
        private var startAngle: Float = 0
        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let spin = spinNode else { return }
            let tx = g.translation(in: g.view).x
            if g.state == .began { startAngle = spin.eulerAngles.y }
            spin.eulerAngles.y = startAngle + Float(tx) * 0.012
        }
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let (scene, spin) = makeScene()
        view.scene = scene
        context.coordinator.spinNode = spin
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.rendersContinuously = animated
        if interactive {
            view.isUserInteractionEnabled = true
            let pan = UIPanGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePan(_:)))
            view.addGestureRecognizer(pan)
        } else {
            view.isUserInteractionEnabled = false
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: - Scene

    private func makeScene() -> (SCNScene, SCNNode) {
        let scene = SCNScene()

        // Camera framing the character from slightly above (closer = bigger).
        let camera = SCNCamera()
        camera.fieldOfView = 32
        camera.zNear = 0.1
        let camNode = SCNNode()
        camNode.camera = camera
        if portrait {
            // Head + shoulders for small circular avatars. Framed wide enough
            // that even a big-headed character (e.g. the cat) fits uncropped.
            camNode.position = SCNVector3(0, 1.6, 2.35)
            camNode.look(at: SCNVector3(0, 1.5, 0))
        } else {
            camNode.position = SCNVector3(0, 0.95, 3.9)
            camNode.look(at: SCNVector3(0, 0.9, 0))
        }
        scene.rootNode.addChildNode(camNode)

        // Key + fill + ambient so the model reads with soft, kid-friendly light.
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 850
        key.light?.castsShadow = false
        key.eulerAngles = SCNVector3(-0.7, 0.6, 0)
        scene.rootNode.addChildNode(key)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 520
        scene.rootNode.addChildNode(ambient)

        // Character (real model if provided, else placeholder). It lives under a
        // `spin` turntable node so the child's drag controls Y rotation without
        // fighting the idle bob (which only moves the character up/down).
        let character = modelName.flatMap(loadModel(named:)) ?? placeholderCharacter()
        let spin = SCNNode()
        spin.eulerAngles.y = -0.2
        spin.addChildNode(character)
        scene.rootNode.addChildNode(spin)

        if animated {
            character.runAction(.repeatForever(.sequence([
                .moveBy(x: 0, y: 0.08, z: 0, duration: 1.2),
                .moveBy(x: 0, y: -0.08, z: 0, duration: 1.2)
            ])))
        }
        return (scene, spin)
    }

    // MARK: - Real model loading (future)

    private func loadModel(named name: String) -> SCNNode? {
        // `name` may include the extension (e.g. "buddy.usdz") or not.
        let url = Bundle.main.url(forResource: name, withExtension: nil)
            ?? Bundle.main.url(forResource: (name as NSString).deletingPathExtension,
                               withExtension: (name as NSString).pathExtension.isEmpty ? "usdz"
                                              : (name as NSString).pathExtension)
        guard let url, let loaded = try? SCNScene(url: url, options: nil) else { return nil }

        let holder = SCNNode()
        loaded.rootNode.childNodes.forEach { holder.addChildNode($0.clone()) }

        // Normalize: real models arrive at arbitrary scales/positions. Scale to a
        // consistent on-screen height and center on the camera's focus point so
        // ANY dropped-in model frames correctly with no per-model tuning.
        // NOTE: measure via `boundingBox` (includes the node hierarchy) — NOT
        // `flattenedClone().boundingBox`, which returns zero for these meshes and
        // would scale the model into oblivion (invisible).
        let (minB, maxB) = holder.boundingBox
        let modelHeight = max(maxB.y - minB.y, 0.0001)
        let targetHeight: Float = 2.8
        let scale = targetHeight / modelHeight
        holder.scale = SCNVector3(scale, scale, scale)

        let center = SCNVector3((minB.x + maxB.x) / 2,
                                (minB.y + maxB.y) / 2,
                                (minB.z + maxB.z) / 2)
        holder.position = SCNVector3(-center.x * scale,
                                     0.7 - center.y * scale,
                                     -center.z * scale)
        return holder
    }

    // MARK: - Placeholder character

    private func material(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.65
        m.metalness.contents = 0.0
        return m
    }

    private func placeholderCharacter() -> SCNNode {
        let root = SCNNode()
        let body = UIColor(bodyColor)
        let dark = UIColor(white: 0.12, alpha: 1)
        let white = UIColor(white: 0.98, alpha: 1)

        // Torso
        let torso = SCNNode(geometry: SCNCapsule(capRadius: 0.55, height: 1.6))
        torso.geometry?.materials = [material(body)]
        torso.position = SCNVector3(0, 0.65, 0)
        root.addChildNode(torso)

        // Head
        let head = SCNNode(geometry: SCNSphere(radius: 0.62))
        head.geometry?.materials = [material(body)]
        head.position = SCNVector3(0, 1.65, 0)
        root.addChildNode(head)

        // Eyes (whites + pupils)
        for dx in [Float(-0.22), 0.22] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.12))
            eye.geometry?.materials = [material(white)]
            eye.position = SCNVector3(dx, 1.72, 0.54)
            root.addChildNode(eye)
            let pupil = SCNNode(geometry: SCNSphere(radius: 0.06))
            pupil.geometry?.materials = [material(dark)]
            pupil.position = SCNVector3(dx, 1.72, 0.63)
            root.addChildNode(pupil)
        }

        // Arms
        for dx in [Float(-0.62), 0.62] {
            let arm = SCNNode(geometry: SCNCapsule(capRadius: 0.16, height: 0.95))
            arm.geometry?.materials = [material(body)]
            arm.position = SCNVector3(dx, 0.75, 0)
            arm.eulerAngles.z = dx > 0 ? -0.18 : 0.18
            root.addChildNode(arm)
        }

        // Legs
        for dx in [Float(-0.26), 0.26] {
            let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.18, height: 0.75))
            leg.geometry?.materials = [material(body)]
            leg.position = SCNVector3(dx, -0.2, 0)
            root.addChildNode(leg)
        }

        return root
    }
}
