import Foundation

/// Human names for the fine-grained skills a question can be tagged with
/// (`Question.skill`). Keys are stable identifiers written into `dailyStats`, so
/// renaming here never breaks history. Unknown keys fall back to the key itself.
enum SkillCatalog {
    /// Computed so the names follow the app language (a stored static would freeze the first one).
    static var names: [String: String] { [
        "addSub":       tr("חיבור וחסור"),
        "completeTen":  tr("הושלמה לעשר"),
        "compare":      tr("השואת מספרים"),
        "evenOdd":      tr("זוגי ואיזוגי"),
        "mul":          tr("כפל"),
        "div":          tr("חלוק"),
        "mixedOps":     tr("פעולות משלבות"),
        "wordProblem":  tr("בעיות מלוליות"),
        "fractions":    tr("שברים פשוטים"),
        "divRemainder": tr("חלוק עם שארית"),
        "geometry":     tr("הקף ושטח"),
        "decimals":     tr("מספרים עשרוניים"),
        "average":      tr("ממצע"),
        "percent":      tr("אחוזים"),
        // ז׳–ח׳
        "negatives":      tr("מספרים מכונים"),
        "expressions":    tr("בטויים אלגבריים"),
        "equations":      tr("משואות"),
        "powers":         tr("חזקות"),
        "roots":          tr("שורשים"),
        "angles":         tr("זויות"),
        "proportion":     tr("יחס ופרופורציה"),
        "pythagoras":     tr("משפט פיתגורס"),
        "linearFunction": tr("פונקציה קוית"),
        "volume":         tr("נפח"),
        "probability":    tr("הסתברות"),
        "circle":         tr("מעגל"),
    ] }
    /// Built once per language: rebuilding ~25 translated names on EVERY call
    /// cost ~30ms each time the question card redrew (Rani: the stutter after
    /// an answer).
    nonisolated(unsafe) private static var cache: (lang: String, names: [String: String])?
    private static let cacheLock = NSLock()
    static func name(_ key: String) -> String {
        let lang = LanguageStore.shared.current.rawValue
        cacheLock.lock(); defer { cacheLock.unlock() }
        if cache?.lang != lang { cache = (lang, names) }
        return cache?.names[key] ?? key
    }
}

/// The three windows the parent report can be filtered to.
enum ReportPeriod: String, CaseIterable, Identifiable {
    case today, week, month
    var id: String { rawValue }
    var title: String {
        switch self { case .today: return tr("היום"); case .week: return tr("השבוע"); case .month: return tr("החודש") }
    }
    /// Calendar days covered (today inclusive).
    var days: Int { switch self { case .today: return 1; case .week: return 7; case .month: return 30 } }
}

/// One topic's numbers over a period, plus the verdict the parent sees.
struct TopicReport: Identifiable {
    let topic: Topic
    let answered: Int
    let correct: Int
    var wrong: Int { answered - correct }
    var accuracy: Double { answered > 0 ? Double(correct) / Double(answered) : 0 }
    var id: String { topic.rawValue }

    enum Verdict { case strong, ok, weak, tooFew }
    /// Thresholds are deliberately generous toward the child: below ~6 answers
    /// we say nothing rather than label a kid "weak" off two misses.
    var verdict: Verdict {
        guard answered >= 6 else { return .tooFew }
        // Matches the approved report: 85 % reads "חזק", 60–73 % "בסדר", 39 % "דורש חיזוק".
        if accuracy >= 0.80 { return .strong }
        if accuracy >= 0.60 { return .ok }
        return .weak
    }
}

struct SkillReport: Identifiable {
    let key: String
    let answered: Int
    let correct: Int
    var name: String { SkillCatalog.name(key) }
    var accuracy: Double { answered > 0 ? Double(correct) / Double(answered) : 0 }
    var id: String { key }
}

/// A topic's change between this period and the one before it, in percentage
/// points of accuracy. Only computed when both periods have enough answers.
struct TopicDelta: Identifiable {
    let topic: Topic
    let deltaPoints: Double
    var id: String { topic.rawValue }
}

/// The single most useful thing to tell a parent right now — always ending, when
/// it can, in something they can actually do.
struct DailyInsight {
    let emoji: String
    let title: String
    let body: String
    let recommendation: String?
}

