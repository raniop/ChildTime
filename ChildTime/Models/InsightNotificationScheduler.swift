import Foundation
import UserNotifications

/// Schedules on-device "parent insight" notifications — short, personal,
/// positive, data-based nudges about each child (what improved, where they
/// struggled, what interests them, what to practice). Frequency is chosen by
/// the parent in Family Overview (off / 1× / 2× / 3× per day).
///
/// Everything is local (UNCalendarNotificationTrigger) — no server needed. We
/// schedule the next 7 days up front with rotating, varied content, and
/// re-schedule whenever the parent opens Family Overview or changes the setting.
enum InsightNotificationScheduler {
    private static let idPrefix = "insight."

    /// One scheduled insight. When `levelUpTopic` is set, the notification gets
    /// interactive "raise the level?" Yes/No buttons for that topic.
    struct InsightItem {
        let name: String
        let text: String
        var levelUpTopic: Topic? = nil
        var childID: UUID? = nil
    }

    /// Cancel any previously-scheduled insight notifications and, unless the
    /// frequency is off, schedule a fresh week of rotating per-child insights.
    static func reschedule(
        rows: [(profile: Profile, snapshot: ProgressSnapshot)],
        enabledTopics: Set<Topic>,
        frequency: ParentSettings.InsightFrequency
    ) {
        let center = UNUserNotificationCenter.current()

        // Clear previously-scheduled insight notifications by their KNOWN ids,
        // synchronously. (Using the async getPendingNotificationRequests + remove
        // raced with the re-add below: our ids are deterministic — "insight.day.hour"
        // — so the delayed removal would wipe the notifications we just scheduled,
        // and the parent would get none.)
        let allHours = [9, 14, 17, 18, 19]   // union of every frequency's slots
        var oldIDs: [String] = []
        for day in 0..<7 {
            for h in allHours { oldIDs.append("\(idPrefix)\(day).\(h)") }
        }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        guard frequency != .off, !rows.isEmpty else { return }

        // Build a pool of insight strings across all children, then shuffle so
        // consecutive notifications feel varied.
        var pool: [InsightItem] = []
        for row in rows {
            // Only include kids with enough signal to say something real.
            guard row.snapshot.totalAnswered >= 4 else { continue }
            pool += insights(for: row.profile, snapshot: row.snapshot, enabledTopics: enabledTopics)
        }
        guard !pool.isEmpty else { return }
        pool.shuffle()

        let cal = Calendar.current
        let now = Date()
        var idx = 0

        for day in 0..<7 {
            guard let base = cal.date(byAdding: .day, value: day, to: now) else { continue }
            for hour in frequency.hours {
                var comps = cal.dateComponents([.year, .month, .day], from: base)
                comps.hour = hour
                comps.minute = 0
                // Skip slots already in the past (e.g. today's morning slot).
                guard let fire = cal.date(from: comps), fire > now else { continue }

                let item = pool[idx % pool.count]
                idx += 1

                let content = UNMutableNotificationContent()
                content.title = "טופי — \(item.name)"
                content.body = item.text
                content.sound = .default
                // Strength insight → offer to raise the level right from the push.
                if let topic = item.levelUpTopic {
                    content.categoryIdentifier = PushManager.Category.insightLevelUp
                    content.userInfo = [
                        "action": "levelup",
                        "topic": topic.rawValue,
                        "childName": item.name,
                        "childID": item.childID?.uuidString ?? ""
                    ]
                }

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let req = UNNotificationRequest(
                    identifier: "\(idPrefix)\(day).\(hour)",
                    content: content,
                    trigger: trigger
                )
                center.add(req) { error in
                    if let error { print("[Insight] schedule failed: \(error.localizedDescription)") }
                }
            }
        }
    }

    // MARK: - Insight strings

    /// Short, positive, data-based one-liners (each ends with a practical hook).
    private static func insights(
        for profile: Profile,
        snapshot s: ProgressSnapshot,
        enabledTopics: Set<Topic>
    ) -> [InsightItem] {
        let name = profile.name.isEmpty ? "הילד" : profile.name
        let lp = LearningProfile(snapshot: s, enabledTopics: enabledTopics, age: profile.age)
        let history = LearningHistoryStore.shared.history(for: profile.id)
        let engine = InsightsEngine(history: history, profile: lp)
        let coach = CoachingEngine(childName: name, insights: engine, profile: lp)

        var out: [InsightItem] = []

        // Improvement / week-over-week.
        let delta = engine.weeklyAccuracyDelta
        if delta >= 8 {
            out.append(InsightItem(name: name, text: "📈 \(name) השתפר ב-\(Int(delta))% השבוע — שווה לציין לו כמה התקדם!"))
        }

        // Strength → actionable: offer to raise the level for this topic.
        if let strong = engine.strengths.first {
            out.append(InsightItem(
                name: name,
                text: "🌟 \(name) זוהר ב\(strong.displayName). רוצים שאתגר אותו בשאלות קצת יותר קשות?",
                levelUpTopic: strong,
                childID: profile.id))
        }

        // Interest / discovery.
        if let disc = engine.discovering.first {
            out.append(InsightItem(name: name, text: "🔭 \(name) מגלה עניין ב\(disc.displayName). עודדו אותו לבחור עוד שאלות בנושא."))
        } else if let fav = lp.favorites.first {
            out.append(InsightItem(name: name, text: "💙 \(name) הכי אוהב \(fav.displayName). אפשר להתחיל מזה כדי לבנות ביטחון."))
        }

        // Challenge + concrete tip.
        if let weak = engine.challenges.first, let tip = coach.recommendedActions().first {
            out.append(InsightItem(name: name, text: "💪 כדאי לחזק את \(name) ב\(weak.displayName). \(tip.text)"))
        }

        // Self-initiated learning.
        if engine.thisWeek.voluntaryLearningRate >= 0.4 {
            out.append(InsightItem(name: name, text: "🙋 \(name) בחר ללמוד מיוזמתו השבוע — סקרנות זה הדלק הכי טוב ללמידה!"))
        }

        // Fallback so there's always something kind to say.
        if out.isEmpty {
            out.append(InsightItem(name: name, text: "🌱 \(name) ממשיך לתרגל. 10 דקות משחק משותף היום יחזקו את ההרגל."))
        }
        return out
    }
}
