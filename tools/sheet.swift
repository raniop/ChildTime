import AVFoundation
import AppKit
import Foundation

// A contact sheet of one recording: N frames in a row, each labelled with its
// timestamp, so the right segment can be picked by looking instead of guessing.
let a = CommandLine.arguments
let src = URL(fileURLWithPath: a[1]), out = URL(fileURLWithPath: a[2])
let times = a[3...].map { Double($0)! }
let asset = AVURLAsset(url: src)
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.maximumSize = CGSize(width: 240, height: 520)
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero

let sem = DispatchSemaphore(value: 0)
Task {
    var imgs: [(Double, CGImage)] = []
    for t in times {
        if let im = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)).image { imgs.append((t, im)) }
    }
    guard let first = imgs.first?.1 else { exit(1) }
    let w = CGFloat(first.width), h = CGFloat(first.height) + 22
    let canvas = NSImage(size: NSSize(width: w * CGFloat(imgs.count), height: h))
    canvas.lockFocus()
    NSColor.black.setFill(); NSRect(x: 0, y: 0, width: w * CGFloat(imgs.count), height: h).fill()
    for (i, pair) in imgs.enumerated() {
        let rep = NSBitmapImageRep(cgImage: pair.1)
        rep.draw(in: NSRect(x: CGFloat(i) * w, y: 22, width: w, height: CGFloat(pair.1.height)))
        ("\(pair.0)s" as NSString).draw(at: NSPoint(x: CGFloat(i) * w + 6, y: 3),
            withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.boldSystemFont(ofSize: 14)])
    }
    canvas.unlockFocus()
    let tiff = canvas.tiffRepresentation!
    let jpg = NSBitmapImageRep(data: tiff)!.representation(using: .jpeg, properties: [.compressionFactor: 0.8])!
    try! jpg.write(to: out)
    print("→ \(out.lastPathComponent)")
    sem.signal()
}
sem.wait()
