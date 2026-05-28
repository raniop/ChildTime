import Foundation

/// A single hand-curated multiple-choice question used by topics where we
/// don't generate questions algorithmically (English, Logic, Science,
/// History, Geography).
struct BankQuestion {
    let prompt: String
    let correctAnswer: String
    let distractors: [String]
}

enum QuestionBanks {

    // MARK: - אנגלית

    static let english: [BankQuestion] = [
        BankQuestion(prompt: "🐈\nאיך אומרים את זה באנגלית?", correctAnswer: "cat", distractors: ["dog", "fish", "bird"]),
        BankQuestion(prompt: "🐕\nאיך אומרים את זה באנגלית?", correctAnswer: "dog", distractors: ["cat", "horse", "cow"]),
        BankQuestion(prompt: "🌞\nאיך אומרים את זה באנגלית?", correctAnswer: "sun", distractors: ["moon", "star", "sky"]),
        BankQuestion(prompt: "🍎\nאיך אומרים את זה באנגלית?", correctAnswer: "apple", distractors: ["banana", "orange", "pear"]),
        BankQuestion(prompt: "🏠\nאיך אומרים את זה באנגלית?", correctAnswer: "house", distractors: ["car", "tree", "school"]),
        BankQuestion(prompt: "📚\nאיך אומרים את זה באנגלית?", correctAnswer: "book", distractors: ["pen", "table", "chair"]),
        BankQuestion(prompt: "🚗\nאיך אומרים את זה באנגלית?", correctAnswer: "car", distractors: ["bus", "bike", "boat"]),
        BankQuestion(prompt: "🌳\nאיך אומרים את זה באנגלית?", correctAnswer: "tree", distractors: ["flower", "grass", "leaf"]),
        BankQuestion(prompt: "💧\nאיך אומרים את זה באנגלית?", correctAnswer: "water", distractors: ["fire", "ice", "milk"]),
        BankQuestion(prompt: "⭐\nאיך אומרים את זה באנגלית?", correctAnswer: "star", distractors: ["sun", "moon", "cloud"]),
        BankQuestion(prompt: "🌙\nאיך אומרים את זה באנגלית?", correctAnswer: "moon", distractors: ["star", "sun", "night"]),
        BankQuestion(prompt: "🥛\nאיך אומרים את זה באנגלית?", correctAnswer: "milk", distractors: ["water", "juice", "tea"]),
        BankQuestion(prompt: "🍞\nאיך אומרים את זה באנגלית?", correctAnswer: "bread", distractors: ["cake", "rice", "egg"]),
        BankQuestion(prompt: "🐟\nאיך אומרים את זה באנגלית?", correctAnswer: "fish", distractors: ["cat", "dog", "bird"]),
        BankQuestion(prompt: "🐦\nאיך אומרים את זה באנגלית?", correctAnswer: "bird", distractors: ["fish", "frog", "duck"]),
        BankQuestion(prompt: "🌸\nאיך אומרים את זה באנגלית?", correctAnswer: "flower", distractors: ["tree", "leaf", "grass"]),
        BankQuestion(prompt: "🐘\nאיך אומרים את זה באנגלית?", correctAnswer: "elephant", distractors: ["lion", "bear", "tiger"]),
        BankQuestion(prompt: "🦁\nאיך אומרים את זה באנגלית?", correctAnswer: "lion", distractors: ["tiger", "bear", "elephant"]),
        BankQuestion(prompt: "🚲\nאיך אומרים את זה באנגלית?", correctAnswer: "bike", distractors: ["car", "bus", "train"]),
        BankQuestion(prompt: "🎂\nאיך אומרים את זה באנגלית?", correctAnswer: "cake", distractors: ["bread", "milk", "fruit"]),
        BankQuestion(prompt: "✋\nאיך אומרים 'יד' באנגלית?", correctAnswer: "hand", distractors: ["foot", "head", "eye"]),
        BankQuestion(prompt: "👁️\nאיך אומרים 'עין' באנגלית?", correctAnswer: "eye", distractors: ["ear", "nose", "mouth"]),
        BankQuestion(prompt: "What does 'apple' mean?", correctAnswer: "תפוח", distractors: ["בננה", "תפוז", "אגס"]),
        BankQuestion(prompt: "What does 'book' mean?", correctAnswer: "ספר", distractors: ["מחברת", "עט", "מכתב"]),
        BankQuestion(prompt: "What does 'tree' mean?", correctAnswer: "עץ", distractors: ["פרח", "עלה", "ענף"])
    ]

    // MARK: - לוגיקה

