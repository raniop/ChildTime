import AppKit

func rounded(_ size: CGFloat, _ w: NSFont.Weight) -> NSFont {
  let f = NSFont.systemFont(ofSize: size, weight: w)
  if let d = f.fontDescriptor.withDesign(.rounded) { return NSFont(descriptor: d, size: size) ?? f }
  return f
}
func para(_ align: NSTextAlignment = .center) -> NSMutableParagraphStyle {
  let p = NSMutableParagraphStyle(); p.alignment = align; p.baseWritingDirection = .rightToLeft; p.lineSpacing = 6; return p
}
func bitmap(_ w: Int, _ h: Int) -> NSBitmapImageRep {
  NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}
func save(_ rep: NSBitmapImageRep, _ path: String) { try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path)) }
func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: CGFloat((v>>16)&255)/255, green: CGFloat((v>>8)&255)/255, blue: CGFloat(v&255)/255, alpha: a) }

let a = CommandLine.arguments
if a[1] == "sub" {
  let text = a[3].replacingOccurrences(of: "\\n", with: "\n")
  var size: CGFloat = 54
  var attr: NSAttributedString
  var bounds: CGRect
  repeat {
    let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.5); shadow.shadowBlurRadius = 4; shadow.shadowOffset = NSSize(width: 0, height: -2)
    attr = NSAttributedString(string: text, attributes: [.font: rounded(size, .bold), .foregroundColor: NSColor.white, .paragraphStyle: para(), .shadow: shadow])
    bounds = attr.boundingRect(with: NSSize(width: 4000, height: 2000), options: [.usesLineFragmentOrigin, .usesFontLeading])
    if bounds.width <= 940 { break }
    size -= 2
  } while size > 36
  let padX: CGFloat = 40, padY: CGFloat = 22
  let W = Int(ceil(bounds.width + padX*2)), H = Int(ceil(bounds.height + padY*2))
  let rep = bitmap(W, H)
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let box = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: W, height: H), xRadius: 28, yRadius: 28)
  NSColor(srgbRed: 0.08, green: 0.05, blue: 0.22, alpha: 0.72).setFill(); box.fill()
  NSColor(white: 1, alpha: 0.18).setStroke(); box.lineWidth = 2; box.stroke()
  attr.draw(with: NSRect(x: CGFloat(W)/2 - 1500, y: padY, width: 3000, height: bounds.height + 4), options: [.usesLineFragmentOrigin, .usesFontLeading])
  NSGraphicsContext.restoreGraphicsState()
  save(rep, a[2])
  print("\(W)x\(H) font=\(size)")
} else if a[1] == "card" {
  let rep = bitmap(1080, 1920)
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  NSGradient(starting: hex(0x6C4DE0), ending: hex(0x3E8BF0))!.draw(in: NSRect(x: 0, y: 0, width: 1080, height: 1920), angle: -60)
  let lion = NSImage(contentsOfFile: a[3])!
  let lh: CGFloat = 640, lw = lh * lion.size.width / lion.size.height
  lion.draw(in: NSRect(x: (1080-lw)/2, y: 1920-260-lh, width: lw, height: lh))
  func line(_ s: String, _ size: CGFloat, _ w: NSFont.Weight, _ y: CGFloat, _ color: NSColor = .white) {
    let sh = NSShadow(); sh.shadowColor = NSColor(white: 0, alpha: 0.35); sh.shadowBlurRadius = 10; sh.shadowOffset = NSSize(width: 0, height: -3)
    let at = NSAttributedString(string: s, attributes: [.font: rounded(size, w), .foregroundColor: color, .paragraphStyle: para(), .shadow: sh])
    at.draw(with: NSRect(x: 40, y: y, width: 1000, height: size * 1.6), options: [.usesLineFragmentOrigin])
  }
  line("טופי", 150, .heavy, 1920-1130)
  line("זמן מסך שמרוויחים בלמידה", 60, .bold, 1920-1250)
  // pill with the site
  let pill = NSBezierPath(roundedRect: NSRect(x: 240, y: 1920-1470, width: 600, height: 120), xRadius: 60, yRadius: 60)
  NSColor.white.setFill(); pill.fill()
  line("tofyapp.com", 64, .heavy, 1920-1455, hex(0x5B3FD0))
  line("להורדה ב-App Store", 50, .semibold, 1920-1580)
  NSGraphicsContext.restoreGraphicsState()
  save(rep, a[2])
}
