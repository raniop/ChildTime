import AppKit
let args = CommandLine.arguments
let out = args[1]; let files = Array(args[2...])
let h: CGFloat = 900
let imgs = files.compactMap { NSImage(contentsOfFile: $0) }
let ws = imgs.map { h * $0.size.width / $0.size.height }
let W = ws.reduce(0,+) + CGFloat(imgs.count+1)*10
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(h)+20, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.black.setFill(); NSRect(x:0,y:0,width:W,height:h+20).fill()
var x: CGFloat = 10
for (i,im) in imgs.enumerated() { im.draw(in: NSRect(x:x,y:10,width:ws[i],height:h)); x += ws[i]+10 }
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .jpeg, properties: [.compressionFactor:0.8])!.write(to: URL(fileURLWithPath: out))
