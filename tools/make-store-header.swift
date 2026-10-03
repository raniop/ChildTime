import AppKit
import CoreImage
// App Store product-page Header (3840×1646) — three directions with the lion.
// usage: swift tools/make-store-header.swift <outdir>
let out = CommandLine.arguments[1]
let root = "/Users/raniophir/ChildTime/ChildTime/Characters2D/"
let W: CGFloat = 3840, H: CGFloat = CGFloat(Double(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "1646")!)
let ctxCI = CIContext()

func load(_ n: String) -> CGImage {
    let img = NSImage(contentsOfFile: root + n + ".png")!
    var r = NSRect(origin: .zero, size: img.size)
    return img.cgImage(forProposedRect: &r, context: nil, hints: nil)!
}
/// High-quality Lanczos scale (the source characters are small).
func scaled(_ cg: CGImage, height: CGFloat) -> CGImage {
    let s = height / CGFloat(cg.height)
    let f = CIFilter(name: "CILanczosScaleTransform")!
    f.setValue(CIImage(cgImage: cg), forKey: kCIInputImageKey)
    f.setValue(s, forKey: kCIInputScaleKey); f.setValue(1.0, forKey: kCIInputAspectRatioKey)
    let o = f.outputImage!
    return ctxCI.createCGImage(o, from: o.extent)!
}
func newCtx() -> CGContext {
    CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
func background(_ ctx: CGContext) {
    // Tofy brand: violet → pink top-right, cyan glow bottom-left (the app's GlassBackdrop).
    let base = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c(0x6A4CF0), c(0x5B6CF2), c(0x3E8BF0)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])
    func glow(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ col: UInt32, _ a: CGFloat) {
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c(col, a), c(col, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
    }
    glow(W * 0.82, H * 0.85, 1300, 0xF06BD6, 0.75)
    glow(W * 0.12, H * 0.1, 1200, 0x2FD6E0, 0.65)
    glow(W * 0.5, H * 0.45, 900, 0xFFFFFF, 0.18)
}
func sparkles(_ ctx: CGContext, seed: Int) {
    var g = SystemRandomNumberGenerator()
    _ = seed
    for _ in 0..<70 {
        let x = CGFloat.random(in: 0...W, using: &g), y = CGFloat.random(in: 0...H, using: &g)
        let s = CGFloat.random(in: 10...34, using: &g)
        let gold = Bool.random(using: &g)
        ctx.setFillColor(gold ? c(0xFFD23F, 0.85) : c(0xFFFFFF, 0.75))
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y + s)); p.addQuadCurve(to: CGPoint(x: x + s, y: y), control: CGPoint(x: x, y: y))
        p.addQuadCurve(to: CGPoint(x: x, y: y - s), control: CGPoint(x: x, y: y)); p.addQuadCurve(to: CGPoint(x: x - s, y: y), control: CGPoint(x: x, y: y))
        p.addQuadCurve(to: CGPoint(x: x, y: y + s), control: CGPoint(x: x, y: y)); ctx.addPath(p); ctx.fillPath()
    }
}
func draw(_ ctx: CGContext, _ img: CGImage, cx: CGFloat, bottom: CGFloat, shadow: CGFloat = 40) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -shadow * 0.5), blur: shadow, color: c(0x1A0F4D, 0.45))
    ctx.draw(img, in: CGRect(x: cx - CGFloat(img.width) / 2, y: bottom, width: CGFloat(img.width), height: CGFloat(img.height)))
    ctx.restoreGState()
}
func glassCard(_ ctx: CGContext, _ r: CGRect, emoji: String) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: c(0x1A0F4D, 0.35))
    let path = CGPath(roundedRect: r, cornerWidth: 70, cornerHeight: 70, transform: nil)
    ctx.addPath(path); ctx.setFillColor(c(0xFFFFFF, 0.22)); ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(path); ctx.setStrokeColor(c(0xFFFFFF, 0.55)); ctx.setLineWidth(5); ctx.strokePath()
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false); NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let t = NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: r.height * 0.52), .paragraphStyle: para])
    let sz = t.size()
    t.draw(in: CGRect(x: r.minX, y: r.midY - sz.height / 2, width: r.width, height: sz.height))
    NSGraphicsContext.restoreGraphicsState()
}
func save(_ ctx: CGContext, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out + "/" + name))
    print("wrote", name)
}
// The lion upscaled 3× on-device (tools/upscale-image.swift, MetalFX) — the
// 520px original looked soft at header size.
let lion: CGImage = {
    let img = NSImage(contentsOfFile: "/Users/raniophir/ChildTime/reports/store-header/lion_hd.png")!
    var r = NSRect(origin: .zero, size: img.size)
    return img.cgImage(forProposedRect: &r, context: nil, hints: nil)!
}()