/// Everything the parent's child report needs, derived from `DailyStat` history.
/// Pure functions on the engine — no network, no LLM, no third parties: the
/// Kids-Category promise is that a child's data never leaves to be analysed.
extension InsightsEngine {

    // MARK: - Windows

    private func stats(period: ReportPeriod, offsetPeriods: Int = 0) -> [DailyStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: -(period.days * offsetPeriods), to: today)!
        let start = cal.date(byAdding: .day, value: -(period.days - 1), to: end)!
        let keys = Set((0..<period.days).compactMap { i in
            cal.date(byAdding: .day, value: i, to: start).map(LearningHistoryStore.dayKey)
        })
        return history.filter { keys.contains($0.date) }
    }

    func summary(_ period: ReportPeriod) -> PeriodSummary {
        switch period {
        case .today: return today
        case .week: return thisWeek
        case .month: return thisMonth
        }
    }

    // MARK: - Topics

    /// Every topic the child touched in the period, best first — so the report
    /// opens on strengths and ends on what needs work.
    func topicReports(_ period: ReportPeriod, offsetPeriods: Int = 0) -> [TopicReport] {
        var answered: [Topic: Int] = [:], correct: [Topic: Int] = [:]
        for day in stats(period: period, offsetPeriods: offsetPeriods) {
            for (raw, t) in day.perTopic {
                guard let topic = Topic(rawValue: raw) else { continue }
                answered[topic, default: 0] += t.answered
                correct[topic, default: 0] += t.correct
            }
        }
        return answered.keys
            .map { TopicReport(topic: $0, answered: answered[$0]!, correct: correct[$0] ?? 0) }
            .sorted { a, b in
                if a.accuracy != b.accuracy { return a.accuracy > b.accuracy }
                return a.answered > b.answered
            }
    }

    /// The skills inside one topic, weakest first — the parent's "what exactly
    /// to practise" list. Empty for topics whose questions carry no skill tag.
    func skillReports(_ topic: Topic, _ period: ReportPeriod) -> [SkillReport] {
        var answered: [String: Int] = [:], correct: [String: Int] = [:]
        for day in stats(period: period) {
            guard let t = day.perTopic[topic.rawValue], let skills = t.perSkill else { continue }
            for (key, s) in skills {
                answered[key, default: 0] += s.answered
                correct[key, default: 0] += s.correct
            }
        }
        return answered.keys
            .map { SkillReport(key: $0, answered: answered[$0]!, correct: correct[$0] ?? 0) }
            .filter { $0.answered >= 3 }
            .sorted { $0.accuracy < $1.accuracy }
    }

    // MARK: - Change over time

    /// Per-topic accuracy change vs the previous period, most improved first.
    /// Needs at least 6 answers in EACH period so noise never reads as a trend.
    func topicDeltas(_ period: ReportPeriod) -> [TopicDelta] {
        let now = Dictionary(uniqueKeysWithValues: topicReports(period).map { ($0.topic, $0) })
        let before = Dictionary(uniqueKeysWithValues: topicReports(period, offsetPeriods: 1).map { ($0.topic, $0) })
        return now.compactMap { topic, cur in
            guard let prev = before[topic], cur.answered >= 6, prev.answered >= 6 else { return nil }
            return TopicDelta(topic: topic, deltaPoints: (cur.accuracy - prev.accuracy) * 100)
        }
        .sorted { $0.deltaPoints > $1.deltaPoints }
    }

    /// Overall accuracy change vs the previous period, in percentage points;
    /// nil when either period is too thin to compare.
    func overallDelta(_ period: ReportPeriod) -> Double? {
        let cur = summarizeDays(stats(period: period))
        let prev = summarizeDays(stats(period: period, offsetPeriods: 1))
        guard cur.questions >= 10, prev.questions >= 10 else { return nil }
        return (cur.accuracy - prev.accuracy) * 100
    }

    private func summarizeDays(_ days: [DailyStat]) -> (questions: Int, correct: Int, accuracy: Double) {
        let q = days.reduce(0) { $0 + $1.questionsAnswered }
        let c = days.reduce(0) { $0 + $1.correct }
        return (q, c, q > 0 ? Double(c) / Double(q) : 0)
    }

    // MARK: - Mastered / to practise

    /// Skills (or, untagged, whole topics) the child has clearly got — high
    /// accuracy on a real sample. Shown so a parent knows what NOT to drill.
    func mastered(_ period: ReportPeriod) -> [(name: String, detail: String)] {
        var out: [(String, String, Double)] = []
        for t in topicReports(period) where t.answered >= 8 {
            let skills = skillReports(t.topic, period)
            // A strong SKILL counts even inside a weak topic — "strong in
            // multiplication, struggling with fractions" is exactly the picture
            // a parent needs, and folding it into "math 45%" would hide it.
            for s in skills where s.answered >= 5 && s.accuracy >= 0.85 {
                out.append((Question.stripNiqqud(s.name), pct(s.accuracy), s.accuracy))
            }
            // The topic as a whole only when there is nothing finer to say.
            if skills.isEmpty, t.accuracy >= 0.85 {
                out.append((t.topic.parentName, tr("\(pct(t.accuracy)) · \(t.answered) שאלות"), t.accuracy))
            }
        }
        return out.sorted { $0.2 > $1.2 }.prefix(4).map { ($0.0, $0.1) }
    }

    /// Specific things worth practising — a skill where one exists, else the
    /// topic. Weakest first, capped so the list is a nudge and not a verdict.
    func toPractice(_ period: ReportPeriod) -> [(name: String, detail: String)] {
        var out: [(String, String, Double)] = []
        for t in topicReports(period) where t.answered >= 6 {
            let skills = skillReports(t.topic, period)
            for s in skills.prefix(3) where s.answered >= 4 && s.accuracy < 0.7 {
                out.append((Question.stripNiqqud(s.name), tr("\(pct(s.accuracy)) ב\(t.topic.parentName)"), s.accuracy))
            }
            if skills.isEmpty, t.accuracy < 0.7 {
                out.append((t.topic.parentName, tr("\(pct(t.accuracy)) · \(t.wrong) טעויות"), t.accuracy))
            }
        }
        return out.sorted { $0.2 < $1.2 }.prefix(4).map { ($0.0, $0.1) }
    }

    // MARK: - Series for the charts

    struct DayPoint: Identifiable {
        let date: String
        let questions: Int
        let accuracy: Double     // 0…1, 0 when no answers
        let earned: Int
        let used: Int
        var id: String { date }
        /// Short Hebrew weekday, Saturday spelt out as the app does elsewhere.
        var weekday: String {
            guard let d = LearningHistoryStore.date(fromKey: date) else { return "" }
            let i = Calendar.current.component(.weekday, from: d)   // 1 = Sunday
            guard LanguageStore.shared.current == .he else {
                // "א׳" also means "grade 1" in the catalog — weekdays come from the calendar instead.
                var cal = Calendar(identifier: .gregorian)
                cal.locale = LanguageStore.shared.current.locale
                return cal.shortWeekdaySymbols[i - 1]
            }
            return ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "שַׁבָּת"][i - 1]
        }
    }

    /// One point per calendar day over the last `days`, oldest first, with empty
    /// days present as zeros so the chart's x-axis is a real calendar.
    func dayPoints(days: Int) -> [DayPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let byKey = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
        return (0..<days).reversed().map { back in
            let key = LearningHistoryStore.dayKey(cal.date(byAdding: .day, value: -back, to: today)!)
            let d = byKey[key]
            let q = d?.questionsAnswered ?? 0
            return DayPoint(date: key, questions: q,
                            accuracy: q > 0 ? Double(d!.correct) / Double(q) : 0,
                            earned: d?.minutesEarned ?? 0, used: d?.minutesUsed ?? 0)
        }
    }

    // MARK: - The daily insight

    /// Rules, in priority order. Each fires only on enough data, and each says
    /// something a parent can act on. Never a judgement of the child.
    /// `minutesToday`: for `.today`, the same live count the "דקות" tile above shows.
    /// History records only answer minutes, so without it the insight said 12 under a 23.
    func dailyInsight(name: String, isGirl: Bool, period: ReportPeriod, minutesToday: Int? = nil) -> DailyInsight? {
        let g = { (m: String, f: String) in isGirl ? f : m }
        let topics = topicReports(period).filter { $0.answered >= 8 }
        let deltas = topicDeltas(period)

        // 1. A wide gap between the strongest and weakest subject.
        if let best = topics.first, let worst = topics.last, best.topic != worst.topic,
           best.accuracy - worst.accuracy >= 0.30, worst.accuracy < 0.6 {
            let weakSkill = skillReports(worst.topic, period).first
            let focus = weakSkill.map { tr(" הפער נפתח בעיקר ב\($0.name).") } ?? ""
            return DailyInsight(
                emoji: "💡",
                title: tr("פער גדול בין נושאים"),
                body: tr("\(name) \(g(tr("עונה"), tr("עונה"))) על \(worst.topic.parentName) ב-\(pct(worst.accuracy)) לעומת \(pct(best.accuracy)) ב\(best.topic.parentName) — הפער הגדול ביותר בין הנושאים \(g(tr("שלו"), tr("שלה"))).\(focus)"),
                recommendation: tr("10 דקות של \(weakSkill.map { Question.stripNiqqud($0.name) } ?? worst.topic.parentName) ביחד, פעם־פעמיים בשבוע. \(g(tr("הוא"), tr("היא"))) כבר \(g(tr("חזק"), tr("חזקה"))) ב\(best.topic.parentName) — יש על מה לבנות."))
        }
        // 2. A subject that jumped.
        if let up = deltas.first, up.deltaPoints >= 10 {
            return DailyInsight(
                emoji: "🌟",
                title: tr("\(up.topic.parentName) הופכת לחוזקה"),
                body: tr("\(name) \(g(tr("השתפר"), tr("השתפרה"))) ב\(up.topic.parentName) ב-\(Int(up.deltaPoints.rounded())) נקודות לעומת התקופה הקודמת."),
                recommendation: tr("שוה לצין את זה בקול — ילדים ממשיכים להשתפר במה שמשבחים אותם עליו."))
        }
        // 3. A subject that slipped.
        if let down = deltas.last, down.deltaPoints <= -8 {
            return DailyInsight(
                emoji: "🔎",
                title: tr("ירידה קלה ב\(down.topic.parentName)"),
                body: tr("הדיוק של \(name) ב\(down.topic.parentName) ירד ב-\(Int(abs(down.deltaPoints).rounded())) נקודות לעומת התקופה הקודמת. לפעמים זה פשוט חומר חדש שנכנס."),
                recommendation: tr("\(g(tr("שאלו אותו"), tr("שאלו אותה"))) מה היה קשה השבוע — לרוב זו שאלה אחת שפותחת הכול."))
        }
        // 4. A real streak.
        let s = summary(period)
        if s.activeDays >= 5 && period != .today {
            return DailyInsight(
                emoji: "🔥",
                title: tr("\(s.activeDays) ימים של למידה"),
                body: tr("\(name) \(g(tr("למד"), tr("למדה"))) ב-\(s.activeDays) ימים \(period == .week ? tr("השבוע") : tr("החודש")), \(s.questions) שאלות בסך הכול ב-\(pct(s.accuracy)) הצלחה."),
                recommendation: tr("הרציפות שוה יותר מהכמות — גם 10 דקות ביום שומרות עליה."))
        }
        // 5. Learning for its own sake.
        if s.voluntaryLearningRate >= 0.3, s.questions >= 20 {
            return DailyInsight(
                emoji: "💛",
                title: tr("\(g(tr("לומד"), tr("לומדת"))) גם בלי פרס"),
                body: tr("\(Int((s.voluntaryLearningRate * 100).rounded()))% מהתשובות של \(name) ניתנו אחרי שהדקות של היום כבר נגמרו — כלומר סתם כי \(g(tr("רצה"), tr("רצתה")))."),
                recommendation: nil)
        }
        // 6. Plain summary when there is data but no story yet.
        guard s.questions > 0 else { return nil }
        let mins = (period == .today ? minutesToday : nil) ?? s.minutesEarned
        return DailyInsight(
            emoji: "📚",
            title: tr("\(s.questions) שאלות \(period.title.lowercased())"),
            body: tr("\(pct(s.accuracy)) הצלחה") + (mins > 0 ? tr(" · \(mins) דקות ש\(g(tr("הרוויח"), tr("הרוויחה")))") : ""),
            recommendation: nil)
    }

    private func pct(_ x: Double) -> String { "\(Int((x * 100).rounded()))%" }
}

extension LearningHistoryStore {
    /// Inverse of `dayKey`.
    static func date(fromKey key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }
}
