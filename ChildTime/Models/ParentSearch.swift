import Foundation

/// 🔎 The parent's smart search (Rani, 2026-10-24: "שורת חיפוש חכמה שההורה
/// יכול לרשום לדוגמא איך אני משנה את הקוד הורה ואז זה ישר מביא אותו לעמוד
/// שצריך"). Free words in → the one page that does it, one tap away.
///
/// Entirely on the phone: no server, no outside AI (a Kids-Category app sends
/// nothing anywhere), works offline. Every place a parent can go is listed
/// below with the words people actually use for it, in all four languages.
enum ParentSettingsPage: String, CaseIterable, Hashable {
    case family, rules, notifications, pin, look, device, about
}

/// A child's inner settings page (the names ChildSettingsView already uses).
enum ChildSettingsPage: String, CaseIterable, Hashable {
    case screentime, school, bedtime, difficulty, worlds, language, devices, map, more
}

enum ParentSearchTarget: Hashable {
    case settings(ParentSettingsPage)
    case childPage(ChildSettingsPage, UUID)
    case gift(UUID), actions(UUID), report(UUID), kidMode(UUID)
    case chores, location, contest, addChild, activity, support, whatsNew
}

struct ParentSearchEntry: Identifiable, Hashable {
    let icon: String
    let title: String
    let place: String
    let keywords: [String]
    let target: ParentSearchTarget
    var id: ParentSearchTarget { target }
}

enum ParentSearch {

    // MARK: Everything a parent can reach