    static let logic: [BankQuestion] = [
        BankQuestion(prompt: "מה בא אחרי?\n1, 2, 3, ?", correctAnswer: "4", distractors: ["5", "6", "2"]),
        BankQuestion(prompt: "מה בא אחרי?\n2, 4, 6, ?", correctAnswer: "8", distractors: ["7", "10", "9"]),
        BankQuestion(prompt: "מה בא אחרי?\n5, 10, 15, ?", correctAnswer: "20", distractors: ["25", "16", "18"]),
        BankQuestion(prompt: "מה בא אחרי?\n10, 9, 8, ?", correctAnswer: "7", distractors: ["6", "11", "5"]),
        BankQuestion(prompt: "מה בא אחרי?\n🔴🟢🔴🟢🔴?", correctAnswer: "🟢", distractors: ["🔴", "🔵", "🟡"]),
        BankQuestion(prompt: "מה בא אחרי?\n🐶🐱🐶🐱🐶?", correctAnswer: "🐱", distractors: ["🐶", "🐭", "🐰"]),
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "🚗", distractors: ["🐶", "🐱", "🐰"]),
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "🍎", distractors: ["🚗", "🚌", "🚲"]),
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "📖", distractors: ["⚽", "🏀", "🎾"]),
        BankQuestion(prompt: "מי לא שייך?", correctAnswer: "🌳", distractors: ["☀️", "🌙", "⭐"]),
        BankQuestion(prompt: "אם 🍎=2, אז 🍎+🍎=?", correctAnswer: "4", distractors: ["3", "5", "2"]),
        BankQuestion(prompt: "אם 🐱>🐭, אז מי גדול יותר?", correctAnswer: "🐱", distractors: ["🐭", "אותו דבר", "לא יודע"]),
        BankQuestion(prompt: "מה הצורה הבאה?\n🔺🔻🔺🔻🔺?", correctAnswer: "🔻", distractors: ["🔺", "⬛", "⚫"]),
        BankQuestion(prompt: "כמה רגליים יש ל-3 כלבים?", correctAnswer: "12", distractors: ["6", "8", "10"]),
        BankQuestion(prompt: "אם דנה גדולה ממיכל ומיכל גדולה מתום, מי הכי גדול?", correctAnswer: "דנה", distractors: ["מיכל", "תום", "אותו דבר"]),
        BankQuestion(prompt: "מה דומה?\n🍎 🍌 🍇 🐶", correctAnswer: "🐶 לא דומה", distractors: ["🍎 לא דומה", "🍌 לא דומה", "🍇 לא דומה"]),
        BankQuestion(prompt: "אם היום שלישי, מה היה אתמול?", correctAnswer: "שני", distractors: ["רביעי", "ראשון", "חמישי"]),
        BankQuestion(prompt: "אם 5 ציפורים על עץ ו-2 עפו, כמה נשארו?", correctAnswer: "3", distractors: ["7", "2", "4"]),
        BankQuestion(prompt: "מה בא אחרי?\nA, B, C, ?", correctAnswer: "D", distractors: ["E", "A", "C"]),
        BankQuestion(prompt: "באיזה צורה אין פינות?", correctAnswer: "⚪", distractors: ["🔺", "⬛", "⬢"])
    ]

    // MARK: - מדע

    static let science: [BankQuestion] = [
        BankQuestion(prompt: "🕷️\nכמה רגליים יש לעכביש?", correctAnswer: "8", distractors: ["6", "10", "4"]),
        BankQuestion(prompt: "🌱\nמאיפה צמחים מקבלים אנרגיה?", correctAnswer: "מהשמש", distractors: ["מהאדמה", "מהאוויר", "מהירח"]),
        BankQuestion(prompt: "🌍\nכמה ימים יש בשבוע?", correctAnswer: "7", distractors: ["5", "6", "8"]),
        BankQuestion(prompt: "🌈\nכמה צבעים יש בקשת?", correctAnswer: "7", distractors: ["5", "6", "10"]),
        BankQuestion(prompt: "👂\nבאיזה איבר אנחנו שומעים?", correctAnswer: "אוזניים", distractors: ["עיניים", "אף", "פה"]),
        BankQuestion(prompt: "🐝\nאיזו חיה עושה דבש?", correctAnswer: "דבורה", distractors: ["נמלה", "זבוב", "פרפר"]),
        BankQuestion(prompt: "❄️\nמה קורה למים בקור?", correctAnswer: "קופאים", distractors: ["מתאדים", "נעלמים", "מתחממים"]),
        BankQuestion(prompt: "🌡️\nאיך מודדים חום?", correctAnswer: "במדחום", distractors: ["במשקל", "בסרגל", "בשעון"]),
        BankQuestion(prompt: "🦷\nכמה שיניים יש לאדם מבוגר?", correctAnswer: "32", distractors: ["20", "28", "40"]),
        BankQuestion(prompt: "🦴\nכמה ימים יש בשנה?", correctAnswer: "365", distractors: ["360", "350", "400"]),
        BankQuestion(prompt: "🌙\nכמה זמן לוקח לירח להקיף את כדור הארץ?", correctAnswer: "כחודש", distractors: ["יום", "שנה", "שבוע"]),
        BankQuestion(prompt: "☀️\nמה הכוכב הקרוב ביותר לכדור הארץ?", correctAnswer: "השמש", distractors: ["הירח", "מאדים", "צדק"]),
        BankQuestion(prompt: "🐠\nאיפה דגים נושמים?", correctAnswer: "במים", distractors: ["באוויר", "באדמה", "בעץ"]),
        BankQuestion(prompt: "🦋\nממה הופך זחל?", correctAnswer: "לפרפר", distractors: ["לדבורה", "לציפור", "לעכביש"]),
        BankQuestion(prompt: "🌋\nמה יוצא מהר געש?", correctAnswer: "לבה", distractors: ["מים", "שלג", "חול"]),
        BankQuestion(prompt: "💨\nממה עשוי אוויר?", correctAnswer: "גזים", distractors: ["מים", "אבק", "כלום"]),
        BankQuestion(prompt: "🌊\nמה גורם לגלים בים?", correctAnswer: "רוח", distractors: ["דגים", "השמש", "אבנים"]),
        BankQuestion(prompt: "🦷\nאיך נקרא הצמח שיש בשיניים?", correctAnswer: "אמייל", distractors: ["סוכר", "סיד", "ברזל"]),
        BankQuestion(prompt: "🚀\nאיך נקרא הכוכב האדום?", correctAnswer: "מאדים", distractors: ["צדק", "שבתאי", "נוגה"]),
        BankQuestion(prompt: "🧠\nאיזה איבר עוזר לנו לחשוב?", correctAnswer: "המוח", distractors: ["הלב", "הקיבה", "הריאות"])
    ]

    // MARK: - היסטוריה

    static let history: [BankQuestion] = [
        BankQuestion(prompt: "🇮🇱\nבאיזו שנה הוקמה מדינת ישראל?", correctAnswer: "1948", distractors: ["1945", "1950", "1967"]),
        BankQuestion(prompt: "👨‍💼\nמי היה ראש הממשלה הראשון של ישראל?", correctAnswer: "דוד בן גוריון", distractors: ["יצחק רבין", "מנחם בגין", "גולדה מאיר"]),
        BankQuestion(prompt: "🕯️\nבאיזה חג מדליקים נרות 8 ימים?", correctAnswer: "חנוכה", distractors: ["פסח", "סוכות", "פורים"]),
        BankQuestion(prompt: "🥯\nבאיזה חג אוכלים מצות?", correctAnswer: "פסח", distractors: ["חנוכה", "ראש השנה", "שבועות"]),
        BankQuestion(prompt: "🎭\nבאיזה חג מתחפשים?", correctAnswer: "פורים", distractors: ["סוכות", "חנוכה", "פסח"]),
        BankQuestion(prompt: "🌳\nבאיזה חג שותלים עצים?", correctAnswer: "ט\"ו בשבט", distractors: ["יום העצמאות", "שבועות", "ל\"ג בעומר"]),
        BankQuestion(prompt: "🇮🇱\nאיך קוראים לדגל של ישראל?", correctAnswer: "מגן דוד", distractors: ["סהר", "צלב", "כוכב"]),
        BankQuestion(prompt: "📜\nמה כתוב במגילת העצמאות?", correctAnswer: "הקמת מדינת ישראל", distractors: ["סיפור פסח", "מתכון", "שיר"]),
        BankQuestion(prompt: "👑\nמי היה המלך הראשון של ישראל?", correctAnswer: "שאול", distractors: ["דוד", "שלמה", "אברהם"]),
        BankQuestion(prompt: "🏛️\nמי בנה את בית המקדש הראשון?", correctAnswer: "שלמה", distractors: ["דוד", "משה", "שאול"]),
        BankQuestion(prompt: "🏺\nמה היה אצל המכבים שמספיק לשמן רק יום אחד?", correctAnswer: "פך שמן", distractors: ["מצה", "שופר", "ספר"]),
        BankQuestion(prompt: "🐑\nמי הוציא את בני ישראל ממצרים?", correctAnswer: "משה", distractors: ["יוסף", "אברהם", "דוד"]),
        BankQuestion(prompt: "🏛️\nהאם הפירמידות במצרים נבנו ע\"י המצרים הקדמונים?", correctAnswer: "כן", distractors: ["לא", "ע\"י רומאים", "ע\"י יוונים"]),
        BankQuestion(prompt: "🇺🇸\nאיזה יבשת גילה קולומבוס?", correctAnswer: "אמריקה", distractors: ["אפריקה", "אוסטרליה", "אסיה"]),
        BankQuestion(prompt: "📡\nמי המציא את הטלפון?", correctAnswer: "אלכסנדר גרהם בל", distractors: ["איינשטיין", "אדיסון", "בילגייטס"]),
        BankQuestion(prompt: "💡\nמי המציא את הנורה?", correctAnswer: "תומאס אדיסון", distractors: ["איינשטיין", "ניוטון", "טסלה"]),
        BankQuestion(prompt: "📕\nמה השפה של התנ\"ך?", correctAnswer: "עברית", distractors: ["אנגלית", "ערבית", "ארמית"]),
        BankQuestion(prompt: "📜\nאיפה חיו האבות אברהם, יצחק ויעקב?", correctAnswer: "בארץ ישראל", distractors: ["במצרים", "באמריקה", "באירופה"]),
        BankQuestion(prompt: "📚\nכמה ספרים יש בתורה?", correctAnswer: "5", distractors: ["7", "10", "3"]),
        BankQuestion(prompt: "🛡️\nמי לחם בגוליית?", correctAnswer: "דוד", distractors: ["משה", "שלמה", "שאול"])
    ]

    // MARK: - גיאוגרפיה

    static let geography: [BankQuestion] = [
        BankQuestion(prompt: "🇮🇱\nמה בירת ישראל?", correctAnswer: "ירושלים", distractors: ["תל אביב", "חיפה", "באר שבע"]),
        BankQuestion(prompt: "🌊\nאיזה ים נמצא ממערב לישראל?", correctAnswer: "הים התיכון", distractors: ["ים סוף", "ים המלח", "האוקיינוס"]),
        BankQuestion(prompt: "🏞️\nמה הים המלוח ביותר בעולם?", correctAnswer: "ים המלח", distractors: ["הים התיכון", "ים סוף", "ים השחור"]),
        BankQuestion(prompt: "🌎\nבאיזו יבשת נמצאת ישראל?", correctAnswer: "אסיה", distractors: ["אפריקה", "אירופה", "אמריקה"]),
        BankQuestion(prompt: "🗽\nמה בירת ארה\"ב?", correctAnswer: "וושינגטון", distractors: ["ניו יורק", "לוס אנג'לס", "שיקגו"]),
        BankQuestion(prompt: "🗼\nבאיזו ארץ נמצא מגדל אייפל?", correctAnswer: "צרפת", distractors: ["איטליה", "אנגליה", "ספרד"]),
        BankQuestion(prompt: "🐼\nאיפה חיים פנדות?", correctAnswer: "סין", distractors: ["יפן", "אוסטרליה", "הודו"]),
        BankQuestion(prompt: "🦘\nאיפה חיים קנגורו?", correctAnswer: "אוסטרליה", distractors: ["אפריקה", "אמריקה", "אירופה"]),
        BankQuestion(prompt: "🐧\nאיפה חיים פינגווינים?", correctAnswer: "באנטארקטיקה", distractors: ["בים התיכון", "באפריקה", "באמריקה"]),
        BankQuestion(prompt: "🏔️\nמה ההר הגבוה בעולם?", correctAnswer: "אוורסט", distractors: ["חרמון", "קילימנג'רו", "אלפים"]),
        BankQuestion(prompt: "🌊\nמה הים הגדול ביותר?", correctAnswer: "האוקיינוס השקט", distractors: ["הים התיכון", "האטלנטי", "ההודי"]),
        BankQuestion(prompt: "🏞️\nמה הנהר הארוך ביותר בעולם?", correctAnswer: "הנילוס", distractors: ["הירדן", "האמזונס", "המיסיסיפי"]),
        BankQuestion(prompt: "🌍\nכמה יבשות יש בעולם?", correctAnswer: "7", distractors: ["5", "6", "8"]),
        BankQuestion(prompt: "🐘\nאיפה חיים פילים?", correctAnswer: "באפריקה והודו", distractors: ["בישראל", "באוסטרליה", "באנטארקטיקה"]),
        BankQuestion(prompt: "🇮🇹\nמה בירת איטליה?", correctAnswer: "רומא", distractors: ["מילאנו", "פירנצה", "ונציה"]),
        BankQuestion(prompt: "🇪🇸\nמה בירת ספרד?", correctAnswer: "מדריד", distractors: ["ברצלונה", "סביליה", "ולנסיה"]),
        BankQuestion(prompt: "🇬🇧\nמה בירת אנגליה?", correctAnswer: "לונדון", distractors: ["מנצ'סטר", "ליברפול", "אדינבורו"]),
        BankQuestion(prompt: "🇯🇵\nמה בירת יפן?", correctAnswer: "טוקיו", distractors: ["סיאול", "פקין", "הונג קונג"]),
        BankQuestion(prompt: "🏜️\nמה המדבר הגדול בישראל?", correctAnswer: "הנגב", distractors: ["סהרה", "סיני", "ערבה"]),
        BankQuestion(prompt: "🌍\nמה היבשת הגדולה ביותר?", correctAnswer: "אסיה", distractors: ["אפריקה", "אמריקה", "אירופה"])
    ]

    /// Original + expanded — call sites get the full combined pool.
    static func bank(for topic: Topic) -> [BankQuestion]? {
        switch topic {
        case .english:   return english   + QuestionBanksExpanded.english
        case .logic:     return logic     + QuestionBanksExpanded.logic
        case .science:   return science   + QuestionBanksExpanded.science
        case .history:   return history   + QuestionBanksExpanded.history
        case .geography: return geography + QuestionBanksExpanded.geography
        case .math:      return nil  // generated algorithmically
        }
    }
}

