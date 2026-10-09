import UIKit
#if DEBUG
import Combine

/// 📏 DEMO_HITCHES=1 (DEBUG only): logs every frame that took longer than two
/// display intervals, with the time since the last answer tap — to find what
/// still stutters after an answer.
final class HitchMonitor: NSObject {
    static let shared = HitchMonitor()
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    var lastTap: CFTimeInterval = 0
    static let enabled = ProcessInfo.processInfo.environment["DEMO_HITCHES"] != nil

    func start() {
        guard link == nil, ProcessInfo.processInfo.environment["DEMO_HITCHES"] != nil else { return }
        link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
    }

    private var watches: [AnyCancellable] = []
    /// Logs every objectWillChange of the app-wide stores, against the last tap —
    /// a store that changes right before a hitch is what re-rendered.
    @MainActor func watchStores() {
        guard Self.enabled, watches.isEmpty else { return }
        func watch<P: Publisher>(_ name: String, _ p: P) where P.Failure == Never {
            watches.append(p.sink { [weak self] _ in
                let tap = self?.lastTap ?? 0
                NSLog("[Mark] willChange %@ at %.0fms after tap", name, tap > 0 ? (CACurrentMediaTime() - tap) * 1000 : -1)
            })
        }
        watch("ProgressStore", ProgressStore.shared.objectWillChange)
        watch("RemoteSync", RemoteSyncManager.shared.objectWillChange)
        watch("ProfileStore", ProfileStore.shared.objectWillChange)
        watch("CosmeticStore", CosmeticStore.shared.objectWillChange)
        watch("ParentSettings", ParentSettings.shared.objectWillChange)
    }

    @objc private func tick(_ l: CADisplayLink) {
        defer { last = l.timestamp }
        guard last > 0 else { return }
        let dt = (l.timestamp - last) * 1000
        if dt > 22 {
            let since = lastTap > 0 ? (l.timestamp - lastTap) * 1000 : -1
            NSLog("[Hitch] frame %.0fms, %.0fms after tap", dt, since)
        }
    }
}
#endif

/// 📏 Times a block and logs it against the last answer tap when DEMO_HITCHES
/// is on — so a hitch on the device can be pinned to the work that caused it
/// (the profiler can't attach there). A plain call-through in Release.
enum PerfMark {
    @inline(__always)
    static func run<T>(_ label: StaticString, _ body: () throws -> T) rethrows -> T {
        #if DEBUG
        guard HitchMonitor.enabled else { return try body() }
        let t0 = CACurrentMediaTime()
        let result = try body()
        let t1 = CACurrentMediaTime()
        let tap = HitchMonitor.shared.lastTap
        NSLog("[Mark] %@ %.1fms, at %.0fms after tap", "\(label)", (t1 - t0) * 1000, tap > 0 ? (t0 - tap) * 1000 : -1)
        return result
        #else
        return try body()
        #endif
    }
}
