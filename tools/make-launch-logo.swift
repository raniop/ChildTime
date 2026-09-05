import AppKit
// LaunchScreen logo: the lion above a white "טופי" wordmark (SF Rounded, black
// weight) on a transparent canvas — the glass language, no gold gradient.
// usage: swift tools/make-launch-logo.swift <lion.png> <out@3x.png>
let a = CommandLine.arguments
let lion = NSImage(contentsOfFile: a[1])!
let W: CGFloat = 450, H: CGFloat = 798   // 150×266 pt @3x
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
// lion: top ~70 % of the canvas
let lw = lion.size.width, lh = lion.size.height
let targetH = H * 0.66
let s = targetH / lh
let dw = lw * s, dh = lh * s
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.3); shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
lion.draw(in: NSRect(x: (W - dw) / 2, y: H - dh - 10, width: dw, height: dh), from: .zero, operation: .sourceOver, fraction: 1)
// wordmark
let font = NSFont.systemFont(ofSize: 132, weight: .black)
let desc = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
let rounded = NSFont(descriptor: desc, size: 132) ?? font
let para = NSMutableParagraphStyle(); para.alignment = .center
let tShadow = NSShadow(); tShadow.shadowColor = NSColor.black.withAlphaComponent(0.25); tShadow.shadowBlurRadius = 14; tShadow.shadowOffset = NSSize(width: 0, height: -6)
let attrs: [NSAttributedString.Key: Any] = [.font: rounded, .foregroundColor: NSColor.white, .paragraphStyle: para, .shadow: tShadow]
let str = NSAttributedString(string: "טופי", attributes: attrs)
let size = str.size()
str.draw(in: NSRect(x: 0, y: 40, width: W, height: size.height + 20))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
print("wrote", a[2])