// A — the lion alone, big and centered.
do {
    let ctx = newCtx(); background(ctx); sparkles(ctx, seed: 1)
    draw(ctx, scaled(lion, height: 1450), cx: W / 2, bottom: 20, shadow: 70)
    save(ctx, "header-A-lion.png")
}
// B — the lion with friends around him.
do {
    let ctx = newCtx(); background(ctx); sparkles(ctx, seed: 2)
    let friends: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("fox", W * 0.30, 70, 760), ("monkey", W * 0.70, 70, 760),
        ("panda", W * 0.17, 120, 620), ("bunny", W * 0.83, 120, 640),
        ("penguin", W * 0.06, 170, 480), ("owl", W * 0.94, 170, 500)]
    for (n, x, b, h) in friends { draw(ctx, scaled(load(n), height: h), cx: x, bottom: b, shadow: 36) }
    draw(ctx, scaled(lion, height: 1380), cx: W / 2, bottom: 30, shadow: 70)
    save(ctx, "header-B-friends.png")
}
// C — the lion among big floating world emojis (no frames — Rani).
func bigEmoji(_ ctx: CGContext, _ e: String, x: CGFloat, y: CGFloat, size: CGFloat, tilt: CGFloat) {
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false); NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    ctx.saveGState()
    ctx.translateBy(x: x, y: y); ctx.rotate(by: tilt * .pi / 180)
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.06), blur: size * 0.18, color: c(0x1A0F4D, 0.4))
    let t = NSAttributedString(string: e, attributes: [.font: NSFont.systemFont(ofSize: size)])
    let sz = t.size(); t.draw(at: CGPoint(x: -sz.width / 2, y: -sz.height / 2))
    ctx.restoreGState(); NSGraphicsContext.restoreGraphicsState()
}
do {
    let ctx = newCtx(); background(ctx); sparkles(ctx, seed: 3)
    let worlds: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ("🧮", W * 0.255, H * 0.66, H > 2000 ? 520 : 400, -8), ("📖", H > 2000 ? W * 0.28 : W * 0.33, H * 0.25, 360, 6), ("🌍", W * 0.12, H * 0.30, 340, -4),
        ("⚽", W * 0.745, H * 0.66, H > 2000 ? 520 : 400, 8), ("🔬", H > 2000 ? W * 0.72 : W * 0.67, H * 0.25, 360, -6), ("🇬🇧", W * 0.88, H * 0.30, 320, 5),
        ("🦖", W * 0.05, H * 0.78, 250, 10), ("🚀", W * 0.95, H * 0.78, 250, -10)]
    for (e, x, y, s, t) in worlds { bigEmoji(ctx, e, x: x, y: y, size: s, tilt: t) }
    draw(ctx, scaled(lion, height: H > 2000 ? 2050 : 1420), cx: W / 2, bottom: H > 2000 ? 60 : 20, shadow: 70)
    save(ctx, H > 2000 ? "search-C-worlds.png" : "header-C-worlds.png")
}
