import Foundation

/// When to ask a PARENT for an App Store rating (Apple's system sheet, never
/// shown on a child's device — Kids Category). The moment is the parent
/// looking at a report that shows real learning: the child has played on
/// several days and answered a meaningful number of questions. Apple itself
/// caps the sheet at 3 per year; we ask at most once per 120 days, and never
/// on the first day a parent opens reports.
enum ReviewPrompter {
    static let minActiveDays = 3
    static let minAnswered = 60
    static let cooldownDays = 120

    private static let lastAskedKey = "review.lastAskedAt"
    private static let firstReportKey = "review.firstReportSeenAt"

    /// True when the report the parent is looking at is a good moment to ask.
    static func shouldAsk(history: [DailyStat], totalAnswered: Int, now: Date = .now) -> Bool {
        guard !AppInfo.isDemoRun else { return false }
        let d = UserDefaults.standard
        // The first report the parent ever opens only starts the clock.
        guard let firstSeen = d.object(forKey: firstReportKey) as? Date else {
            d.set(now, forKey: firstReportKey)
            return false
        }
        guard now.timeIntervalSince(firstSeen) >= 86_400 else { return false }
        if let last = d.object(forKey: lastAskedKey) as? Date,
           now.timeIntervalSince(last) < Double(cooldownDays) * 86_400 { return false }
        let activeDays = history.filter { $0.questionsAnswered > 0 }.count
        return activeDays >= minActiveDays && totalAnswered >= minAnswered
    }

    static func markAsked(now: Date = .now) {
        UserDefaults.standard.set(now, forKey: lastAskedKey)
    }
}
