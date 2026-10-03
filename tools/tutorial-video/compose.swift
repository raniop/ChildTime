import AVFoundation
import CoreGraphics
import VideoToolbox
import AppKit

struct Clip: Codable { let file: String?; let from: Double?; let dur: Double; let kind: String; let image: String? }
struct Sub: Codable { let png: String; let from: Double; let to: Double; let fin: Bool; let fout: Bool }
struct Spec: Codable { let out: String; let fps: Int; let clips: [Clip]; let subs: [Sub]; let xfade: Double }

let W = 1080, H = 1920
let spec = try! JSONDecoder().decode(Spec.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let bmInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

func loadImage(_ p: String) -> CGImage {
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil)!
  return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}
func hexc(_ v: UInt32, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: CGFloat((v>>16)&255)/255, green: CGFloat((v>>8)&255)/255, blue: CGFloat(v&255)/255, alpha: a) }
func newCtx() -> CGContext { CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W*4, space: cs, bitmapInfo: bmInfo)! }

// Layout rects (CG coords, origin bottom-left). Video area top 60..1600 in top-down coords.
func rectFor(kind: String, srcW: Int, srcH: Int) -> (CGRect, CGFloat) {
  let areaTop: CGFloat = 60, areaH: CGFloat = 1540, areaW: CGFloat = kind == "ipad" ? 1000 : 1000
  let s = min(areaW / CGFloat(srcW), areaH / CGFloat(srcH))
  let w = (CGFloat(srcW) * s).rounded(), h = (CGFloat(srcH) * s).rounded()
  let x = ((CGFloat(W) - w) / 2).rounded(), yTop = areaTop + ((areaH - h) / 2).rounded()
  let radius: CGFloat = kind == "ipad" ? 34 : 88
  return (CGRect(x: x, y: CGFloat(H) - yTop - h, width: w, height: h), radius)
}

// Background gradient
func drawGradient(_ c: CGContext) {
  let g = CGGradient(colorsSpace: cs, colors: [hexc(0x6C4DE0), hexc(0x3E8BF0)] as CFArray, locations: [0, 1])!
  c.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: CGFloat(W), y: 0), options: [])
  // soft glow blobs
  let glow = CGGradient(colorsSpace: cs, colors: [hexc(0xF06EDB, 0.35), hexc(0xF06EDB, 0)] as CFArray, locations: [0, 1])!
  c.drawRadialGradient(glow, startCenter: CGPoint(x: 900, y: 1600), startRadius: 0, endCenter: CGPoint(x: 900, y: 1600), endRadius: 600, options: [])
  let glow2 = CGGradient(colorsSpace: cs, colors: [hexc(0x2FD4E0, 0.30), hexc(0x2FD4E0, 0)] as CFArray, locations: [0, 1])!
  c.drawRadialGradient(glow2, startCenter: CGPoint(x: 120, y: 300), startRadius: 0, endCenter: CGPoint(x: 120, y: 300), endRadius: 650, options: [])
}
var bgCache: [String: CGImage] = [:]
func background(kind: String, rect: CGRect, radius: CGFloat) -> CGImage {
  let key = "\(kind)-\(rect)"
  if let b = bgCache[key] { return b }
  let c = newCtx(); drawGradient(c)
  c.saveGState()
  c.setShadow(offset: CGSize(width: 0, height: -14), blur: 48, color: hexc(0x140A3C, 0.55))
  c.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
  c.setFillColor(hexc(0x000000)); c.fillPath()
  c.restoreGState()
  let img = c.makeImage()!; bgCache[key] = img; return img
}

// Sequential frame source for a clip
final class FrameSource {
  let reader: AVAssetReader; let out: AVAssetReaderTrackOutput
  var cur: CGImage?; var curT = -1.0; var pending: (Double, CGImage)?; var done = false
  let srcW: Int, srcH: Int
  init(file: String, from: Double, dur: Double) async throws {
    let asset = AVURLAsset(url: URL(fileURLWithPath: file))
    let tr = try await asset.loadTracks(withMediaType: .video).first!
    let sz = try await tr.load(.naturalSize); srcW = Int(sz.width); srcH = Int(sz.height)
    reader = try AVAssetReader(asset: asset)
    let total = try await asset.load(.duration).seconds
    let start = max(0, min(from, total - 0.05))
    reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: dur + 1, preferredTimescale: 600))
    out = AVAssetReaderTrackOutput(track: tr, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    out.alwaysCopiesSampleData = false
    reader.add(out); reader.startReading()
  }
  func next() -> (Double, CGImage)? {
    while let sb = out.copyNextSampleBuffer() {
      guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
      var img: CGImage?; VTCreateCGImageFromCVPixelBuffer(pb, options: nil, imageOut: &img)
      if let img { return (CMSampleBufferGetPresentationTimeStamp(sb).seconds, img) }
    }
    return nil
  }
  func frame(at t: Double) -> CGImage? {
    if cur == nil { if let f = next() { cur = f.1; curT = f.0 } }
    while !done {
      if pending == nil { pending = next(); if pending == nil { done = true; break } }
      if pending!.0 <= t { cur = pending!.1; curT = pending!.0; pending = nil } else { break }
    }
    return cur
  }
}