    static func entries(children: [Profile]) -> [ParentSearchEntry] {
        let inSettings = tr("בהגדרות")
        var out: [ParentSearchEntry] = [
            .init(icon: "🔐", title: tr("קוד הורה"), place: inSettings, keywords: [
                "קוד הורה", "קוד", "סיסמה", "סיסמא", "פין", "שכחתי", "להחליף קוד",
                "pin", "code", "password", "passcode", "parent code",
                "код", "пароль", "пин", "رمز", "كلمة المرور"], target: .settings(.pin)),
            .init(icon: "👪", title: tr("המשפחה"), place: inSettings, keywords: [
                "משפחה", "הורה נוסף", "הוספת הורה", "בן זוג", "בת זוג", "אמא", "אבא", "שם המשפחה",
                "אזור זמן", "שעון", "סדר הילדים", "סנכרון",
                "family", "parent", "partner", "spouse", "time zone", "order",
                "семья", "родитель", "муж", "жена", "часовой пояс", "عائلة", "والد", "زوج", "المنطقة الزمنية"], target: .settings(.family)),
            .init(icon: "🎮", title: tr("כללי המשחק"), place: inSettings, keywords: [
                "כללי המשחק", "כללים", "דקות לתשובה", "כמה דקות", "פרס", "עונש", "קנס", "טעות", "שאלות חכמות",
                "rules", "reward", "penalty", "minutes per answer",
                "правила", "награда", "штраф", "قواعد", "مكافأة", "عقوبة"], target: .settings(.rules)),
            .init(icon: "🔔", title: tr("התראות"), place: inSettings, keywords: [
                "התראות", "הודעות", "פוש", "צלצול",
                "notifications", "alerts", "push", "уведомления", "оповещения", "إشعارات", "تنبيهات"], target: .settings(.notifications)),
            .init(icon: "🎨", title: tr("מראה ושפה"), place: inSettings, keywords: [
                "מראה", "רקע", "צבע", "שפה", "עברית", "אנגלית", "רוסית", "ערבית",
                "look", "background", "theme", "color", "language", "english", "hebrew", "russian", "arabic",
                "язык", "фон", "цвет", "русский", "لغة", "خلفية", "لون", "عربية"], target: .settings(.look)),
            .init(icon: "📱", title: tr("הטלפון הזה"), place: inSettings, keywords: [
                "הטלפון הזה", "אפליקציות", "חסימה", "חסימת אפליקציות", "אפליקציות מותרות", "נעילת אפליקציות",
                "צלילים", "סאונד", "זמן מסך של אפל",
                "apps", "block", "blocked", "allowed apps", "sounds", "this phone",
                "приложения", "блокировка", "звуки", "تطبيقات", "حظر", "أصوات"], target: .settings(.device)),
            .init(icon: "ℹ️", title: tr("אודות ופרטיות"), place: inSettings, keywords: [
                "אודות", "פרטיות", "גרסה", "מחיקת חשבון", "מחיקה", "ייצוא", "התנתקות", "יציאה מהחשבון",
                "about", "privacy", "version", "delete account", "export", "sign out", "log out",
                "конфиденциальность", "версия", "удалить аккаунт", "выйти", "خصوصية", "إصدار", "حذف الحساب", "تسجيل الخروج"], target: .settings(.about)),
            .init(icon: "🧹", title: tr("מטלות"), place: tr("במסך הבית"), keywords: [
                "מטלות", "משימות", "סידור החדר", "עבודות בית", "chores", "tasks", "housework",
                "обязанности", "задания", "مهام", "أعمال المنزل"], target: .chores),
            .init(icon: "📍", title: tr("מיקום"), place: tr("במסך הבית"), keywords: [
                "מיקום", "מפה", "איפה", "איפה הילדים", "צפצוף", "location", "map", "where", "find",
                "местоположение", "карта", "где", "موقع", "خريطة", "أين"], target: .location),
            .init(icon: "🏆", title: tr("תחרות השבוע"), place: tr("במסך הבית"), keywords: [
                "תחרות", "תחרות השבוע", "צנצנת", "אלוף", "contest", "competition", "jar", "champion",
                "конкурс", "соревнование", "банка", "مسابقة", "بطل", "جرة"], target: .contest),
            .init(icon: "➕", title: tr("הוספת ילד/ה"), place: tr("במסך הבית"), keywords: [
                "הוספת ילד", "ילד חדש", "ילדה חדשה", "להוסיף ילד", "add child", "new child",
                "добавить ребенка", "إضافة طفل"], target: .addChild),
            .init(icon: "🔔", title: tr("מה קרה לאחרונה"), place: tr("בפעמון"), keywords: [
                "פעמון", "מה קרה", "עדכונים", "היסטוריה", "activity", "bell", "history",
                "события", "история", "النشاط", "سجل"], target: .activity),
            .init(icon: "💬", title: tr("תמיכה"), place: tr("צ׳אט עם הצוות"), keywords: [
                "תמיכה", "עזרה", "צאט", "צ׳אט", "בעיה", "באג", "לא עובד", "support", "help", "chat", "problem", "bug",
                "поддержка", "помощь", "проблема", "دعم", "مساعدة", "مشكلة"], target: .support),
            .init(icon: "✨", title: tr("מה חדש"), place: tr("בגרסה האחרונה"), keywords: [
                "מה חדש", "עדכון", "גרסה חדשה", "חידושים", "whats new", "what's new", "update", "new version",
                "что нового", "обновление", "ما الجديد", "تحديث"], target: .whatsNew),
        ]
        for p in children {
            let name = Question.stripNiqqud(p.name)
            let ofChild = tr("בהגדרות של \(name)")
            let words = [p.name, name]
            func page(_ icon: String, _ title: String, _ page: ChildSettingsPage, _ kw: [String]) -> ParentSearchEntry {
                .init(icon: icon, title: title, place: ofChild, keywords: kw + words, target: .childPage(page, p.id))
            }
            out += [
                page("⏱", tr("זמן מסך יומי"), .screentime, [
                    "זמן מסך", "מקסימום", "תקרה", "מגבלה", "מגבלה יומית", "כמה זמן ביום", "דקות ביום",
                    "screen time", "daily limit", "limit", "max", "лимит", "экранное время", "وقت الشاشة", "حد يومي"]),
                page("🏫", tr("זמן בית ספר"), .school, [
                    "בית ספר", "שעות בית ספר", "זמן בית ספר", "גן", "school", "kindergarten", "школа", "садик", "مدرسة", "روضة"]),
                page("🌙", tr("שעת שינה"), .bedtime, [
                    "שעת שינה", "שינה", "לילה", "ללכת לישון", "bedtime", "sleep", "night", "сон", "ночь", "نوم", "ليل"]),
                page("🎯", tr("רמת קושי"), .difficulty, [
                    "רמת קושי", "קושי", "קל", "קשה", "רמה", "כיתה", "difficulty", "level", "grade", "easy", "hard",
                    "сложность", "уровень", "класс", "صعوبة", "مستوى", "صف"]),
                page("🌍", tr("עולמות ונושאים"), .worlds, [
                    "עולמות", "נושאים", "מקצועות", "חשבון", "אנגלית", "מדעים", "worlds", "topics", "subjects", "math",
                    "темы", "предметы", "عوالم", "مواضيع"]),
                page("🗣", tr("שפת השאלות"), .language, [
                    "שפת השאלות", "שפה של הילד", "שפה", "question language", "language", "язык вопросов", "لغة الأسئلة"]),
                page("📲", tr("המכשיר של \(name)"), .devices, [
                    "מכשיר", "חיבור מכשיר", "לחבר", "אייפד", "טלפון של הילד", "קוד חיבור", "qr",
                    "device", "connect", "pair", "ipad", "устройство", "подключить", "جهاز", "ربط"]),
                page("🗺", tr("איפה \(name)"), .map, [
                    "מיקום", "איפה", "מפה", "צפצוף", "location", "map", "where", "где", "карта", "موقع", "أين"]),
                page("⚙️", tr("עוד הגדרות"), .more, [
                    "מחיקת ילד", "למחוק", "איפוס", "לאפס", "התקדמות", "חברים", "שם", "תמונה",
                    "delete child", "remove", "reset", "friends", "name", "photo",
                    "удалить", "сброс", "друзья", "حذف", "إعادة تعيين", "أصدقاء"]),
                .init(icon: "💝", title: tr("מתנת דקות ל\(name)"), place: tr("בכרטיס של \(name)"), keywords: [
                    "מתנה", "מתנת דקות", "לתת דקות", "דקות מתנה", "בונוס", "להוסיף דקות", "gift", "give minutes", "bonus", "add minutes",
                    "подарок", "дать минуты", "бонус", "هدية", "دقائق", "مكافأة"] + words, target: .gift(p.id)),
                .init(icon: "⚡", title: tr("נעילה, שחרור ומצב טיסה"), place: tr("בפעולות של \(name)"), keywords: [
                    "נעילה", "לנעול", "נעל", "לשחרר", "שחרור", "מצב טיסה", "טיסה", "קוד טיסה", "פעולות", "לסגור", "לעצור",
                    "lock", "unlock", "release", "flight", "airplane", "actions", "stop",
                    "заблокировать", "разблокировать", "самолет", "قفل", "فتح", "طيران"] + words, target: .actions(p.id)),
                .init(icon: "📊", title: tr("הדוח של \(name)"), place: tr("מידע נוסף"), keywords: [
                    "דוח", "מידע נוסף", "התקדמות", "טעויות", "שאלות שטעה", "כמה ענה", "ביצועים", "מה לתרגל",
                    "report", "progress", "mistakes", "practice", "отчет", "прогресс", "ошибки", "تقرير", "تقدم", "أخطاء"] + words, target: .report(p.id)),
                .init(icon: "🧒", title: tr("תנו ל\(name) לשחק כאן"), place: tr("מצב ילד בטלפון הזה"), keywords: [
                    "מצב ילד", "לשחק כאן", "לתת את הטלפון", "kid mode", "play here", "детский режим", "وضع الطفل"] + words,
                       target: .kidMode(p.id)),
            ]
        }
        return out
    }

