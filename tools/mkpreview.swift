import AVFoundation
import Foundation

// Trim a simulator screen recording and export it as an App Store App Preview:
// 886×1920 (the 6.9" iPhone portrait size), 30 fps, h264, plus a SILENT stereo
// AAC track — App Store Connect has rejected previews with no audio track at all.
// The picture is scaled to fill and centre-cropped (a 1320×2868 capture loses ~2 px
// top and bottom). Same reader → writer path as mkvideo.swift (ffmpeg here is x86).
// The cut is a list of ranges from the one recording, joined back to back — the
// launches between the UI test's beats (black frames, the splash) fall away.
// A range may name another recording — "other.mov@12.5-16" — so one beat can be
// re-shot without re-recording the whole take.
//   swift mkpreview.swift <in.mov> <out.mp4> <from-to,from-to,…> [W H]
let a = CommandLine.arguments
guard a.count >= 4 else { fputs("usage: mkpreview <in> <out> <from-to,…> [W H]\n", stderr); exit(2) }
let src = URL(fileURLWithPath: a[1]), dst = URL(fileURLWithPath: a[2])
let ranges: [(URL, Double, Double)] = a[3].split(separator: ",").map { item in
    let parts = item.split(separator: "@")
    let file = parts.count == 2 ? URL(fileURLWithPath: String(parts[0])) : src
    let p = parts.last!.split(separator: "-").map { Double($0)! }; return (file, p[0], p[1])
}
let dur = ranges.reduce(0) { $0 + $1.2 - $1.1 }
let W = a.count >= 6 ? Int(a[4])! : 886, H = a.count >= 6 ? Int(a[5])! : 1920

let asset = AVURLAsset(url: src)
let sem = DispatchSemaphore(value: 0)

Task {
    let track = try! await asset.loadTracks(withMediaType: .video).first!
    let natural = try! await track.load(.naturalSize)
    var tracks: [URL: AVAssetTrack] = [src: track]
    var assets = [asset]                    // a track is only valid while its asset lives
    // FIT=1 letterboxes instead of filling — a portrait phone clip inside a landscape video.
    let fit = ProcessInfo.processInfo.environment["FIT"] == "1"
    let scale = fit ? min(CGFloat(W) / natural.width, CGFloat(H) / natural.height)
                    : max(CGFloat(W) / natural.width, CGFloat(H) / natural.height)
    let dx = (CGFloat(W) - natural.width * scale) / 2, dy = (CGFloat(H) - natural.height * scale) / 2

    let comp = AVMutableComposition()
    let vt = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    for (file, from, to) in ranges {
        if tracks[file] == nil {
            let other = AVURLAsset(url: file); assets.append(other)
            tracks[file] = try! await other.loadTracks(withMediaType: .video).first!
        }
        let range = CMTimeRange(start: CMTime(seconds: from, preferredTimescale: 600),
                                duration: CMTime(seconds: to - from, preferredTimescale: 600))
        try! vt.insertTimeRange(range, of: tracks[file]!, at: comp.duration)
    }

    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: vt)
    layer.setTransform(CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: dx, y: dy)), at: .zero)
    let inst = AVMutableVideoCompositionInstruction()
    inst.timeRange = CMTimeRange(start: .zero, duration: comp.duration)
    inst.layerInstructions = [layer]
    let vc = AVMutableVideoComposition()
    vc.instructions = [inst]
    vc.frameDuration = CMTime(value: 1, timescale: 30)
    vc.renderSize = CGSize(width: W, height: H)

    try? FileManager.default.removeItem(at: dst)
    let reader = try! AVAssetReader(asset: comp)
    let output = AVAssetReaderVideoCompositionOutput(videoTracks: comp.tracks(withMediaType: .video),
        videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    output.videoComposition = vc
    reader.add(output)
    let writer = try! AVAssetWriter(outputURL: dst, fileType: .mp4)
    let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 10_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoExpectedSourceFrameRateKey: 30,
            AVVideoMaxKeyFrameIntervalKey: 30,
        ],
    ])
    let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128_000,
    ])
    video.expectsMediaDataInRealTime = false; audio.expectsMediaDataInRealTime = false
    writer.add(video); writer.add(audio)
    writer.startWriting(); writer.startSession(atSourceTime: .zero); reader.startReading()

    // Silence, in 1024-frame PCM buffers, for the whole duration.
    var asbd = AudioStreamBasicDescription(mSampleRate: 44_100, mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked, mBytesPerPacket: 4,
        mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
    var fmt: CMAudioFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                   magicCookie: nil, extensions: nil, formatDescriptionOut: &fmt)
    let totalFrames = Int(dur * 44_100)
    var written = 0
    func silence() -> CMSampleBuffer? {
        guard written < totalFrames else { return nil }
        let n = min(1024, totalFrames - written)
        var block: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: n * 4, blockAllocator: nil,
            customBlockSource: nil, offsetToData: 0, dataLength: n * 4, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block)
        CMBlockBufferFillDataBytes(with: 0, blockBuffer: block!, offsetIntoDestination: 0, dataLength: n * 4)
        var sb: CMSampleBuffer?
        CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block!, formatDescription: fmt!,
            sampleCount: n, presentationTimeStamp: CMTime(value: CMTimeValue(written), timescale: 44_100),
            packetDescriptions: nil, sampleBufferOut: &sb)
        written += n
        return sb
    }

    let group = DispatchGroup()
    group.enter(); group.enter()
    video.requestMediaDataWhenReady(on: DispatchQueue(label: "v")) {
        while video.isReadyForMoreMediaData {
            if let buf = output.copyNextSampleBuffer() { video.append(buf) } else { video.markAsFinished(); group.leave(); return }
        }
    }
    audio.requestMediaDataWhenReady(on: DispatchQueue(label: "a")) {
        while audio.isReadyForMoreMediaData {
            if let buf = silence() { audio.append(buf) } else { audio.markAsFinished(); group.leave(); return }
        }
    }
    group.wait()
    await writer.finishWriting()
    if writer.status != .completed { fputs("export failed: \(writer.error?.localizedDescription ?? "?")\n", stderr); exit(1) }
    print("\(W)x\(H) · \(dur)s + silent audio → \(dst.lastPathComponent)")
    _ = assets
    sem.signal()
}
sem.wait()
