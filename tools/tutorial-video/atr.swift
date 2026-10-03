import AVFoundation
let s = DispatchSemaphore(value: 0)
Task { for p in CommandLine.arguments.dropFirst() { let a = AVURLAsset(url: URL(fileURLWithPath: p)); let t = try! await a.loadTracks(withMediaType: .audio); let v = try! await a.loadTracks(withMediaType: .video)
 var fmts: [String] = []; for tr in t+v { for d in try! await tr.load(.formatDescriptions) { let c = CMFormatDescriptionGetMediaSubType(d); fmts.append(String(bytes: withUnsafeBytes(of: c.bigEndian, Array.init), encoding: .ascii)!) } }
 print((p as NSString).lastPathComponent, "audio:", t.count, "video:", v.count, fmts, String(format: "%.2f", try! await a.load(.duration).seconds)) }; s.signal() }
s.wait()