// MARK: - Anti-repeat memory

/// Keeps the most-recently-served questions per topic so the runner
/// doesn't repeat items inside a session OR across the next few
/// sessions. Window slides at ~85% of the pool — when the pool refreshes
/// the kid won't see the same question for a long time.
///
/// Persisted to UserDefaults (per profile when a profile is active) so
/// closing and reopening the app doesn't erase the memory.
final class QuestionMemory {
    static let shared = QuestionMemory()
    private init() { load() }

    private let defaults = UserDefaults.standard
    private var recent: [Topic: [String]] = [:]

    private var storageKey: String {
        let pid = ProfileStore.shared.activeID?.uuidString ?? "default"
        return "questionMemory.\(pid)"
    }

    /// Pick a random question from `pool` that hasn't been served recently.
    /// Falls back to a true random when every question is in the recent
    /// window (only possible for very small pools).
    func pickFresh(_ pool: [BankQuestion], for topic: Topic) -> BankQuestion? {
        guard !pool.isEmpty else { return nil }
        // 85% — leaves a small pool of "fresh" candidates and keeps a long
        // tail of "already seen recently" out of rotation. With ~80 English
        // questions the kid will go through ~68 before any can repeat.
        let windowSize = max(5, (pool.count * 85) / 100)
        let recentList = recent[topic] ?? []
        let candidates = pool.filter { !recentList.contains(promptKey($0)) }
        let chosen = (candidates.isEmpty ? pool : candidates).randomElement()
        if let chosen {
            remember(promptKey(chosen), in: topic, windowSize: windowSize)
        }
        return chosen
    }

    /// Wipe memory for a specific profile (used by remote-reset).
    func clear(for profileID: UUID? = nil) {
        recent = [:]
        let key = profileID.map { "questionMemory.\($0.uuidString)" } ?? storageKey
        defaults.removeObject(forKey: key)
    }

    /// Pull state for the freshly-active profile.
    func reloadForActiveProfile() {
        load()
    }

    private func promptKey(_ q: BankQuestion) -> String { q.prompt }

    private func remember(_ key: String, in topic: Topic, windowSize: Int) {
        var list = recent[topic] ?? []
        list.append(key)
        if list.count > windowSize { list.removeFirst(list.count - windowSize) }
        recent[topic] = list
        save()
    }

    // MARK: - Persistence (per profile)

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            recent = [:]
            return
        }
        var rebuilt: [Topic: [String]] = [:]
        for (rawTopic, list) in decoded {
            if let t = Topic(rawValue: rawTopic) { rebuilt[t] = list }
        }
        recent = rebuilt
    }

    private func save() {
        let encodable = recent.reduce(into: [String: [String]]()) { dict, pair in
            dict[pair.key.rawValue] = pair.value
        }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
