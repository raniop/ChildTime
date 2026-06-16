import SwiftUI

/// Parent-only, on-device heuristic analyses layered on top of InsightsEngine.
/// No third-party calls and no runtime LLM — everything is derived locally from
/// the child's own per-topic stats, keeping the app Kids-Category compliant.
extension InsightsEngine {

    struct Labeled: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let detail: String
    }

    // MARK: - Snapshot extras

    /// Average answer time across topics the child has met, in whole seconds.
    var avgResponseSeconds: Int? {
        let met = Topic.allCases.filter { profile.exposure(for: $0) > 0 }
        let times = met.compactMap { profile.avgResponseMs(for: $0) }.filter { $0 > 0 }
        guard !times.isEmpty else { return nil }
        return Int((times.reduce(0, +) / Double(times.count) / 1000).rounded())
    }

    enum Trend { case up, flat, down
        var label: String { self == .up ? "⬆ מִשְׁתַּפֵּר" : self == .down ? "⬇ יְרִידָה קַלָּה" : "➡ יַצִּיב" }
        var color: Color { self == .up ? AppColor.successMint : self == .down ? AppColor.flameOrange : .secondary }
    }
    var learningTrend: Trend {
        let d = weeklyAccuracyDelta
        if d > 0.03 { return .up }
        if d < -0.03 { return .down }
        return .flat
    }

    // MARK: - Learning style (heuristic)

    /// A gentle, never-definitive guess at HOW the child learns best, from which
    /// kinds of topics they're strong/fast in. nil until there's enough signal.
    var learningStyle: Labeled? {
        let met = Topic.allCases.filter { profile.exposure(for: $0) >= 4 }
        guard met.count >= 2 else { return nil }

        let logicLike: Set<Topic> = [.logic, .math]
        let memoryLike: Set<Topic> = [.english, .hebrew, .history, .geography]
        let strong = Set(strengths)
        let fast = (avgResponseSeconds ?? 99) <= 6
        let accurate = profile.overallAccuracy >= 0.8

        if fast && accurate {
            return Labeled(emoji: "⚡️", title: "לוֹמֵד דֶּרֶךְ דְּפוּסִים",
                           detail: "קוֹלֵט מָהֵר וּמְזַהֶה דְּפוּסִים — עוֹנֶה נָכוֹן וּבִמְהִירוּת.")
        }
        if !strong.isDisjoint(with: logicLike) && strong.isDisjoint(with: memoryLike) {
            return Labeled(emoji: "🧠", title: "לוֹמֵד דֶּרֶךְ הִיגָּיוֹן",
                           detail: "מְצֻיָּן בִּמְשִׂימוֹת חֲשִׁיבָה וּפִתְרוֹן בְּעָיוֹת.")
        }
        if !strong.isDisjoint(with: memoryLike) && strong.isDisjoint(with: logicLike) {
            return Labeled(emoji: "📚", title: "לוֹמֵד דֶּרֶךְ זִכָּרוֹן",
                           detail: "חָזָק בִּשְׁמִירַת מֵידָע — אוֹצַר מִלִּים, עֻבְדּוֹת וּמְקוֹמוֹת.")
        }
        let abandons = Topic.allCases.reduce(0) { $0 + profile.abandonCount(for: $1) }
        if abandons >= 4 {
            return Labeled(emoji: "🔬", title: "לוֹמֵד דֶּרֶךְ נִסּוּי וְטָעִיָּה",
                           detail: "מְנַסֶּה, טוֹעֶה וּמְתַקֵּן — כְּדַאי לְעוֹדֵד לְהַמְשִׁיךְ גַּם כְּשֶׁקָּשֶׁה.")
        }
        return Labeled(emoji: "🌱", title: "סִגְנוֹן מְעֹרָב",
                       detail: "לוֹמֵד מִכַּמָּה כִּוּוּנִים — נַמְשִׁיךְ לְלַמֵּד אֵיךְ הוּא לוֹמֵד הֲכִי טוֹב.")
    }

    // MARK: - Persistence

    /// How the child handles difficulty: do they push through mistakes, or bail
    /// on hard topics? Built from per-topic abandonment vs exposure.
    var persistence: Labeled? {
        let exposureTotal = Topic.allCases.reduce(0) { $0 + profile.exposure(for: $1) }
        guard exposureTotal >= 15 else { return nil }
        let abandons = Topic.allCases.reduce(0) { $0 + profile.abandonCount(for: $1) }
        let rate = Double(abandons) / Double(exposureTotal + abandons)
        if rate < 0.06 {
            return Labeled(emoji: "💪", title: "הַתְמָדָה גְּבוֹהָה",
                           detail: "מַמְשִׁיךְ לַעֲנוֹת גַּם אַחֲרֵי טָעֻיּוֹת וְכִמְעַט לֹא נוֹטֵשׁ.")
        }
        if rate < 0.18 {
            return Labeled(emoji: "🙂", title: "הַתְמָדָה טוֹבָה",
                           detail: "בְּדֶרֶךְ כְּלָל מַתְמִיד; לִפְעָמִים מְדַלֵּג עַל שְׁאֵלָה קָשָׁה.")
        }
        let bail = profile.abandoned.first.map { " (בְּעִקָּר \($0.displayName))" } ?? ""
        return Labeled(emoji: "🤝", title: "נוֹטֶה לְוַתֵּר עַל קָשֶׁה",
                       detail: "מְדַלֵּג עַל שְׁאֵלוֹת קָשׁוֹת\(bail) — שָׁוֶה לְעוֹדֵד וּלְהָקֵל אֶת הָרָמָה.")
    }

    // MARK: - Interests

    /// Topics gaining interest (freshly discovered) and ones losing it (high
    /// abandonment relative to interest).
    var gainedInterest: [Topic] { discovering }
    var lostInterest: [Topic] {
        profile.abandoned.filter { profile.abandonCount(for: $0) >= 2 }
    }
}
