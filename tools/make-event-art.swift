import AppKit
import CoreImage
// App Store In-App Event art — the event card (1920×1080) and the event page
// (1080×1920): the lion among phones that show the real game boards.
// usage: swift tools/make-event-art.swift <games-dir> <lang> <outdir>
//   <games-dir>/<lang>-<screen>.png are full simulator screenshots of the
//   games (DEMO_SCREEN=<screen> DEMO_SURPRISE=1, which skips the intro card).
let gamesDir = CommandLine.arguments[1], lang = CommandLine.arguments[2], out = CommandLine.arguments[3]
let ciCtx = CIContext()

func cgImage(_ path: String) -> CGImage {
    let img = NSImage(contentsOfFile: path)!
    var r = NSRect(origin: .zero, size: img.size)
    return img.cgImage(forProposedRect: &r, context: nil, hints: nil)!
}
func scaled(_ cg: CGImage, height: CGFloat) -> CGImage {
    let f = CIFilter(name: "CILanczosScaleTransform")!
    f.setValue(CIImage(cgImage: cg), forKey: kCIInputImageKey)
    f.setValue(height / CGFloat(cg.height), forKey: kCIInputScaleKey); f.setValue(1.0, forKey: kCIInputAspectRatioKey)
    let o = f.outputImage!
    return ciCtx.createCGImage(o, from: o.extent)!
}
func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
func canvas(_ w: CGFloat, _ h: CGFloat) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Tofy's GlassBackdrop: violet → blue, pink glow, cyan glow.
    let base = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c(0x6A4CF0), c(0x5B6CF2), c(0x3E8BF0)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])
    func glow(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ col: UInt32, _ a: CGFloat) {
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c(col, a), c(col, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
    }
    let m = max(w, h)
    glow(w * 0.85, h * 0.85, m * 0.45, 0xF06BD6, 0.75)
    glow(w * 0.12, h * 0.12, m * 0.42, 0x2FD6E0, 0.6)
    glow(w * 0.5, h * 0.5, m * 0.3, 0xFFFFFF, 0.14)
    var g = SystemRandomNumberGenerator()
    for _ in 0..<Int(w * h / 60_000) {
        let x = CGFloat.random(in: 0...w, using: &g), y = CGFloat.random(in: 0...h, using: &g)
        let s = CGFloat.random(in: 5...15, using: &g)
        ctx.setFillColor(Bool.random(using: &g) ? c(0xFFD23F, 0.8) : c(0xFFFFFF, 0.7))
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y + s)); p.addQuadCurve(to: CGPoint(x: x + s, y: y), control: CGPoint(x: x, y: y))
        p.addQuadCurve(to: CGPoint(x: x, y: y - s), control: CGPoint(x: x, y: y)); p.addQuadCurve(to: CGPoint(x: x - s, y: y), control: CGPoint(x: x, y: y))
        p.addQuadCurve(to: CGPoint(x: x, y: y + s), control: CGPoint(x: x, y: y)); ctx.addPath(p); ctx.fillPath()
    }
    return ctx
}
/// A phone showing one game board, centred at (cx, cy), `h` tall, tilted.
func phone(_ ctx: CGContext, _ screen: String, cx: CGFloat, cy: CGFloat, h: CGFloat, tilt: CGFloat) {
    let shot = cgImage("\(gamesDir)/\(lang)-\(screen).png")
    // Drop the status bar — the board is the point, not the clock.
    let top = Int(Double(shot.height) * 0.055)
    let board = shot.cropping(to: CGRect(x: 0, y: top, width: shot.width, height: shot.height - top))!
    let w = h * CGFloat(board.width) / CGFloat(board.height)
    let bezel = h * 0.022, radius = h * 0.085
    ctx.saveGState()
    ctx.translateBy(x: cx, y: cy); ctx.rotate(by: tilt * .pi / 180)
    let outer = CGRect(x: -w / 2 - bezel, y: -h / 2 - bezel, width: w + bezel * 2, height: h + bezel * 2)
    ctx.setShadow(offset: CGSize(width: 0, height: -h * 0.03), blur: h * 0.08, color: c(0x1A0F4D, 0.5))
    ctx.addPath(CGPath(roundedRect: outer, cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil))
    ctx.setFillColor(c(0x14102E)); ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    let inner = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
    ctx.addPath(CGPath(roundedRect: inner, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(scaled(board, height: h * 2), in: inner)
    ctx.restoreGState()
}
let lion = cgImage("/Users/raniophir/ChildTime/reports/store-header/lion_hd.png")
func drawLion(_ ctx: CGContext, cx: CGFloat, bottom: CGFloat, height: CGFloat) {
    let img = scaled(lion, height: height)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -height * 0.02), blur: height * 0.06, color: c(0x1A0F4D, 0.5))
    ctx.draw(img, in: CGRect(x: cx - CGFloat(img.width) / 2, y: bottom, width: CGFloat(img.width), height: CGFloat(img.height)))
    ctx.restoreGState()
}
func save(_ ctx: CGContext, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    let path = "\(out)/\(name)"
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: URL(fileURLWithPath: path))
    print("wrote", path)
}

// 🃏 Event card, 1920×1080. Apple lays the badge, the name and the short
// description over the lower part, so the lion and the phones keep to the top
// two thirds and the bottom stays quiet.
do {
    let W: CGFloat = 1920, H: CGFloat = 1080
    let ctx = canvas(W, H)
    let row: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ("vaultgame",   W * 0.085, H * 0.60, 470, -12), ("grocerygame", W * 0.915, H * 0.60, 470, 12),
        ("pairsgame",   W * 0.215, H * 0.61, 530, -6),  ("crushgame",   W * 0.785, H * 0.61, 530, 6),
        ("balancegame", W * 0.345, H * 0.62, 580, -2),  ("balloongame", W * 0.655, H * 0.62, 580, 2)]
    for (s, x, y, h, t) in row { phone(ctx, s, cx: x, cy: y, h: h, tilt: t) }
    drawLion(ctx, cx: W / 2, bottom: H * 0.25, height: 690)
    save(ctx, "event-card-\(lang).jpg")
}
// 📄 Event page, 1080×1920: a fan of phones across the middle, the lion in
// front, the bottom third left for Apple's text.
do {
    let W: CGFloat = 1080, H: CGFloat = 1920
    let ctx = canvas(W, H)
    let fan: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ("vaultgame",   W * 0.14, H * 0.70, 520, -10), ("grocerygame", W * 0.86, H * 0.70, 520, 10),
        ("pairsgame",   W * 0.31, H * 0.715, 580, -4), ("crushgame",   W * 0.69, H * 0.715, 580, 4),
        ("balloongame", W * 0.50, H * 0.73, 630, 0)]
    for (s, x, y, h, t) in fan { phone(ctx, s, cx: x, cy: y, h: h, tilt: t) }
    drawLion(ctx, cx: W / 2, bottom: H * 0.33, height: 800)
    save(ctx, "event-page-\(lang).jpg")
}
