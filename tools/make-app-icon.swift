import AppKit
import CoreGraphics

// Renders the Tofy app icon in the approved glass language:
// brand gradient + pink/teal orbs, a glass pane, the lion in front.
// usage: swift icon.swift <lion.png> <out.png>
let args = CommandLine.arguments
let lionPath = args[1], outPath = args[2]
let S: CGFloat = 1024

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, a])!
}

// 1. gradient (#7A5CFF → #5E60CE → #3E8BF0), top-right → bottom-left
let grad = CGGradient(colorsSpace: cs, colors: [rgb(0x7A5CFF), rgb(0x5E60CE), rgb(0x3E8BF0)] as CFArray, locations: [0, 0.45, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: S * 0.62, y: S), end: CGPoint(x: S * 0.38, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])   // paint the corners too

// 2. orbs (radial, soft) — pink upper-left, teal lower-right
func orb(_ c: UInt32, cx: CGFloat, cy: CGFloat, r: CGFloat, a: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: [rgb(c, a), rgb(c, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: cx, y: cy), startRadius: 0, endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: [])
}
orb(0xFF7BD3, cx: S * 0.18, cy: S * 0.72, r: S * 0.55, a: 0.85)
orb(0x37E2D5, cx: S * 0.85, cy: S * 0.15, r: S * 0.6, a: 0.85)

// 3. glass pane — inset rounded square, white 14 %, top highlight, light edge
// Rani: the glass spreads to the very edge — iOS applies its own rounded mask,
// so the whole icon IS the pane (highlight + edge run right to the border).
let inset: CGFloat = 0
let pane = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let radius: CGFloat = inset == 0 ? 0 : S * 0.2   // full-bleed: no rounded clip (black corners otherwise)
let panePath = CGPath(roundedRect: pane, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.saveGState()
ctx.addPath(panePath); ctx.clip()
ctx.setFillColor(rgb(0xFFFFFF, 0.16)); ctx.fill(pane)
let hi = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.32), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(hi, start: CGPoint(x: 0, y: pane.maxY), end: CGPoint(x: 0, y: pane.maxY - pane.height * 0.35), options: [])
ctx.restoreGState()
ctx.addPath(panePath); ctx.setStrokeColor(rgb(0xFFFFFF, 0.55)); ctx.setLineWidth(S * 0.006); ctx.strokePath()

// 4. sparkles
func sparkle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ a: CGFloat) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: x, y: y + r)); p.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x + r * 0.18, y: y + r * 0.18))
    p.addQuadCurve(to: CGPoint(x: x, y: y - r), control: CGPoint(x: x + r * 0.18, y: y - r * 0.18))
    p.addQuadCurve(to: CGPoint(x: x - r, y: y), control: CGPoint(x: x - r * 0.18, y: y - r * 0.18))
    p.addQuadCurve(to: CGPoint(x: x, y: y + r), control: CGPoint(x: x - r * 0.18, y: y + r * 0.18))
    ctx.addPath(p); ctx.setFillColor(rgb(0xFFFFFF, a)); ctx.fillPath()
}
sparkle(S * 0.22, S * 0.80, S * 0.035, 0.95)
sparkle(S * 0.80, S * 0.84, S * 0.025, 0.85)
sparkle(S * 0.15, S * 0.40, S * 0.018, 0.7)
sparkle(S * 0.86, S * 0.55, S * 0.02, 0.7)

// 5. the lion — big, bottom-anchored, slight drop shadow, clipped to the pane
guard let lionImg = NSImage(contentsOfFile: lionPath)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("no lion") }
let lw = CGFloat(lionImg.width), lh = CGFloat(lionImg.height)
// Big and close, like a portrait: the head + waving paw fill the pane, the
// body runs out of the bottom edge.
let targetH = S * 1.18
let scale = targetH / lh
let dw = lw * scale, dh = lh * scale
let lionRect = CGRect(x: (S - dw) / 2 + S * 0.02, y: pane.maxY - S * 0.12 - dh, width: dw, height: dh)
ctx.saveGState()
ctx.addPath(panePath); ctx.clip()
ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.02), blur: S * 0.05, color: rgb(0x000000, 0.35))
ctx.draw(lionImg, in: lionRect)
ctx.restoreGState()

let out = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: out)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote", outPath)
