import AVFoundation
import AppKit
import Foundation

// Trim a simulator screen recording and export it as the site's hero loop:
// 640×1392, h264, no audio. ffmpeg on this Mac is an x86 binary, so the export
// goes through AVFoundation.
//   swift mkvideo.swift <in.mov> <out.mp4> <start> <duration> [posterAt] [poster.jpg]
let a = CommandLine.arguments
guard a.count >= 5 else { fputs("usage: mkvideo <in> <out> <start> <dur> [posterAt] [poster]\n", stderr); exit(2) }
let src = URL(fileURLWithPath: a[1]), dst = URL(fileURLWithPath: a[2])
let start = Double(a[3])!, dur = Double(a[4])!

let asset = AVURLAsset(url: src)
let sem = DispatchSemaphore(value: 0)

Task {
    let track = try! await asset.loadTracks(withMediaType: .video).first!
    let natural = try! await track.load(.naturalSize)
    let scale = min(640 / natural.width, 1392 / natural.height)
    let target = CGSize(width: (natural.width * scale).rounded(.down) - (Int((natural.width * scale)) % 2 == 0 ? 0 : 1),
                        height: (natural.height * scale).rounded(.down) - (Int((natural.height * scale)) % 2 == 0 ? 0 : 1))

    let comp = AVMutableComposition()
    let vt = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                            duration: CMTime(seconds: dur, preferredTimescale: 600))
    try! vt.insertTimeRange(range, of: track, at: .zero)

    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: vt)
    layer.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: .zero)
    let inst = AVMutableVideoCompositionInstruction()
    inst.timeRange = CMTimeRange(start: .zero, duration: comp.duration)
    inst.layerInstructions = [layer]
    let vc = AVMutableVideoComposition()
    vc.instructions = [inst]
    vc.frameDuration = CMTime(value: 1, timescale: 30)
    vc.renderSize = target

    // AVAssetExportSession's presets tie bitrate to a fixed resolution ladder:
    // 1280x720 kept the size but shipped 16 MB, and MediumQuality shrank the
    // picture to 220x480. Reader + writer keeps the render size and sets the
    // bitrate directly — the existing Hebrew and English loops are ~4 MB.
    try? FileManager.default.removeItem(at: dst)
    let reader = try! AVAssetReader(asset: comp)
    let output = AVAssetReaderVideoCompositionOutput(videoTracks: comp.tracks(withMediaType: .video),
        videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    output.videoComposition = vc
    reader.add(output)
    let writer = try! AVAssetWriter(outputURL: dst, fileType: .mp4)
    let bitrate = Int(ProcessInfo.processInfo.environment["BITRATE"] ?? "1200000")!
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: Int(target.width), AVVideoHeightKey: Int(target.height),
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: 60,
        ],
    ])
    input.expectsMediaDataInRealTime = false
    writer.shouldOptimizeForNetworkUse = true
    writer.add(input)
    writer.startWriting(); writer.startSession(atSourceTime: .zero); reader.startReading()
    let queue = DispatchQueue(label: "write")
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        input.requestMediaDataWhenReady(on: queue) {
            while input.isReadyForMoreMediaData {
                if let buf = output.copyNextSampleBuffer() { input.append(buf) }
                else { input.markAsFinished(); writer.finishWriting { c.resume() }; return }
            }
        }
    }
    if writer.status != .completed { fputs("export failed: \(writer.error?.localizedDescription ?? "?")\n", stderr); exit(1) }
    print("\(Int(target.width))x\(Int(target.height)) · \(dur)s → \(dst.lastPathComponent)")

    if a.count >= 7 {                       // a poster frame from the same take
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = target
        let img = try! await gen.image(at: CMTime(seconds: Double(a[5])!, preferredTimescale: 600)).image
        let rep = NSBitmapImageRep(cgImage: img)
        let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])!
        try! jpg.write(to: URL(fileURLWithPath: a[6]))
        print("poster → \(a[6])")
    }
    sem.signal()
}
sem.wait()
