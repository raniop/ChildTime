import Foundation

/// ✨ The release notes, as a real history instead of one growing pile.
///
/// The old shape was `items(for: version) -> [Item]` — one flat list per
/// MARKETING version. A release goes through a dozen TestFlight builds, and
/// every improvement from every one of them landed in the same list, so a
/// tester saw all 24 of them again on every upload. Rani: "במה חדש אתה משאיר
/// מלא מלא דברים אחורה מה הגבול?"
///
/// So each note now carries the build it actually shipped in, and the sheet
/// shows only what arrived AFTER the build you last saw. Everything older is
/// still there — one tap away, in the version history — instead of on top of
/// the new thing every time.
///
/// ⚠️ RELEASE CHECKLIST: add a `Release` for the build you are about to upload.
/// A build with no entry shows nothing, which is correct for a build that only
/// changed things a parent would never notice.
enum WhatsNewContent {

    struct Item: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let line: String
    }

    /// One upload's worth of notes. `build` is what `shouldShow` compares, and
    /// `version` is what a parent is shown — a whole release is many builds.
    struct Release: Identifiable {
        let build: Int
        let version: String
        /// One line for the history list, before you open the release.
        let headline: String
        let items: [Item]
        var id: Int { build }
    }

    /// What the parent sees, e.g. "2026.9.1". See `AppInfo` for the scheme.
    static var currentVersion: String { AppInfo.version }

    /// Newest first. `build: 0` is everything the app already did before the
    /// notes were dated — the first release, as one entry.
    static let releases: [Release] = [

        Release(build: 177, version: "2026.9.1", headline: tr("\"מה חדש\" מראה רק מה שחדש"), items: [
            Item(emoji: "✨", title: tr("רק מה שבאמת חדש בשבילכם"),
                 line: tr("קודם המסך הזה הראה את כל מה שנוסף אי פעם, בכל פעם מחדש. עכשיו הוא מראה רק את מה שהגיע מאז העדכון האחרון שראיתם")),
            Item(emoji: "🗂", title: tr("כל העדכונים, אחד אחד"),
                 line: tr("מסך חדש עם כל העדכונים של טופי, מהחדש לישן. לחיצה על עדכון מראה בדיוק מה השתנה בו. גם בהגדרות ההורים")),
        ]),

        Release(build: 176, version: "2026.9.1", headline: tr("עולם الأعياد, ודגל לערבית"), items: [
            Item(emoji: "🎊", title: tr("עולם الأعياد נפתח"),
                 line: tr("72 שאלות על רמדאן, עיד אל־פיטר, עיד אל־אדחא, חג המולד והפסחא — העולם היה קיים אבל לא היה אפשר להגיע אליו. עכשיו הוא במסך הבית של כל ילד שהאפליקציה שלו בערבית")),
            Item(emoji: "🇦🇪", title: tr("בורר השפה — עם דגל לכל שפה"),
                 line: tr("לערבית יש עכשיו דגל כמו לשאר השפות, והסדר הוא עברית, ערבית, אנגלית ורוסית")),
        ]),

        Release(build: 175, version: "2026.9.1", headline: tr("טופי מדבר גם ערבית"), items: [
            Item(emoji: "🇦🇪", title: tr("טופי מדבר גם ערבית"),
                 line: tr("כל האפליקציה והשאלות — כמעט 3,000 שאלות בערבית, ועולם חדש של الأعياد: רמדאן, שני העידים, חג המולד והפסחא. בהגדרות ההורים, במסך \"שפה\", בוחרים עברית, ערבית, רוסית או אנגלית")),
        ]),

        Release(build: 174, version: "2026.9.1", headline: tr("רמז עולה פחות"), items: [
            Item(emoji: "💡", title: tr("רמז עולה 12 שניות"),
                 line: tr("קודם רמז לקח שתי דקות שלמות מזמן המשחק, וזה היה הרבה מדי — עכשיו הוא עולה בדיוק כמו טעות")),
        ]),

        Release(build: 173, version: "2026.9.1", headline: tr("שפה לילד, מרחוק"), items: [
            Item(emoji: "🌍", title: tr("קובעים לילד שפה מהטלפון שלכם"),
                 line: tr("בכרטיס של כל ילד במסך ההורים אפשר לבחור באיזו שפה האפליקציה תופיע אצלו — והמכשיר שלו מתחלף מיד, בלי לגעת בו")),
            Item(emoji: "🔔", title: tr("ההתראות מגיעות בשפה של המכשיר"),
                 line: tr("ילד שהאפליקציה שלו ברוסית מקבל את ההתראות ברוסית, וההורה בעברית — באותה משפחה, על אותו אירוע")),
            Item(emoji: "🧹", title: tr("שאלות שחזרו על עצמן — נוקו"),
                 line: tr("71 שאלות כפולות ירדו מהמאגר העברי, כדי שילד לא יקבל פעמיים את אותה שאלה")),
        ]),

        Release(build: 172, version: "2026.9.1", headline: tr("טופי מדבר גם רוסית"), items: [
            Item(emoji: "🇷🇺", title: tr("טופי מדבר גם רוסית"),
                 line: tr("כל האפליקציה, וגם השאלות עצמן — כמעט 3,000 שאלות שנכתבו מחדש ברוסית, כולל עולם ישראל וחגי תשרי. בהגדרות ההורים, במסך \"שפה\", בוחרים עברית, אנגלית או רוסית")),
        ]),

        Release(build: 171, version: "2026.9.1", headline: tr("תשובה שגויה מעבירה הלאה"), items: [
            Item(emoji: "➡️", title: tr("טעות תמיד מעבירה לשאלה הבאה"),
                 line: tr("לפעמים אחרי טעות חזרה בדיוק אותה שאלה, וזה נראה לילד כאילו כלום לא קרה. עכשיו השאלה תחזור מאוחר יותר — לא מיד")),
            Item(emoji: "🧹", title: tr("\"לטאטא את החדר\" נקרא עכשיו \"לסדר את החדר\""),
                 line: tr("מטלה שילד באמת מכיר בשם הזה")),
        ]),

        // 🏁 The app as it was when the notes started being dated.
        Release(build: 0, version: "2026.9.1", headline: tr("הגרסה הראשונה של טופי"), items: [
            Item(emoji: "💳", title: tr("רכישת טופי+ נרשמת מיד"),
                 line: tr("אחרי אישור התשלום ב-App Store המנוי נפתח באותו רגע. קודם קרה שהתשלום עבר והאפליקציה עדיין הציגה את מסך הרכישה")),
            Item(emoji: "👪", title: tr("שם למשפחה כבר בהרשמה"),
                 line: tr("משפחה חדשה נשאלת איך לקרוא לה, עם הצעה מוכנה משם החשבון — במקום להישאר \"תנו שם למשפחה\" במסך הראשי")),
            Item(emoji: "🚪", title: tr("מכשיר תקוע כבר לא תקוע"),
                 line: tr("מכשיר שאיבד את הקשר למשפחה מציע לאפס את עצמו ולחזור למסך הפתיחה, בלי למחוק ולהתקין מחדש")),
            Item(emoji: "👑", title: tr("מסך טופי+ נכנס למסך אחד"),
                 line: tr("כל מה שכלול, שני המסלולים והכפתור — בלי גלילה. ומנוי פעיל פותח את מסך ניהול המנוי של Apple")),
            Item(emoji: "🔒", title: tr("חלון משחק אחד — בכל המכשירים יחד"),
                 line: tr("כשהילד פותח דקות באייפון, האייפד מראה שהחלון פתוח שם ומציע להעביר אותו לכאן. אותן דקות לא נפתחות פעמיים, והמגבלה היומית נספרת פעם אחת לכל הילד")),
            Item(emoji: "🔁", title: tr("מעבירים את הזמן בלחיצה אחת"),
                 line: tr("האייפד לא ייפתח עד שהאייפון באמת ננעל — ורק אז הדקות שנשארו עוברות אליו. בלי כפילויות ובלי דקות שנעלמות")),
            Item(emoji: "🔓", title: tr("נעילה מרחוק שתמיד עובדת"),
                 line: tr("גם אם המכשיר של הילד כבוי או תקוע, 'נעל עכשיו (מרחוק)' סוגר את זמן המשחק — והילד יכול לפתוח מיד במכשיר השני")),
            Item(emoji: "📶", title: tr("עובד גם בלי אינטרנט"),
                 line: tr("אם נפתח חלון בלי רשת, ברגע שהחיבור חוזר האפליקציה מסדרת הכול לבד — ובלי לקחת מהילד דקות שהרוויח")),
            Item(emoji: "🕐", title: tr("שינוי שעון כבר לא מזכה בזמן"),
                 line: tr("הזזת השעון במכשיר לא מוסיפה דקות, לא פותחת מחדש פרסים יומיים ולא משאירה אפליקציות פתוחות")),
            Item(emoji: "🧹", title: tr("מסך מטלות חדש וצבעוני"),
                 line: tr("כפתור 'עשיתי!' בצבע של הילד/ה, כתר וברכת 'אלוף/אלופה', וקטגוריה נפרדת של 'בוצעו היום'. הפרס תמיד דקות משחק")),
            Item(emoji: "📖", title: tr("עשרות קטעי קריאה חדשים"),
                 line: tr("קטעי הבנת הנקרא לכל הכיתות, מותאמים לחומר הנלמד בבית הספר — עם הרבה פחות חזרות")),
            Item(emoji: "🎓", title: tr("שאלות מותאמות לכיתה"),
                 line: tr("כל שאלה באפליקציה מתויגת לפי תוכנית הלימודים — כל ילד מקבל בדיוק את הרמה שלו")),
            Item(emoji: "👪", title: tr("מסך הורים חדש — במבט של כמה שניות"),
                 line: tr("לכל ילד כרטיס פשוט: דקות היום מתוך המקסימום, שאלות, נכונות ואחוז הצלחה. לחיצה פותחת דוח מלא — במה הילד חזק, מה כדאי לתרגל, האם הוא משתפר, ותובנה יומית עם המלצה. בלי כוכבים ויהלומים — אלה של הילדים")),
            Item(emoji: "🎲", title: tr("\"הרפתקה חכמה\" נקראת עכשיו טופי טיים"),
                 line: tr("אותו מסלול חכם שמתאים את השאלות לילד — עם שם קצר יותר וקובייה. זה החלק החינמי של טופי")),
            Item(emoji: "👑", title: tr("טופי+ הוא מנוי משפחתי"),
                 line: tr("קונים פעם אחת, בטלפון של ההורה — וכל המכשירים של כל הילדים נפתחים. במכשיר של הילד אין יותר מסך תשלום: יש כפתור 'בקש מאבא או אמא', והבקשה מגיעה ישר לטלפון שלכם")),
            Item(emoji: "👪", title: tr("שם למשפחה, וטופי+ במסך הראשי"),
                 line: tr("לחיצה על הכותרת במסך ההורים נותנת שם למשפחה (\"משפחת גולן\"), והוא מופיע לכל ההורים. טופי+ עבר לכרטיס במסך הראשי, וההגדרות סודרו מחדש לשישה מסכים קצרים")),
            Item(emoji: "🪟", title: tr("עיצוב זכוכית חדש — בכל האפליקציה"),
                 line: tr("כל מסך עבר לעיצוב זכוכית שקוף על רקע המותג: מסך הבית של הילד, השאלות, גלגל המזל, החנות, המטלות, הדירוג והטורניר — וגם מסך ההורים, הדוח לכל ילד, ההגדרות ומסך הרכישה. הכפתורים והכרטיסים אחידים, קריאים ורגועים יותר")),
            Item(emoji: "🌍", title: tr("כל עולם אפשר לפתוח גם ל־30 יום, בלי מנוי"),
                 line: tr("לא רוצים מנוי קבוע? כל עולם בסיסי נפתח לילד אחד ל־30 יום בתשלום חד־פעמי, בלי חידוש אוטומטי. במסך ההורים יש מדף \"העולמות של טופי\", ובכל עמוד עולם שתי דרכים: רק העולם הזה, או טופי+ לכל המשפחה. 3 ימים לפני הסיום תקבלו תזכורת, וההתקדמות של הילד נשמרת")),
            Item(emoji: "⚽", title: tr("שאלונים חדשים לילדים — עולם הכדורגל ראשון"),
                 line: tr("במסך ההורים יש עכשיו מדף \"שאלונים חדשים\": עולם שלם של שאלות בנושא שהילד אוהב. למנויי טופי+ הוא נפתח אוטומטית לכל הילדים; בלי מנוי בוחרים לאיזה ילד לשלוח, וברגע הבא הוא מקבל מתנה במסך הבית שלו. ילד שרוצה שאלון לוחץ \"בקש מאבא או אמא\" — בלי מחירים במכשיר של הילד")),
            Item(emoji: "🔊", title: tr("ההקראה אומרת קודם את המספר"),
                 line: tr("\"מספר 1. קטן. מספר 2. …\" — עם הפסקה בין המספר לתשובה, כדי שילד שעוד לא קורא יבחר בקלות. ואם התקנתם את קול \"כרמית משופרת\" בהגדרות הנגישות, טופי משתמש בו")),
            Item(emoji: "🧬", title: tr("ההתקדמות של כל ילד נשארת שלו"),
                 line: tr("תיקנו תקלה נדירה שבה במכשיר משותף ההתקדמות של ילד אחד יכלה להיכתב אצל אח או אחות. עכשיו זה פשוט לא אפשרי")),
            Item(emoji: "💛", title: tr("יציב יותר, בטוח יותר"),
                 line: tr("המון שיפורים שקטים לשמירה על ההתקדמות, הפרטיות והפרסים של הילדים בכל המכשירים")),
        ]),
    ]

    // MARK: what THIS install has not seen

    /// Kept from when this was build-keyed: an existing install holds a build
    /// number here, so nothing has to be migrated.
    private static let seenKey = "whatsNew.shownForBuild"

    /// A TestFlight build carries a sandbox receipt; the App Store one does not.
    private static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// The last build whose notes this install has already been shown.
    ///
    /// The stored value has been three different things over time (a build
    /// number, a version string, a "version (build)" pair), so every shape is
    /// read here rather than migrated — the number in it is what matters.
    private static var seenBuild: Int? {
        guard let raw = UserDefaults.standard.string(forKey: seenKey) else { return nil }
        // "2026.9.1 (174)" → 174 · "174" → 174 · "2026.9.1" → the release it names
        if let open = raw.lastIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            return Int(raw[raw.index(after: open)..<close])
        }
        if let n = Int(raw) { return n }
        return releases.first(where: { $0.version == raw })?.build
    }

    /// What to write once the sheet has been shown.
    static var seenToken: String { "\(currentVersion) (\(AppInfo.build))" }

    /// This build's number. `AppInfo.build` is the string Info.plist holds.
    private static var currentBuild: Int { Int(AppInfo.build) ?? .max }

    /// Only what landed after the build this install last saw. A parent who
    /// skipped four builds gets all four — but never the whole history.
    ///
    /// The upper bound matters while a release is being written: a note for a
    /// build that has not shipped yet must not appear on the build in hand.
    static var unseenReleases: [Release] {
        guard let seen = seenBuild else { return [] }   // fresh install: nothing is "new"
        return releases.filter { $0.build > seen && $0.build <= currentBuild }
    }

    static var unseenItems: [Item] { unseenReleases.flatMap(\.items) }

    /// Real parents should see the notes once per RELEASE, not on every internal
    /// upload. Testers need the opposite. Both fall out of the same list: on the
    /// App Store a release is one entry, on TestFlight it is many.
    @MainActor
    static var shouldShow: Bool {
        guard UserDefaults.standard.string(forKey: seenKey) != nil else {
            UserDefaults.standard.set(seenToken, forKey: seenKey)   // fresh install → just record
            return false
        }
        return !unseenItems.isEmpty
    }

    @MainActor
    static func markShown() {
        UserDefaults.standard.set(seenToken, forKey: seenKey)
    }
}