    // MARK: Matching

    /// Words that say nothing about WHERE ("איך אני משנה את…").
    static let stopwords: Set<String> = [
        "איך", "אני", "אפשר", "רוצה", "רוצים", "מה", "את", "של", "על", "עם", "לי", "זה", "זאת", "יש", "אין", "לא", "כן",
        "לשנות", "משנה", "משנים", "להחליף", "מחליף", "לעשות", "עושים", "איפה", "למצוא", "מוצא", "צריך", "הילד", "הילדה",
        "how", "do", "i", "the", "a", "an", "to", "can", "my", "change", "set", "where", "is", "of", "for", "find",
        "как", "мне", "где", "это", "изменить", "كيف", "أين", "تغيير", "هل",
    ]

    static func normalize(_ s: String) -> String {
        let finals: [Character: Character] = ["ך": "כ", "ם": "מ", "ן": "נ", "ף": "פ", "ץ": "צ"]
        let plain = Question.stripNiqqud(s).lowercased()
        let mapped = String(plain.map { finals[$0] ?? $0 })
        let cleaned = mapped.unicodeScalars.map { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) ? Character($0) : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    private static func words(_ s: String) -> [String] { normalize(s).split(separator: " ").map(String.init) }

    /// "ובשעת" → also "בשעת", "שעת": one leading prefix letter peeled at a time.
    private static func variants(_ w: String) -> [String] {
        var out = [w]
        var cur = w
        while let f = cur.first, "והבלמשכ".contains(f), cur.count > 3 {
            cur.removeFirst()
            out.append(cur)
        }
        return out
    }

    private static func distanceAtMostOne(_ a: String, _ b: String) -> Bool {
        let x = Array(a), y = Array(b)
        if abs(x.count - y.count) > 1 { return false }
        var i = 0, j = 0, edits = 0
        while i < x.count && j < y.count {
            if x[i] == y[j] { i += 1; j += 1; continue }
            edits += 1
            if edits > 1 { return false }
            if x.count > y.count { i += 1 } else if y.count > x.count { j += 1 } else { i += 1; j += 1 }
        }
        return edits + (x.count - i) + (y.count - j) <= 1
    }

    private static func score(_ token: String, against keyword: String) -> Double {
        var best = 0.0
        for t in variants(token) {
            for k in variants(keyword) {
                if t == k { best = max(best, 3) }
                else if t.count >= 2 && k.hasPrefix(t) { best = max(best, t.count >= 3 ? 2.2 : 1) }
                else if k.count >= 3 && t.hasPrefix(k) { best = max(best, 1.8) }
                else if t.count >= 4 && distanceAtMostOne(t, k) { best = max(best, 1.6) }
                else if t.count >= 3 && k.contains(t) { best = max(best, 1) }
            }
        }
        return best
    }

    /// The best places for what the parent typed, best first.
    static func search(_ query: String, in entries: [ParentSearchEntry], limit: Int = 6) -> [ParentSearchEntry] {
        let tokens = words(query).filter { !stopwords.contains($0) }
        guard !tokens.isEmpty else { return [] }
        var scored: [(ParentSearchEntry, Double)] = []
        for e in entries {
            let kw = Set((e.keywords + [e.title]).flatMap(words))
            var total = 0.0
            var matched = 0
            for t in tokens {
                let s = kw.map { score(t, against: $0) }.max() ?? 0
                if s > 0 { matched += 1; total += s }
            }
            guard matched > 0 else { continue }
            // Every word found counts most; a phrase that matches whole beats parts.
            total += Double(matched == tokens.count ? 2 : 0)
            let phrase = normalize(query)
            if e.keywords.contains(where: { phrase.contains(normalize($0)) && normalize($0).count >= 4 }) { total += 2.5 }
            scored.append((e, total))
        }
        // Only what is close to the best answer: "קוד הורה" must not drag in every
        // page that mentions some other code.
        guard let best = scored.map(\.1).max() else { return [] }
        return scored.filter { $0.1 >= best * 0.6 }.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}
