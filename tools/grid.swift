import AppKit
import Foundation

// A labelled grid of screenshots, so a whole screen audit can be read in a few
// images instead of fifty.
//   swift tools/grid.swift <out.png> <columns> <cellWidth> <a.png> <b.png> …
let a = CommandLine.arguments
guard a.count > 4 else { fputs("usage: grid <out.png> <cols> <cellWidth> <png>…\n", stderr); exit(2) }
let out = URL(fileURLWithPath: a[1])
let cols = Int(a[2])!, cellW = CGFloat(Double(a[3])!)
let files = Array(a[4...])

let images = files.compactMap { f -> (String, NSImage)? in
    guard let im = NSImage(contentsOfFile: f) else { return nil }
    return ((f as NSString).lastPathComponent.replacingOccurrences(of: ".png", with: ""), im)
}
guard let first = images.first?.1 else { exit(1) }
let cellH = cellW * first.size.height / first.size.width
let label: CGFloat = 26
let rows = (images.count + cols - 1) / cols
let size = NSSize(width: cellW * CGFloat(cols), height: (cellH + label) * CGFloat(rows))

let canvas = NSImage(size: size)
canvas.lockFocus()
NSColor(white: 0.08, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
    .foregroundColor: NSColor.white,
]
for (i, pair) in images.enumerated() {
    let col = i % cols, row = i / cols
    let x = CGFloat(col) * cellW
    let yTop = size.height - CGFloat(row) * (cellH + label)
    pair.1.draw(in: NSRect(x: x + 2, y: yTop - label - cellH + 2, width: cellW - 4, height: cellH - 4))
    (pair.0 as NSString).draw(at: NSPoint(x: x + 8, y: yTop - label + 5), withAttributes: attrs)
}
canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: out)
print("→ \(out.lastPathComponent) · \(images.count) screens")
