import Foundation

/// 🕐 The one place that decides "was this already used today?".
///
/// Every once-per-day gate in the app compares a stored stamp against the
/// DEVICE clock, and `Calendar.isDateInToday` answers **false** for a stamp in
/// the FUTURE. A child can move the clock forward in Settings → Date & Time, and
/// that one jump used to permanently unlock every daily reward — the daily
/// chest, the daily challenge, the boss jackpot, the comeback wheel, the variety
/// bonus, the per-topic anti-grind cap — and it also zeroed the daily
/// screen-time caps, because a future `dailyEarnedDate` read as "not today".
///
/// The rule everywhere is therefore: a stamp dated **today or later** counts as
/// already used. A future stamp is never legitimate, so treating it as spent is
/// both the safe direction and self-correcting the moment the clock is honest
/// again. (Rani: the app must be trustworthy for parents — a kid who finds the
/// clock must not be able to mint rewards.)
enum DayGate {
    /// True when `stamp` falls on today or any later day.
    static func usedToday(_ stamp: Date?) -> Bool {
        guard let stamp else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: stamp) >= cal.startOfDay(for: Date())
    }

    /// Unix-seconds variant — chore docs store their stamps as `Double`.
    static func usedToday(unixSeconds: Double?) -> Bool {
        guard let t = unixSeconds else { return false }
        return usedToday(Date(timeIntervalSince1970: t))
    }

    /// A stored "day" that is AHEAD of today is corrupt (clock tampering, or a
    /// future-dated snapshot merged in from a peer). Callers use this to force a
    /// rollover instead of trusting the stamp forever.
    static func isFutureDay(_ stamp: Date?) -> Bool {
        guard let stamp else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: stamp) > cal.startOfDay(for: Date())
    }
}
