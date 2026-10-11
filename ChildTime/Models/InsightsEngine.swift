import Foundation

/// Turns a child's raw `DailyStat` history + `LearningProfile` into the summaries
/// the parent dashboard shows: today, this week, this month, per-topic confidence,
/// strengths/challenges, and week-over-week improvement. Pure value type.
struct InsightsEngine {
    let history: [DailyStat]        // ascending by date
    let profile: LearningProfile

    init(history: [DailyStat], profile: LearningProfile) {
        self.history = history.sorted { $0.date < $1.date }
        self.profile = profile
    }

    // MARK: - Period summaries

    struct PeriodSummary {
        var questions = 0
        var correct = 0
        var wrong = 0
        var minutesEarned = 0
        var minutesUsed = 0
        var longestStreak = 0
        var learningMinutes = 0
        var sessions = 0
        var earnSessions = 0
        var freeSessions = 0
        var voluntaryAnswers = 0
        var activeDays = 0
        var accuracy: Double { questions > 0 ? Double(correct) / Double(questions) : 0 }
        /// Share of answers the child gave AFTER hitting the daily minute-max —
        /// i.e. learning purely for its own sake, not to earn time. The headline
        /// "is this becoming a real learning engine?" signal.
        var voluntaryLearningRate: Double {
            questions > 0 ? Double(voluntaryAnswers) / Double(questions) : 0
        }
    }

    var today: PeriodSummary {
        let key = LearningHistoryStore.dayKey(Date())
        return summarize(history.filter { $0.date == key })
    }

    /// Last 7 calendar days (including today).
    var thisWeek: PeriodSummary { summarize(daysInLast(7)) }

    // MARK: 📅 The calendar week (what the parent's report calls "השבוע")

    /// "Now", replaceable in tests — a calendar week depends on which weekday it is.
    static var clock: () -> Date = { Date() }

    /// The first day of the week `date` is in: Sunday in Hebrew, the phone's own
    /// first weekday in the other languages.
    static func weekStart(of date: Date = clock()) -> Date {
        var cal = Calendar.current
        if LanguageStore.shared.current == .he { cal.firstWeekday = 1 }
        let day = cal.startOfDay(for: date)
        let back = (cal.component(.weekday, from: day) - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -back, to: day) ?? day
    }

    /// The days of a calendar week: `weeksBack` 0 is this week up to today, 1 is
    /// the whole week before it.
    func daysInCalendarWeek(weeksBack: Int = 0) -> [DailyStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Self.clock())
        guard let start = cal.date(byAdding: .day, value: -7 * weeksBack, to: Self.weekStart()) else { return [] }
        let keys = Set((0..<7).compactMap { i -> String? in
            guard let d = cal.date(byAdding: .day, value: i, to: start), d <= today else { return nil }
            return LearningHistoryStore.dayKey(d)
        })
        return history.filter { keys.contains($0.date) }
    }

    /// This week as a weekly calendar counts it: from its first day up to today.
    /// The report's "השבוע" used to mean "the last 7 days" while its chart showed
    /// the calendar week — on a Monday the numbers included last week and the
    /// chart did not (Rani approved the change, 2026-10-12).
    var calendarWeek: PeriodSummary { summarize(daysInCalendarWeek()) }

    /// Last 30 calendar days.
    var thisMonth: PeriodSummary { summarize(daysInLast(30)) }

    /// Week-over-week accuracy improvement, as a signed percentage-point delta.
    var weeklyAccuracyDelta: Double {
        let current = summarize(daysInLast(7)).accuracy
        let prior = summarize(daysInRange(from: 14, to: 7)).accuracy
        guard prior > 0 else { return 0 }
        return (current - prior) * 100
    }

    /// Total minutes earned this week minus last week.
    var weeklyMinutesDelta: Int {
        summarize(daysInLast(7)).minutesEarned - summarize(daysInRange(from: 14, to: 7)).minutesEarned
    }

    /// THE key product KPI: over the last 30 days, what share of sessions did the
    /// child start voluntarily (Free Learning) vs. to earn screen time. Rising =
    /// the product is becoming a real learning engine, not just a reward gate.
    var voluntaryLearningRate: Double { thisMonth.voluntaryLearningRate }

    // MARK: - Per-topic

    /// Confidence 0–100 for a topic, blending accuracy with how much we've seen
    /// (low exposure → pulled toward a neutral 50 so we don't over-claim).
    func confidence(for topic: Topic) -> Int {
        let acc = profile.successRate(for: topic)
        let exposure = profile.exposure(for: topic)
        guard exposure > 0 else { return 0 }
        let trust = min(1.0, Double(exposure) / 10.0)     // full trust at ~10 questions
        let blended = acc * trust + 0.5 * (1 - trust)
        return Int((blended * 100).rounded())
    }

    /// Confidence per topic the child has actually met, highest first.
    var confidenceByTopic: [(topic: Topic, score: Int)] {
        Topic.allCases
            .filter { profile.exposure(for: $0) > 0 }
            .map { ($0, confidence(for: $0)) }
            .sorted { $0.score > $1.score }
    }

    var strengths: [Topic] { profile.strong }
    var challenges: [Topic] { profile.weak }
    var discovering: [Topic] { profile.discovering }

    /// Topics ranked by how much time the child spent on them this week.
    func topTopicsThisWeek(limit: Int = 3) -> [Topic] {
        var totals: [String: Int] = [:]
        for day in daysInLast(7) {
            for (raw, t) in day.perTopic { totals[raw, default: 0] += t.answered }
        }
        return totals.sorted { $0.value > $1.value }
            .compactMap { Topic(rawValue: $0.key) }
            .prefix(limit).map { $0 }
    }

    /// Per-day accuracy series for charts (date string → accuracy 0..1).
    func accuracySeries(days: Int) -> [(date: String, accuracy: Double)] {
        daysInLast(days).map { d in
            (d.date, d.questionsAnswered > 0 ? Double(d.correct) / Double(d.questionsAnswered) : 0)
        }
    }

    /// Per-day minutes-earned series for charts.
    func minutesSeries(days: Int) -> [(date: String, minutes: Int)] {
        daysInLast(days).map { ($0.date, $0.minutesEarned) }
    }

    // MARK: - Helpers

    private func summarize(_ stats: [DailyStat]) -> PeriodSummary {
        var s = PeriodSummary()
        for d in stats {
            s.questions += d.questionsAnswered
            s.correct += d.correct
            s.wrong += d.wrong
            s.minutesEarned += d.minutesEarned
            s.minutesUsed += d.minutesUsed
            s.longestStreak = max(s.longestStreak, d.longestStreak)
            s.learningMinutes += d.learningSeconds / 60
            s.sessions += d.sessions
            s.earnSessions += d.earnSessions
            s.freeSessions += d.freeSessions
            s.voluntaryAnswers += d.voluntaryAnswers
            if d.questionsAnswered > 0 { s.activeDays += 1 }
        }
        return s
    }

    /// The day stats falling within the last `n` days (inclusive of today).
    private func daysInLast(_ n: Int) -> [DailyStat] {
        daysInRange(from: n, to: 0)
    }

    /// Day stats whose date is within [today-from, today-to).
    private func daysInRange(from: Int, to: Int) -> [DailyStat] {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        guard let lower = cal.date(byAdding: .day, value: -from, to: today),
              let upper = cal.date(byAdding: .day, value: -to, to: today) else { return [] }
        return history.filter { stat in
            guard let d = Self.parse(stat.date) else { return false }
            return d >= lower && d < upper.addingTimeInterval(1)
        }
    }

    private static func parse(_ key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }
}
