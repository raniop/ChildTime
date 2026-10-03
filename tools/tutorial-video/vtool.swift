import AVFoundation
import AppKit
let a = CommandLine.arguments
let sem = DispatchSemaphore(value: 0)
Task {
  let asset = AVURLAsset(url: URL(fileURLWithPath: a[2]))
  if a[1] == "probe" {
    let d = try await asset.load(.duration)
    if let tr = try await asset.loadTracks(withMediaType: .video).first {
      let s = try await tr.load(.naturalSize); let f = try await tr.load(.nominalFrameRate)
      print(String(format: "%@ dur=%.2f size=%.0fx%.0f fps=%.1f", (a[2] as NSString).lastPathComponent, d.seconds, s.width, s.height, f))
    } else { print(String(format: "%@ dur=%.3f", (a[2] as NSString).lastPathComponent, d.seconds)) }
  } else if a[1] == "frame" {
    let g = AVAssetImageGenerator(asset: asset); g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
    g.maximumSize = CGSize(width: Double(a.count > 5 ? a[5] : "700")!, height: 3000)
    let (img, _) = try await g.image(at: CMTime(seconds: Double(a[3])!, preferredTimescale: 600))
    let rep = NSBitmapImageRep(cgImage: img)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[4]))
  }
  sem.signal()
}
sem.wait()
