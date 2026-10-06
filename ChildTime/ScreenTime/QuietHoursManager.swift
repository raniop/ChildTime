import Foundation
import Combine
import DeviceActivity
import os.log

/// 🏫🌙 School time and bedtime on the CHILD's device: keeps the active child's
/// `QuietHours` where the background monitor can read it, asks iOS to wake the
/// monitor at each start, and closes an open play window when one begins.
///
/// The rules themselves live in `ShieldCore/QuietHours.swift` (shared with the
/// extensions). This class is the app's side of them:
///  * `sync()` — the active child's hours → app group + DeviceActivity schedules;
///  * `settle()` — a quiet time began while a window was open → close it and
///    give back what was left AT THAT MOMENT (the monitor marks the moment;
///    the refund needs the app, which owns the wallet and the cloud lease);
///  * `blockedMessage()` — the child's line when they try to open minutes inside one.
///
/// A parent's phone never applies quiet hours: they belong to the child's device.
@MainActor
final class QuietHoursManager: ObservableObject {
    static let shared = QuietHoursManager()

    /// The quiet time in force right now on this device, refreshed every 20 s
    /// while the app is open — the home screen's 🏫/🌙 line reads it.
    @Published private(set) var current: QuietHours.Occurrence?

    static let schoolActivity = DeviceActivityName("childtime.quiet.school")
    static let bedtimeActivity = DeviceActivityName("childtime.quiet.bedtime")

    private var bag = Set<AnyCancellable>()
    private var lastScheduled: QuietHours?

    private init() {
        ProfileStore.shared.$profiles.combineLatest(ProfileStore.shared.$activeID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.sync() }
            .store(in: &bag)
        Timer.publish(every: 20, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &bag)
    }

    /// Call once at launch so the observers above exist.
    func start() { sync() }

    /// This device's hours: the active child's, on a child device only.
    var hours: QuietHours {
        guard ParentSettings.shared.deviceRole == .child || AppInfo.isDemoRun,
              let q = ProfileStore.shared.active?.quietHours else { return QuietHours() }
        return q
    }

    func sync() {
        let q = hours
        QuietHoursStore.save(q, AppGroup.defaults)
        current = q.active(at: Date())
        guard q != lastScheduled else { return }
        lastScheduled = q
        schedule(q)
    }

    private func tick() {
        let now = hours.active(at: Date())
        if now != current { current = now }
        if now != nil { settle() }
    }

    /// One daily wake-up per kind, at its start. The monitor decides on waking
    /// whether today counts (days, "no school today", vacation) — so a change of
    /// days needs no re-registration, and only two of iOS's ~20 slots are used.
    /// The interval is 15 minutes because iOS refuses anything shorter; only its
    /// start matters.
    private func schedule(_ q: QuietHours) {
        let center = DeviceActivityCenter()
        center.stopMonitoring([Self.schoolActivity, Self.bedtimeActivity])
        for (name, window) in [(Self.schoolActivity, q.school), (Self.bedtimeActivity, q.bedtime)] {
            guard let w = window, w.enabled, !w.days.isEmpty else { continue }
            let s = w.start, e = (w.start + 15) % (24 * 60)
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: s / 60, minute: s % 60),
                intervalEnd: DateComponents(hour: e / 60, minute: e % 60),
                repeats: true)
            do {
                try center.startMonitoring(name, during: schedule)
                screenTimeLog.notice("quiet: \(name.rawValue, privacy: .public) wakes daily at \(s / 60, privacy: .public):\(s % 60, privacy: .public)")
            } catch {
                screenTimeLog.error("quiet: could not schedule \(name.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// A quiet time started while a play window was open → close it with the
    /// leftover from that moment, and lock. The parent's own manual open is left
    /// alone (a parent can always override). Safe to call any time.
    @discardableResult
    func settle(now: Date = Date()) -> Bool {
        let d = AppGroup.defaults
        let marked = d.object(forKey: QuietHoursStore.cutAtKey) as? Date
        d.removeObject(forKey: QuietHoursStore.cutAtKey)
        let progress = ProgressStore.shared
        // A marker older than the open window belongs to a window that is gone.
        var cut = marked.flatMap { m in (progress.unlockOpenedAt.map { $0 > m } ?? false) ? nil : m }
        if cut == nil, let occ = hours.active(at: now) {
            // The monitor did not mark it (it never woke, or the window opened
            // before this build): cut at the later of the quiet start and the
            // window's own start.
            cut = max(occ.start, progress.unlockOpenedAt ?? occ.start)
        }
        guard let at = cut, progress.closeForQuietTime(at: at) else { return false }
        ShieldManager.shared.relockBaseline()
        screenTimeLog.notice("quiet: closed the open play window at \(at, privacy: .public)")
        return true
    }

    /// The child's line when they try to open minutes inside a quiet time; nil
    /// when nothing stops them. Never failure language — the minutes are safe
    /// and the line says when they come back.
    func blockedMessage(now: Date = Date()) -> String? {
        guard let occ = hours.active(at: now) else { return nil }
        let at = Self.clock(occ.end)
        switch occ.kind {
        case .school:
            return Gendered.g(tr("🏫 עַכְשָׁיו זְמַן בֵּית סֵפֶר — הַדַּקּוֹת שֶׁלְּךָ מְחַכּוֹת לְךָ בְּ-\(at)"),
                              tr("🏫 עַכְשָׁיו זְמַן בֵּית סֵפֶר — הַדַּקּוֹת שֶׁלָּךְ מְחַכּוֹת לָךְ בְּ-\(at)"))
        case .bedtime:
            return Gendered.g(tr("🌙 עַכְשָׁיו שְׁעַת שֵׁינָה — הַדַּקּוֹת שֶׁלְּךָ מְחַכּוֹת לְךָ בְּ-\(at)"),
                              tr("🌙 עַכְשָׁיו שְׁעַת שֵׁינָה — הַדַּקּוֹת שֶׁלָּךְ מְחַכּוֹת לָךְ בְּ-\(at)"))
        }
    }

    /// "13:30" — the device's own 24-hour clock.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
