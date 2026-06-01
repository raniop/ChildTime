import Foundation

/// Turns analytics into plain-Hebrew guidance for the parent — the "personal
/// coach" voice. Two outputs: narrative insights ("נראה שיואב מתקשה ב…") and
/// concrete, low-effort actions ("תרגלו חיבור בארוחת הערב"). Pure + rule-based.
struct CoachingEngine {
    let childName: String
    let insights: InsightsEngine
    let profile: LearningProfile
    /// Hebrew inflects by gender — pick the right verb/adjective forms.
    var isGirl: Bool = false

    private func g(_ masculine: String, _ feminine: String) -> String {
        isGirl ? feminine : masculine
    }

    struct Insight: Identifiable {
        enum Kind { case positive, attention, discovery, neutral }
        let id = UUID()
        let kind: Kind
        let emoji: String
        let text: String
    }

    struct RecommendedAction: Identifiable {
        let id = UUID()
        let emoji: String
        let text: String
    }

    private var name: String { childName.isEmpty ? "הילד" : childName }

    // MARK: - Narrative insights

    func insightCards() -> [Insight] {
        var out: [Insight] = []

        // Week-over-week movement in accuracy.
        let delta = insights.weeklyAccuracyDelta
        if delta <= -10 {
            out.append(.init(kind: .attention, emoji: "📉",
                text: "השבוע נרשמה ירידה של \(Int(abs(delta)))% בביצועים הכלליים. שווה לתרגל יחד קצת."))
        } else if delta >= 10 {
            out.append(.init(kind: .positive, emoji: "📈",
                text: "\(name) \(g("שיפר","שיפרה")) את הביצועים ב-\(Int(delta))% השבוע. כל הכבוד!"))
        }

        // Challenges (weak topics).
        if let weak = insights.challenges.first {
            out.append(.init(kind: .attention, emoji: "💪",
                text: "נראה ש\(name) מתקשה ב\(weak.displayName). זה תחום מצוין להתמקד בו יחד."))
        }

        // Strengths.
        if !insights.strengths.isEmpty {
            let list = insights.strengths.prefix(3).map { $0.displayName }.joined(separator: "، ")
            out.append(.init(kind: .positive, emoji: "🌟",
                text: "\(name) \(g("מצטיין","מצטיינת")) ב\(list). תחומים שכיף לחגוג בהם."))
        }

        // Discovery.
        if let disc = insights.discovering.first {
            out.append(.init(kind: .discovery, emoji: "🔭",
                text: "\(name) מגלה עניין הולך וגובר ב\(disc.displayName)."))
        }

        // Streak / consistency.
        let week = insights.thisWeek
        if week.activeDays >= 5 {
            out.append(.init(kind: .positive, emoji: "🔥",
                text: "\(name) \(g("למד","למדה")) ב-\(week.activeDays) מתוך 7 הימים האחרונים — עקביות יפה!"))
        }

        if out.isEmpty {
            out.append(.init(kind: .neutral, emoji: "🌱",
                text: "עוד אוספים נתונים על \(name). אחרי עוד כמה משחקים נוכל להציג תובנות אישיות."))
        }
        return out
    }

    // MARK: - Recommended actions

    func recommendedActions() -> [RecommendedAction] {
        var out: [RecommendedAction] = []

        if let weak = insights.challenges.first {
            out.append(.init(emoji: "💡", text: actionForWeakTopic(weak)))
        }
        if let disc = insights.discovering.first {
            out.append(.init(emoji: "💡",
                text: "שאלו את \(name) מה \(g("הוא למד","היא למדה")) היום ב\(disc.displayName) — סקרנות מחזקת זיכרון."))
        }
        if insights.thisWeek.activeDays < 3 {
            out.append(.init(emoji: "💡",
                text: "נסו לקבוע 10 דקות משחק קבועות ביום — עקביות חשובה יותר מכמות."))
        }
        if out.count < 2, let strong = insights.strengths.first {
            out.append(.init(emoji: "💡",
                text: "\(name) \(g("חזק","חזקה")) ב\(strong.displayName) — אתגרו \(g("אותו","אותה")) בשאלה קשה יותר ותראו את הביטחון."))
        }
        if out.isEmpty {
            out.append(.init(emoji: "💡",
                text: "הקדישו 10 דקות למשחק משותף — זו דרך נהדרת לראות איך \(name) \(g("חושב","חושבת"))."))
        }
        return out
    }

    private func actionForWeakTopic(_ topic: Topic) -> String {
        switch topic {
        case .math:      return "נסו לתרגל חיבור וחיסור קצר בזמן ארוחת הערב."
        case .english:   return "הקדישו 10 דקות לקריאת מילים באנגלית יחד."
        case .hebrew:    return "כתבו יחד כמה מילים והתרגלו איות נכון."
        case .logic:     return "פתרו חידה או משחק חשיבה אחד ביחד היום."
        case .science:   return "שאלו את \(name) שאלת \"למה\" על משהו בטבע."
        case .history:   return "ספרו ל\(name) סיפור קצר על משהו שקרה פעם."
        case .geography: return "הסתכלו יחד על מפה ובחרו מדינה ללמוד עליה."
        case .money:     return "תנו ל\(name) לספור כסף קטן בחנות, או לדבר על חיסכון לצעצוע."
        }
    }
}