func run() async throws {
  let outURL = URL(fileURLWithPath: spec.out)
  try? FileManager.default.removeItem(at: outURL)
  let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
  let vin = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoMaxKeyFrameIntervalKey: 60],
    AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2, AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2, AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2]])
  vin.expectsMediaDataInRealTime = false
  let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
  writer.add(vin); writer.startWriting(); writer.startSession(atSourceTime: .zero)

  let subs = spec.subs.map { ($0, loadImage($0.png)) }
  let fps = Double(spec.fps)
  var frameNo = 0
  var prevComposed: CGImage? = nil
  var clipStart = 0.0
  for (ci, clip) in spec.clips.enumerated() {
    var src: FrameSource? = nil
    var cardImg: CGImage? = nil
    if clip.kind == "card" { cardImg = loadImage(clip.image!) } else { src = try await FrameSource(file: clip.file!, from: clip.from ?? 0, dur: clip.dur) }
    let clipEnd = clipStart + clip.dur
    var lastComposed: CGImage? = nil
    while Double(frameNo) / fps < clipEnd - 1e-6 {
      let t = Double(frameNo) / fps, local = t - clipStart
      let c = newCtx()
      if let cardImg { c.draw(cardImg, in: CGRect(x: 0, y: 0, width: W, height: H)) }
      else if let src, let img = src.frame(at: (clip.from ?? 0) + local) {
        let (r, rad) = rectFor(kind: clip.kind, srcW: src.srcW, srcH: src.srcH)
        c.draw(background(kind: clip.kind, rect: r, radius: rad), in: CGRect(x: 0, y: 0, width: W, height: H))
        c.saveGState(); c.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); c.clip()
        c.interpolationQuality = .high; c.draw(img, in: r); c.restoreGState()
      }
      // crossfade from previous clip's last frame
      if ci > 0, let prev = prevComposed, local < spec.xfade {
        let p = local / spec.xfade
        let ease = p * p * (3 - 2 * p)
        c.saveGState(); c.setAlpha(CGFloat(1 - ease)); c.draw(prev, in: CGRect(x: 0, y: 0, width: W, height: H)); c.restoreGState()
      }
      lastComposed = c.makeImage()
      // subtitles (with 0.15s fade)
      for (s, img) in subs where t >= s.from && t < s.to {
        let a = min(1, min(s.fin ? (t - s.from) / 0.15 : 1, s.fout ? (s.to - t) / 0.15 : 1))
        let w = CGFloat(img.width), h = CGFloat(img.height)
        let centerYTop: CGFloat = 1755
        let r = CGRect(x: ((CGFloat(W) - w) / 2).rounded(), y: (CGFloat(H) - centerYTop - h / 2).rounded(), width: w, height: h)
        c.saveGState(); c.setAlpha(CGFloat(a)); c.draw(img, in: r); c.restoreGState()
      }
      // write
      while !vin.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
      var pbOut: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pbOut)
      let pb = pbOut!; CVPixelBufferLockBaseAddress(pb, [])
      let dc = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: cs, bitmapInfo: bmInfo)!
      dc.draw(c.makeImage()!, in: CGRect(x: 0, y: 0, width: W, height: H))
      CVPixelBufferUnlockBaseAddress(pb, [])
      adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frameNo), timescale: CMTimeScale(spec.fps)))
      frameNo += 1
    }
    prevComposed = lastComposed
    clipStart = clipEnd
    FileHandle.standardError.write("clip \(ci) done @\(String(format: "%.2f", clipEnd))\n".data(using: .utf8)!)
  }
  vin.markAsFinished()
  await writer.finishWriting()
  print("wrote \(frameNo) frames, status \(writer.status.rawValue) \(writer.error?.localizedDescription ?? "")")
}
let sem = DispatchSemaphore(value: 0)
Task { do { try await run() } catch { print("ERROR \(error)") }; sem.signal() }
sem.wait()
