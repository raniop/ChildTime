import ModelIO
import SceneKit
import SceneKit.ModelIO
import Foundation
import AppKit

// macOS step of the FBX -> .scn pipeline. Model I/O reads the OBJ that SceneKit's
// own OBJ loader can't, SCNScene(mdlAsset:) bridges it, we bake the diffuse
// texture onto the materials, and write a native .scn (self-contained: the image
// is archived into the file). Usage: swift obj_to_scn.swift <in.obj> <out.scn>
let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: obj_to_scn.swift <in.obj> <out.scn>"); exit(2) }
let objURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let dir = objURL.deletingLastPathComponent()

let asset = MDLAsset(url: objURL)
asset.loadTextures()
let scene = SCNScene(mdlAsset: asset)

// Find the diffuse/base-color texture robustly: first the .mtl's `map_Kd`
// (works whatever the file is named, e.g. "file8.png"), then a "diffuse"-named
// PNG, then the only PNG present.
func findDiffuse(in dir: URL) -> (NSImage, String)? {
    let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
    if let mtl = files.first(where: { $0.lowercased().hasSuffix(".mtl") }),
       let txt = try? String(contentsOf: dir.appendingPathComponent(mtl), encoding: .utf8) {
        for line in txt.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.lowercased().hasPrefix("map_kd"), let name = t.split(separator: " ").last.map(String.init),
               let img = NSImage(contentsOf: dir.appendingPathComponent(name)) {
                return (img, name)
            }
        }
    }
    if let d = files.first(where: { $0.lowercased().contains("diffuse") && $0.lowercased().hasSuffix("png") }),
       let img = NSImage(contentsOfFile: dir.appendingPathComponent(d).path) { return (img, d) }
    let pngs = files.filter { $0.lowercased().hasSuffix("png") }
    if pngs.count == 1, let img = NSImage(contentsOfFile: dir.appendingPathComponent(pngs[0]).path) {
        return (img, pngs[0])
    }
    return nil
}
// Downscale big Mixamo diffuse maps (often 4K, ~9MB) so each bundled .scn stays
// small — 1024 is plenty at the sizes the character renders on screen.
func resized(_ image: NSImage, max: CGFloat) -> NSImage {
    let s = image.size
    let scale = Swift.min(1, max / Swift.max(s.width, s.height))
    if scale >= 1 { return image }
    let ns = NSSize(width: s.width * scale, height: s.height * scale)
    let out = NSImage(size: ns)
    out.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: ns))
    out.unlockFocus()
    return out
}
let found = findDiffuse(in: dir)
let diffuse = found.map { resized($0.0, max: 512) }
let diffuseName = found?.1

func applyTex(_ n: SCNNode) {
    if let g = n.geometry {
        if let diffuse {
            // TEXTURED source (e.g. Mixamo): the material Model I/O derives from
            // Blender's .mtl (illum 6 / `d 0`) renders fully transparent and
            // can't be reliably un-broken; one fresh textured material sidesteps it.
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = diffuse
            m.roughness.contents = 0.8
            m.metalness.contents = 0.0
            m.isDoubleSided = true
            g.materials = [m]
        } else {
            // FLAT-COLOURED source (e.g. Quaternius/Kenney): each material carries
            // its own colour (skin / shirt / hair). The Blender-exported material
            // is still broken-transparent, so rebuild each slot FRESH while
            // copying its original diffuse colour — preserving the multi-colour
            // look without the invisibility.
            g.materials = g.materials.map { old in
                let m = SCNMaterial()
                m.lightingModel = .physicallyBased
                m.diffuse.contents = old.diffuse.contents ?? NSColor(white: 0.8, alpha: 1)
                m.roughness.contents = 0.85
                m.metalness.contents = 0.0
                m.isDoubleSided = true
                return m
            }
        }
    }
    n.childNodes.forEach(applyTex)
}
scene.rootNode.childNodes.forEach(applyTex)

let opts: [String: Any] = [:]
let del: SCNSceneExportDelegate? = nil
let prog: ((Float, Error?, UnsafeMutablePointer<ObjCBool>) -> Void)? = nil
let ok = scene.write(to: outURL, options: opts, delegate: del, progressHandler: prog)
print("scn write ok=\(ok) diffuse=\(diffuseName ?? "none") -> \(outURL.lastPathComponent)")
