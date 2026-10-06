import Foundation

// MARK: - 🏫 School time and 🌙 bedtime (pure, framework-free, unit-testable)

/// The hours a parent sets aside — school, sleep — when the child's play
/// minutes do not open. Rani, 2026-10-06: "זמן בית ספר שמגדירים ואז אי אפשר
/// בזמן הזה לפתוח בכלל", and the same mechanism for bedtime.
///
/// What a quiet window does on the child's device:
///  * no EARNED or GIFT play window can open inside it;
///  * one that is open when it starts closes, and its leftover goes back to the
///    child's wallet to the second (nothing is ever lost);
///  * a window opened shortly before it starts is cut to end exactly at its start;
///  * the parent's own manual open still works (a parent can always override);
///  * Tofy and the parent's "always open" apps stay reachable — the child may
///    keep answering and bank minutes for later.
///
/// This file is shared by the app and both extensions (the background monitor
/// closes a window at the start even while Tofy is not running), so it holds
/// only plain Foundation types. Android mirrors it in `QuietHours.kt`; the
/// Firestore shape (`children/{id}.quietHours`) is the contract between them.
struct QuietWindow: Codable, Hashable, Sendable {
    var enabled: Bool
    /// Calendar weekdays the window STARTS on: 1 = Sunday … 7 = Saturday.
    /// A bedtime that starts Thursday evening and ends Friday morning is
    /// Thursday's.
    var days: [Int]
    /// Minutes after local midnight.
    var start: Int
    /// Minutes after local midnight. At or before `start` = ends the next day.
    var end: Int
    /// A different end on Friday — the short school day. nil = same as `end`.
    var fridayEnd: Int?

    func endMinute(weekday: Int) -> Int { weekday == 6 ? (fridayEnd ?? end) : end }
}

enum QuietKind: String, Codable, Sendable { case school, bedtime }

struct QuietHours: Codable, Hashable, Sendable {
    var school: QuietWindow?
    var bedtime: QuietWindow?
    /// "yyyy-MM-dd" on the child device's calendar: the parent's one-tap "no
    /// school today" (a holiday, a sick day). Only that date; tomorrow is normal.
    var schoolOffDay: String?
    /// Vacation: every school window is off until the parent turns it back on.
    var schoolPaused: Bool?

    init(school: QuietWindow? = nil, bedtime: QuietWindow? = nil,
         schoolOffDay: String? = nil, schoolPaused: Bool? = nil) {
        self.school = school
        self.bedtime = bedtime
        self.schoolOffDay = schoolOffDay
        self.schoolPaused = schoolPaused
    }

    /// Sunday–Friday 08:00–13:30, Friday until 12:00.
    static let schoolDefault = QuietWindow(enabled: true, days: [1, 2, 3, 4, 5, 6],
                                           start: 8 * 60, end: 13 * 60 + 30, fridayEnd: 12 * 60)
    /// Every night 20:30–07:00.
    static let bedtimeDefault = QuietWindow(enabled: true, days: [1, 2, 3, 4, 5, 6, 7],
                                            start: 20 * 60 + 30, end: 7 * 60)

    var isEmpty: Bool { !(school?.enabled ?? false) && !(bedtime?.enabled ?? false) }

    struct Occurrence: Equatable, Sendable {
        let kind: QuietKind
        let start: Date
        let end: Date
    }

    /// "2026-10-06" — the key `schoolOffDay` is compared against.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Every quiet occurrence that STARTS on a day from `fromDay` to `toDay`
    /// days around `date`'s day (inclusive), in start order.
    func occurrences(around date: Date, fromDay: Int = -1, toDay: Int = 8,
                     calendar: Calendar = .current) -> [Occurrence] {
        let today = calendar.startOfDay(for: date)
        var out: [Occurrence] = []
        for offset in fromDay...toDay {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            for (kind, window) in [(QuietKind.school, school), (.bedtime, bedtime)] {
                guard let w = window, w.enabled, w.days.contains(weekday) else { continue }
                if kind == .school {
                    if schoolPaused == true { continue }
                    if let off = schoolOffDay, off == Self.dayKey(day, calendar: calendar) { continue }
                }
                let endMin = w.endMinute(weekday: weekday)
                guard endMin != w.start,
                      let s = calendar.date(byAdding: .minute, value: w.start, to: day),
                      let e = calendar.date(byAdding: .minute,
                                            value: endMin + (endMin < w.start ? 24 * 60 : 0),
                                            to: day) else { continue }
                out.append(Occurrence(kind: kind, start: s, end: e))
            }
        }
        return out.sorted { $0.start < $1.start }
    }

    /// The quiet time in force at `now`, if any. Back-to-back or overlapping
    /// windows read as one (bedtime until 07:00 then school from 07:00 → quiet
    /// until school ends), so a child is never handed a few seconds of play in
    /// the seam between them.
    func active(at now: Date, calendar: Calendar = .current) -> Occurrence? {
        let all = occurrences(around: now, calendar: calendar)
        guard var cur = all.filter({ $0.start <= now && now < $0.end })
                           .max(by: { $0.end < $1.end }) else { return nil }
        var grew = true
        while grew {
            grew = false
            for o in all where o.start <= cur.end && o.end > cur.end {
                cur = Occurrence(kind: cur.kind, start: cur.start, end: o.end)
                grew = true
            }
        }
        return cur
    }

    /// When the next quiet time starts after `now` (nil = none within a week).
    func nextStart(after now: Date, calendar: Calendar = .current) -> Date? {
        occurrences(around: now, fromDay: 0, toDay: 8, calendar: calendar)
            .first { $0.start > now }?.start
    }

    /// The most seconds a play window opened at `now` may last: until the next
    /// quiet time starts. 0 while quiet; nil when nothing is coming.
    func secondsUntilQuiet(from now: Date, calendar: Calendar = .current) -> Int? {
        if active(at: now, calendar: calendar) != nil { return 0 }
        return nextStart(after: now, calendar: calendar).map { max(0, Int($0.timeIntervalSince(now))) }
    }
}

/// Where the child device keeps its own copy, so the background monitor (no
/// network, no Firebase) can decide on its own at the moment a window starts.
enum QuietHoursStore {
    static let key = "quietHours.v1"
    /// Set by the monitor when it closed a play window at a quiet start: the
    /// app settles the refund from this exact moment on its next wake.
    static let cutAtKey = "quietHours.cutAt"

    static func load(_ defaults: UserDefaults) -> QuietHours {
        guard let data = defaults.data(forKey: key),
              let q = try? JSONDecoder().decode(QuietHours.self, from: data) else { return QuietHours() }
        return q
    }

    static func save(_ q: QuietHours, _ defaults: UserDefaults) {
        if q.isEmpty { defaults.removeObject(forKey: key); return }
        if let data = try? JSONEncoder().encode(q) { defaults.set(data, forKey: key) }
    }
}
