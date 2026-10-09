#if DEBUG
import UIKit

/// 📏 DEMO_HITCHES=1 (DEBUG only): logs every frame that took longer than two
/// display intervals, with the time since the last answer tap — to find what
/// still stutters after an answer.
final class HitchMonitor: NSObject {
    static let shared = HitchMonitor()
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    var lastTap: CFTimeInterval = 0

    func start() {
        guard link == nil, ProcessInfo.processInfo.environment["DEMO_HITCHES"] != nil else { return }
        link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
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
