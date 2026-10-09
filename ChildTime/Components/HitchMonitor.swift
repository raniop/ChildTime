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
        watch("Household", HouseholdManager.shared.objectWillChange)
        watch("Lease", PlayWindowLeaseManager.shared.objectWillChange)
        watch("Friends", FriendsManager.shared.objectWillChange)
        watch("LiveGame", LiveGameManager.shared.objectWillChange)
        watch("KidMode", KidModeManager.shared.objectWillChange)
        watch("Quiet", QuietHoursManager.shared.objectWillChange)
        watch("PackStore", PackStore.shared.objectWillChange)
        watch("Conversion", ConversionConfig.shared.objectWillChange)
        watch("Campaign", CampaignTracker.shared.objectWillChange)
        watch("Chores", ChoreStore.shared.objectWillChange)
        watch("Display", DisplayGeometry.shared.objectWillChange)
        watch("Shields", ShieldManager.shared.objectWillChange)
        watch("Subs", SubscriptionManager.shared.objectWillChange)
        watch("Auth", AuthManager.shared.objectWillChange)
        watch("Location", LocationSharing.shared.objectWillChange)
        watch("JoinCoord", JoinCoordinator.shared.objectWillChange)
        // Any UserDefaults write — @AppStorage views redraw on these.
        watch("Defaults", NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification))
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

/// 📏 `let _ = BodyLog.hit("X")` inside a body: logs each re-evaluation
/// against the last answer tap when DEMO_HITCHES is on. Free in Release.
enum BodyLog {
    @inline(__always) @discardableResult
    static func hit(_ name: StaticString) -> Int {
        #if DEBUG
        if HitchMonitor.enabled {
            let tap = HitchMonitor.shared.lastTap
            NSLog("[Body] %@ at %.0fms after tap", "\(name)", tap > 0 ? (CACurrentMediaTime() - tap) * 1000 : -1)
        }
        #endif
        return 0
    }
}
