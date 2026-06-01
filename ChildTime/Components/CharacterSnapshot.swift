import SceneKit
import UIKit

/// Renders a 3D character (.scn) to a flat, transparent UIImage — cached.
///
/// The floating map buddy wanders and is dragged around; moving a live Metal
/// `SCNView` with SwiftUI is janky, so the buddy shows this snapshot instead.
/// The live 3D view stays where it doesn't move (shop, picker, parent avatar).
enum CharacterSnapshot {
    private static var cache: [String: UIImage] = [:]

    /// `modelName` is the bundled resource (e.g. "hero3.scn"). `pixelSize` is the
    /// render width in points; height is 1.3× (room for the legs).
    static func image(modelName: String, pixelSize: CGFloat = 320) -> UIImage? {
        let key = "\(modelName)#\(Int(pixelSize))"
        if let cached = cache[key] { return cached }

        guard let url = Bundle.main.url(forResource: modelName, withExtension: nil)
                ?? Bundle.main.url(forResource: (modelName as NSString).deletingPathExtension, withExtension: "scn"),
              let loaded = try? SCNScene(url: url, options: nil),
              let device = MTLCreateSystemDefaultDevice() else { return nil }

        let scene = SCNScene()

        let camera = SCNCamera()
        camera.fieldOfView = 32
        let camNode = SCNNode()
        camNode.camera = camera
        camNode.position = SCNVector3(0, 0.95, 3.9)
        camNode.look(at: SCNVector3(0, 0.9, 0))
        scene.rootNode.addChildNode(camNode)

        let key1 = SCNNode()
        key1.light = SCNLight(); key1.light?.type = .directional; key1.light?.intensity = 850
        key1.eulerAngles = SCNVector3(-0.7, 0.6, 0)
        scene.rootNode.addChildNode(key1)
        let ambient = SCNNode()
        ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 520
        scene.rootNode.addChildNode(ambient)

        // Normalize (mirrors Character3DView.loadModel).
        let holder = SCNNode()
        loaded.rootNode.childNodes.forEach { holder.addChildNode($0.clone()) }
        let (minB, maxB) = holder.boundingBox
        let scale = Float(2.8) / max(maxB.y - minB.y, 0.0001)
        holder.scale = SCNVector3(scale, scale, scale)
        holder.position = SCNVector3(-(minB.x + maxB.x) / 2 * scale,
                                     0.7 - (minB.y + maxB.y) / 2 * scale,
                                     -(minB.z + maxB.z) / 2 * scale)
        holder.eulerAngles.y = -0.2
        scene.rootNode.addChildNode(holder)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.autoenablesDefaultLighting = false
        let img = renderer.snapshot(atTime: 0,
                                    with: CGSize(width: pixelSize, height: pixelSize * 1.3),
                                    antialiasingMode: .multisampling4X)
        cache[key] = img
        return img
    }
}
