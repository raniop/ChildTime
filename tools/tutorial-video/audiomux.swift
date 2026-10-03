import AVFoundation
let a = CommandLine.arguments
let sr = 48000.0
let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sr, channels: 2, interleaved: false)!
func run() async throws {
  if a[1] == "mix" {
    let total = Double(a[3])!
    let n = AVAudioFrameCount(total * sr)
    let mixBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n)!; mixBuf.frameLength = n
    for ch in 0..<2 { memset(mixBuf.floatChannelData![ch], 0, Int(n) * 4) }
    var i = 4
    while i + 1 < a.count {
      let f = try AVAudioFile(forReading: URL(fileURLWithPath: a[i])); let at = Double(a[i+1])!; i += 2
      let inBuf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length))!
      try f.read(into: inBuf)
      let conv = AVAudioConverter(from: f.processingFormat, to: fmt)!
      let outCap = AVAudioFrameCount(Double(inBuf.frameLength) * sr / f.processingFormat.sampleRate + 1024)
      let outBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: outCap)!
      var fed = false
      var err: NSError?
      conv.convert(to: outBuf, error: &err) { _, st in if fed { st.pointee = .endOfStream; return nil }; fed = true; st.pointee = .haveData; return inBuf }
      let off = Int(at * sr)
      for ch in 0..<2 { let dst = mixBuf.floatChannelData![ch], s = outBuf.floatChannelData![ch]
        for k in 0..<Int(outBuf.frameLength) where off + k < Int(n) { dst[off + k] += s[k] } }
    }
    var peak: Float = 0
    for ch in 0..<2 { let d = mixBuf.floatChannelData![ch]; for k in 0..<Int(n) { peak = max(peak, abs(d[k])) } }
    if peak > 0 { let g = 0.89 / peak; for ch in 0..<2 { let d = mixBuf.floatChannelData![ch]; for k in 0..<Int(n) { d[k] *= g } } }
    let url = URL(fileURLWithPath: a[2]); try? FileManager.default.removeItem(at: url)
    let outF = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sr, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 160000], commonFormat: .pcmFormatFloat32, interleaved: false)
    try outF.write(from: mixBuf)
    print("mixed peak=\(peak)")
  } else if a[1] == "mux" {
    let v = AVURLAsset(url: URL(fileURLWithPath: a[2])), au = AVURLAsset(url: URL(fileURLWithPath: a[3]))
    let comp = AVMutableComposition()
    let vt = try await v.loadTracks(withMediaType: .video).first!
    let dur = try await v.load(.duration)
    let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try cv.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: vt, at: .zero)
    let at = try await au.loadTracks(withMediaType: .audio).first!
    let adur = try await au.load(.duration)
    let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try ca.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(dur, adur)), of: at, at: .zero)
    let out = URL(fileURLWithPath: a[4]); try? FileManager.default.removeItem(at: out)
    let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)!
    try await ex.export(to: out, as: .mp4)
    print("muxed")
  }
}
let sem = DispatchSemaphore(value: 0)
Task { do { try await run() } catch { print("ERROR \(error)") }; sem.signal() }
sem.wait()
