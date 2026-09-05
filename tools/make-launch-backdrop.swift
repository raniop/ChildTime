import AppKit
import CoreGraphics
// Renders the LaunchScreen backdrop (1290×2796) in the glass language:
// brand gradient + the pink / teal orbs — the same picture GlassBackdrop paints,
// so the storyboard and the first SwiftUI frame are indistinguishable.
// usage: swift tools/make-launch-backdrop.swift <out.png>
let out = CommandLine.arguments[1]
let W: CGFloat = 1290, H: CGFloat = 2796
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, a])!
}
let grad = CGGradient(colorsSpace: cs, colors: [rgb(0x7A5CFF), rgb(0x5E60CE), rgb(0x3E8BF0)] as CFArray, locations: [0, 0.45, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: W * 0.62, y: H), end: CGPoint(x: W * 0.38, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
func orb(_ c: UInt32, cx: CGFloat, cy: CGFloat, r: CGFloat, a: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: [rgb(c, a), rgb(c, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: cx, y: cy), startRadius: 0, endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: [])
}
// GlassBackdrop: pink at (40pt, 250pt from top), teal at (width-30, height-200) — in points of a 402×874 screen.
orb(0xFF7BD3, cx: W * (40.0 / 402.0), cy: H - H * (250.0 / 874.0), r: W * 0.55, a: 0.8)
orb(0x37E2D5, cx: W - W * (30.0 / 402.0), cy: H * (200.0 / 874.0), r: W * 0.62, a: 0.8)
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote", out)
