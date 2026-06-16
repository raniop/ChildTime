import Foundation

/// Limited-time events that add recurring novelty + excitement, with ZERO new
/// state or sync: the active event is a pure function of the calendar date, so
/// every device agrees and there's nothing to persist.
///
/// - Weekend (Fri/Sat in Israel) → all 💎 earned are DOUBLED.
/// - Weekday → a rotating "topic of the day" whose questions earn double 💎,
///   nudging kids to try a topic they might skip.
enum GameEvent: Equatable {
    case doubleDiamonds
    case featuredTopic(Topic)

    /// The event in effect for `date` (default: now). Pure + deterministic.
    static func current(_ date: Date = Date(), calendar: Calendar = .current) -> GameEvent? {
        let weekday = calendar.component(.weekday, from: date) // 1=Sun … 7=Sat
        if weekday == 6 || weekday == 7 { return .doubleDiamonds }   // Fri / Sat
        // Deterministic topic-of-the-day from the day-of-year, over the
        // knowledge topics (math is always present, so spotlight the others).
        let pool: [Topic] = [.english, .hebrew, .logic, .science, .history, .geography, .money]
        let doy = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return .featuredTopic(pool[doy % pool.count])
    }

    /// 💎 multiplier for a correct answer in `topic` (1 = no event bonus).
    func diamondMultiplier(for topic: Topic) -> Int {
        switch self {
        case .doubleDiamonds:            return 2
        case .featuredTopic(let t):      return t == topic ? 2 : 1
        }
    }

    var emoji: String {
        switch self {
        case .doubleDiamonds:   return "💎"
        case .featuredTopic:    return "🌟"
        }
    }

    /// Short, kid-friendly banner line (Hebrew, vowelized).
    var bannerText: String {
        switch self {
        case .doubleDiamonds:
            return "סוֹף שָׁבוּעַ שֶׁל יַהֲלוֹמִים כְּפוּלִים! 💎×2"
        case .featuredTopic(let t):
            return "נוֹשֵׂא הַיּוֹם: \(t.displayName) — יַהֲלוֹמִים כְּפוּלִים! 💎×2"
        }
    }
}
