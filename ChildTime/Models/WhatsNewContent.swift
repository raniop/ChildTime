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
        /// A stable name for a note that something else also shows — the
        /// "מה חדש" STORY (`WhatsNewStories`) reads its parent-facing lines
        /// from here by key, so a sentence a parent can read in two places is
        /// written in exactly one.
        var key: String? = nil

        init(emoji: String, title: String, line: String, key: String? = nil) {
            self.emoji = emoji
            self.title = title
            self.line = line
            self.key = key
        }
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

        // 2026.10.8 in one list, the most important first (Rani approved the
        // order; 211 and 212 were TestFlight-only builds of the same version).
        Release(build: 214, version: "2026.10.8", headline: tr("פעולות פשוטות יותר, וזמן מסך מדויק"), items: [
            Item(emoji: "⚡", title: tr("כל הפעולות במקום אחד"),
                 line: tr("בכפתור ״פעולות״ של כל ילד: מתנת דקות, נעילה ואיפה הילד בלחיצה אחת, ומשם זמן מסך, מטלות וכל ההגדרות")),
            Item(emoji: "🧒", title: tr("מסך בית רגוע יותר לילד"),
                 line: tr("סרגל אחד למטה למתנה, לדקות ולקוד הסודי, ו״היום שלי״ עם המטלות — יותר מקום לעולמות")),
            Item(emoji: "⏱", title: tr("זמן המסך נספר נכון"),
                 line: tr("דקות שחזרו לארנק כשחלון משחק נסגר מוקדם לא נספרות יותר כאילו שוחקו, גם בדוח להורה")),
            Item(emoji: "🛡", title: tr("רק הורה פותח משפחה"),
                 line: tr("ילד שמנסה להירשם כהורה מקבל מסך שמבקש לפנות לאבא או לאמא — הגיל נבדק דרך אפל או לפי שנת הלידה")),
            Item(emoji: "✏️", title: tr("עריכה בלחיצה על העיפרון"),
                 line: tr("העיפרון ליד שם הילד פותח ישר את השם, התמונה והכיתה")),
            Item(emoji: "⌚️", title: tr("פעולות מהשעון"),
                 line: tr("באפל ווטש: מתנת דקות, נעילה וצפצוף לטלפון של כל ילד, ישר מהיד")),
            Item(emoji: "🙂", title: tr("יציאה ממצב ילד בזיהוי אחד"),
                 line: tr("זיהוי הפנים ביציאה ממצב ילד פותח ישר את מסך ההורה, בלי לבקש שוב")),
            Item(emoji: "🔢", title: tr("מספרים משמאל לימין"),
                 line: tr("קוד ההורה, קוד הילד וגלגלי הכספת מתמלאים משמאל לימין, כמו כל מספר")),
            Item(emoji: "🔤", title: tr("בלי ניקוד במסכי ההורה"),
                 line: tr("כל המסכים של ההורה כתובים עכשיו בלי ניקוד. אצל הילדים הניקוד נשאר")),
            Item(emoji: "📱", title: tr("מותאם ל-iPhone Duo"),
                 line: tr("כל מסך מנצל את כל הרוחב ויושב באמצע המכשיר, סגור ופתוח")),
        ]),

        Release(build: 208, version: "2026.10.7", headline: tr("איפה הילדים, במבט אחד"), items: [
            Item(emoji: "🏠", title: tr("איפה הילדים, במבט אחד"),
                 line: tr("בכרטיס של כל ילד כתוב עכשיו בבית, בבית הספר או אצל סבתא, עם הסמל של המקום")),
        ]),

        Release(build: 204, version: "2026.10.7", headline: tr("לדעת איפה הילדים"), items: [
            Item(emoji: "📍", title: tr("לדעת איפה הילדים"),
                 line: tr("מפה עם הילדים, התראה כשמגיעים לבית הספר או הביתה, וצפצוף לטלפון שהלך לאיבוד. רק אם תפעילו, ורק ההורים רואים")),
        ]),

        Release(build: 203, version: "2026.10.7", headline: tr("זמן בית ספר ושעת שינה"), items: [
            Item(emoji: "🏫", title: tr("זמן בית ספר ושעת שינה"),
                 line: tr("בהגדרות של כל ילד בוחרים ימים ושעות שבהם אי אפשר לפתוח דקות משחק. משחק פתוח נעצר, והדקות שנשארו חוזרות לארנק")),
        ]),

        Release(build: 202, version: "2026.10.6", headline: tr("שלוש דרגות בכל עולם, ופנייה נכונה לכל ילד וילדה"), items: [
            Item(emoji: "🏆", title: tr("שלוש דרגות בכל עולם"),
                 line: tr("כל עולם נפתח שוב בשלוש דרגות — ארד, כסף וזהב — וכל דרגה מאתגרת קצת יותר. מי שמסיים את שלושתן מקבל כתר של אלוף או אלופה 👑")),
            Item(emoji: "🔄", title: tr("יודעים כשיש גרסה חדשה"),
                 line: tr("כשיוצאת גרסה חדשה של טופי, מופיעה הודעה קצרה עם מה שחדש וכפתור שמוביל ישר לעדכון")),
            Item(emoji: "👧", title: tr("מדברים אל הילדה בלשון נקבה"),
                 line: tr("במסכים של ילדה, טופי פונה אליה בלשון נקבה — בפרסים, ברמזים ובמשחקים")),
            Item(emoji: "🌍", title: tr("ילד או ילדה — בכל שפה"),
                 line: tr("בהוספת ילד, הבחירה בין ילד לילדה מופיעה נכון באנגלית, ברוסית ובערבית")),
        ]),

        Release(build: 200, version: "2026.10.6", headline: tr("כל תשובה נכונה נכנסת מיד לזמן"), items: [
            Item(emoji: "⏱", title: tr("כל תשובה נכונה נכנסת מיד לזמן"),
                 line: tr("כל תשובה נכונה מוסיפה מיד את השניות שלה לזמן המשחק, בלי לחכות לסבב של 10 — וטעות אף פעם לא מורידה מהזמן שכבר נצבר")),
            Item(emoji: "⚡", title: tr("סיבוב הפתעה מרוויח זמן"),
                 line: tr("גם תשובות נכונות בסיבוב ההפתעה מוסיפות זמן משחק, ומסך הסיום מראה כמה")),
            Item(emoji: "💡", title: tr("כל מספר מסביר את עצמו"),
                 line: tr("לחיצה על כל מספר במסך הבית של הילד — דקות לשחק, דקות מתנה, הרווחת היום, נכונות היום — פותחת הסבר קצר")),
            Item(emoji: "🔢", title: tr("מימין לשמאל, כמו בעברית"),
                 line: tr("סדרות מספרים והקוד בכספת נקראים עכשיו מימין לשמאל, וטופי טיים תמיד ראשון בין העולמות")),
        ]),

        Release(build: 199, version: "2026.10.5", headline: tr("התחלה נכונה גם במכשיר הראשון"), items: [
            Item(emoji: "🧭", title: tr("מתחילים כאן"),
                 line: tr("מסך הפתיחה אומר להורה איפה להתחיל, ומי שפותח טופי במכשיר של הילד בלי קוד חיבור מקבל שלוש דרכים להמשיך במקום מסך סריקה סתום"),
                 key: "startHere"),
        ]),

        Release(build: 198, version: "2026.10.5", headline: tr("פרס בכל סוף סיבוב, וזמן מדויק לשנייה"), items: [
            Item(emoji: "🏅", title: tr("פרס בכל סוף סיבוב"),
                 line: tr("בסוף כל סיבוב רואים כוכבים, יהלומים וכמה זמן מסך הרווחתם — וגם סיבוב פחות מוצלח נגמר בפרס"),
                 key: "roundReward"),
            Item(emoji: "⏱", title: tr("זמן מדויק לשנייה"),
                 line: tr("הזמן שהילד הרוויח מוצג בדיוק כמו זמן מתנה — בלי עיגול שמעלים שניות"),
                 key: "exactTime"),
            Item(emoji: "🎁", title: tr("מתנה קטנה נפתחת"),
                 line: tr("גם שארית של פחות מדקה שנתתם במתנה נפתחת עכשיו, במקום להיתקע"),
                 key: "smallGift"),
        ]),

        Release(build: 197, version: "2026.10.4", headline: tr("התחלה פשוטה ב-4 צעדים"), items: [
            Item(emoji: "🧭", title: tr("התחלה פשוטה ב-4 צעדים"),
                 line: tr("משפחה, ילד, מכשיר ונעילה — עם פס התקדמות למעלה, ובטלפון של הילד אישור זמן מסך כבר בהתחלה"),
                 key: "onboarding4"),
            Item(emoji: "📐", title: tr("כפתורים מיושרים"),
                 line: tr("בכרטיס של כל ילד, \"פעולות\" ו\"מידע נוסף\" באותו גובה ובאותו קו"),
                 key: "aligned"),
        ]),

        Release(build: 196, version: "2026.10.3", headline: tr("נעילה שבאמת נועלת — ממקום אחד"), items: [
            Item(emoji: "🔒", title: tr("נעילה שבאמת נועלת"),
                 line: tr("מהרגע שמאשרים זמן מסך בטלפון של הילד, הכל נעול חוץ מטופי עד שמרוויחים זמן — גם אפליקציה שיתקין מחר. בלי לבחור או לסמן כלום"),
                 key: "lock"),
            Item(emoji: "📱", title: tr("מקום אחד במכשיר הילד"),
                 line: tr("ארבע רשימות הפכו לכפתור אחד: מה נשאר פתוח. ולידו פתיחה זמנית של אפליקציה לזמן קצוב"),
                 key: "onePlace"),
            Item(emoji: "🧒", title: tr("תנו לילד לשחק בטלפון שלכם"),
                 line: tr("בכרטיס של כל ילד יש כפתור בשורה משלו, עם השם שלו, שמוסר לו את הטלפון שלכם — והיציאה חזרה מוגנת בקוד"),
                 key: "kidMode"),
            Item(emoji: "✨", title: tr("ועוד תיקונים"),
                 line: tr("מסך הנעילה מראה כמה דקות באמת מרוויחים, ו\"מה חדש\" עובר מימין לשמאל"),
                 key: "more191"),
            Item(emoji: "🧭", title: tr("הדרכה על המסך"),
                 line: tr("בפעם הראשונה, נקודה על כל כפתור במסך הבית — אצלכם ואצל הילד. אפשר להציג שוב מההגדרות"),
                 key: "tour"),
            Item(emoji: "🚀", title: tr("התחלה קלה יותר"),
                 line: tr("אחרי שמוסיפים ילד שואלים אם יש לו מכשיר משלו, ורשימה קצרה במסך הבית מראה מה נשאר כדי לסיים"),
                 key: "setup"),
            Item(emoji: "✏️", title: tr("עריכת ילד בלחיצה אחת"),
                 line: tr("לחיצה על השם של הילד במסך הבית פותחת את ההגדרות שלו — וגם מתפריט הפעולות ומהכותרת של הדף שלו"),
                 key: "editChild"),
            Item(emoji: "🎁", title: tr("טופי+ במתנה ל-30 יום"),
                 line: tr("כל משפחה מקבלת את טופי+ במתנה ל-30 יום, מהרגע שהיא נפתחת — בלי כרטיס אשראי"),
                 key: "gift30"),
            Item(emoji: "🔐", title: tr("קוד לזמן מסך, ומחיקה פשוטה"),
                 line: tr("הסבר צעד אחר צעד, עם ציור של מסכי האייפון, איך מגדירים קוד לזמן מסך ואיך מוחקים את טופי"),
                 key: "passcode"),
            Item(emoji: "⏸", title: tr("עוצרים כדי לקרוא"),
                 line: tr("ב\"מה חדש\" מחזיקים אצבע על המסך או לוחצים ⏸ — והסטורי מחכה עד שממשיכים"),
                 key: "storyPause"),
        ]),

        Release(build: 190, version: "2026.10.3", headline: tr("12 משחקים חדשים — הילד בוחר איך לשחק"), items: [
            Item(emoji: "🎮", title: tr("בוחרים עולם, ואז בוחרים משחק"),
                 line: tr("אחרי בחירת עולם נפתח מסך \"איך בא לך לשחק?\" — שאלות רגילות או אחד המשחקים, ובלחיצה אחת נכנסים ישר לשחק"),
                 key: "chooser"),
            Item(emoji: "🕹", title: tr("12 משחקים, לפי מה שיש בעולם"),
                 line: tr("מצאו את הזוגות, פיצוץ בלונים, בנו את המילה, מפצחים, תפזורת, נכון או לא נכון, מיון לסלים, התבנית, 2048 של טופי, הכספת, המכולת ומאזניים. בכל עולם מופיעים רק המשחקים שמתאימים לתוכן שלו"),
                 key: "games12"),
            Item(emoji: "🎓", title: tr("כל משחק לפי הכיתה של הילד"),
                 line: tr("בעברית הרמה עולה חזק עם הגיל. באנגלית, שהיא שפה שנייה, היא נשארת נגישה"),
                 key: "gradefit"),
            Item(emoji: "⏱", title: tr("גם במשחקים מרוויחים דקות"),
                 line: tr("כל תשובה נכונה במשחק מרוויחה זמן מסך בדיוק כמו שאלה רגילה"),
                 key: "minutes"),
            Item(emoji: "⚡", title: tr("סיבוב הפתעה באמצע השאלות"),
                 line: tr("כל כמה שאלות קופצת הפתעה — משחק קצר עם כוכבים ויהלומים כפולים"),
                 key: "surprise"),
            Item(emoji: "📝", title: tr("להורים: רק שאלות רגילות"),
                 line: tr("בעמוד הילד יש מתג חדש שמכבה את המשחקים, והילד נכנס ישר לשאלות"),
                 key: "onlyQuestions"),
        ]),

        Release(build: 185, version: "2026.10.2", headline: tr("צ'אט עם צוות טופי, אייפד של הילד וכרטיס ילד מסודר"), items: [
            Item(emoji: "⏱", title: tr("אתם קובעים כמה זמן מסך ביום"),
                 line: tr("כבר ביצירת ילד בוחרים כמה זמן מסך הוא יכול להרוויח ביום — חצי שעה, שעה, שעתיים, בלי הגבלה, או כל מספר דקות שתרצו. ואפשר לשנות בכל רגע בהגדרות של הילד")),
            Item(emoji: "💬", title: tr("צ'אט עם צוות טופי"),
                 line: tr("שאלה? משהו לא ברור? הכפתור העגול 💬 במסך הבית פותח שיחה איתנו, ואנחנו עונים ישר לטלפון שלכם")),
            Item(emoji: "📱", title: tr("האייפד הוא של הילד"),
                 line: tr("הגדרתם בטעות את האייפד של הילד כמכשיר הורה? בהגדרות יש עכשיו \"להפוך את האייפד הזה למכשיר של ילד\" — בלחיצה אחת, בלי למחוק כלום. והתקנה חדשה באייפד ממליצה מראש על מכשיר ילד")),
            Item(emoji: "🧹", title: tr("כרטיס ילד מסודר"),
                 line: tr("מתנה, נעילה ומטלות בלחיצה אחת למעלה, הדוח מתחת, כל המכשירים במקום אחד, וכל ההגדרות של הילד ברשימה אחת — במקום כפתור שפתח עוד כרטיס ותפריט ארוך")),
            Item(emoji: "🐉", title: tr("קרב בוס נספר"),
                 line: tr("תשובות בקרב בוס לא הופיעו בדוחות שלכם. עכשיו כל תשובה בקרב נספרת — בשאלות היום, בהצלחה ובהתקדמות")),
            Item(emoji: "✨", title: tr("ועוד תיקונים"),
                 line: tr("\"דקות היום\" במקום מילה לא ברורה, קוד הגנת זמן המשחק תמיד גלוי לכם בהגדרות הילד, שדה הקוד בערבית קריא, ומסך פתיחה בשפה של האייפון")),
        ]),

        Release(build: 181, version: "2026.10.1", headline: tr("מתנה ראשונה מגיעה מיד, ושאלות שמתאימות לילד"), items: [
            Item(emoji: "💝", title: tr("מתנה ראשונה מגיעה מיד"),
                 line: tr("מכשיר של ילד שרק הצטרף למשפחה לא קיבל מתנת דקות עד שסגרו ופתחו את טופי. עכשיו המתנה מגיעה תוך שנייה, גם בדקות הראשונות")),
            Item(emoji: "⌨️", title: tr("קוד החיבור מוקלד בכל מקלדת"),
                 line: tr("באייפון בעברית אי אפשר היה להקליד את קוד החיבור, כי עלתה רק מקלדת עברית. עכשיו עולה מקלדת לטינית — לחיבור ילד, להורה שני ולהוספת חבר")),
            Item(emoji: "🌍", title: tr("טופי מדבר בשפה של האייפון"),
                 line: tr("התקנה חדשה נפתחת בשפה של המכשיר — עברית, English, Русский או العربية — ואפשר להחליף כבר במסך הראשון")),
            Item(emoji: "🧠", title: tr("שאלות שמתאימות לילד"),
                 line: tr("ילד שמצליח מקבל שאלות קשות מכיתה אחת מעליו, במקום לחזור לשאלות של גן. ותשובות שנראו אותו דבר בלי ניקוד הוחלפו")),
            Item(emoji: "✨", title: tr("ועוד המון תיקונים קטנים"),
                 line: tr("\"יום אחד\" במקום \"1 ימים\", קוד הורה שנפתח נקי אחרי יציאה מהאפליקציה, אזהרה כשאין במכשיר הילד הרשאת \"זמן מסך\", ו\"רבע שעה\" במתנות")),
        ]),

        Release(build: 180, version: "2026.10.1", headline: tr("עצרתם מוקדם? הדקות חוזרות גם למכסה"), items: [
            Item(emoji: "⏱", title: tr("עצירה מוקדמת כבר לא עולה לילד ביום"),
                 line: tr("ילד שפתח 90 דקות, שיחק 22 ועצר — קיבל את 68 הדקות בחזרה לארנק, אבל הן המשיכו להיספר נגד המכסה היומית שלו. הוא ראה \"הגעת למקסימום\" עם דקות שהוא לא יכול לגעת בהן. עכשיו הן חוזרות לשניהם, וגם אם המכשיר השני עוד לא יודע שהוא עצר")),
        ]),

        Release(build: 178, version: "2026.9.1", headline: tr("מתנה שנתתם — נפתחת"), items: [
            Item(emoji: "💝", title: tr("המתנה שלכם נפתחת תמיד"),
                 line: tr("ילד שראה \"מתנה מההורים · 60 דקות\" ולחץ, יכול היה לחזור למסך הבית בלי שנפתח לו כלום ובלי מילה. הדקות תמיד היו שם — רק הכפתור והפתיחה ספרו אותן משני מקומות שונים. עכשיו הם סופרים מאותו מקום")),
            Item(emoji: "🔔", title: tr("ואם בכל זאת משהו נתקע — תדעו"),
                 line: tr("אם פתיחה לא מצליחה פעמיים ברצף, הילד שומע משפט רגוע במקום שתיקה, ואתם מקבלים התראה. הדקות לא נמחקות אף פעם — הן נשארות בכיס שלו")),
            Item(emoji: "📖", title: tr("הבנת הנקרא באייפד"),
                 line: tr("באייפד, כרטיס הקטע נשאר ענק גם כשהקטע היה קצר, טופי עמד על תשובה 4 וכפתור הרמז נחתך בקצה המסך. עכשיו הכרטיס בגודל הקטע, התשובות ממלאות את השטח, והכל נשאר בתוך המסך")),
        ]),

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
                 line: tr("לערבית יש עכשיו דגל בבורר השפה, כמו לכל שאר השפות")),
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
    private static var seenBuild: Int? { build(inToken: UserDefaults.standard.string(forKey: seenKey)) }

    /// The build inside a stored token, in every shape the app has ever
    /// written: "2026.9.1 (174)" → 174 · "174" → 174 · "2026.9.1" → the
    /// release it names. `nil` in, `nil` out — "this reader has no record".
    /// Shared with the "מה חדש" STORY, which keeps a token of its own per child.
    static func build(inToken raw: String?) -> Int? {
        guard let raw else { return nil }
        if let open = raw.lastIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            return Int(raw[raw.index(after: open)..<close])
        }
        if let n = Int(raw) { return n }
        return releases.first(where: { $0.version == raw })?.build
    }

    /// One note by its stable `key` — the single source for a line that the
    /// release notes AND the story both show (see `WhatsNewStories`).
    static func item(_ key: String) -> Item? {
        releases.lazy.flatMap(\.items).first { $0.key == key }
    }

    /// Builds that landed after `seen` and no later than this one. The story
    /// keeps its own seen-token per child and asks this.
    static func unseenBuilds(seen: Int?) -> [Int] {
        guard let seen else { return [] }
        return releases.filter { $0.build > seen && $0.build <= currentBuild }.map(\.build)
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
        return releases.filter { $0.build > min(seen, versionFloor) && $0.build <= currentBuild }
    }

    /// The last build BEFORE the version in hand. Rani: "אתה אמור להציג את כל
    /// הדברים החדשים מהגרסה האחרונה שאושרה באפל" — a tester who already saw
    /// build 207 of 2026.10.7 is shown all of 2026.10.7 on 208, not only 208's
    /// one line, because that whole version is what the App Store parent gets.
    /// It widens WHAT is shown, never WHEN (`shouldShow` still asks for a build
    /// this install has not opened yet).
    private static var versionFloor: Int {
        (releases.filter { $0.version == currentVersion }.map(\.build).min() ?? (currentBuild + 1)) - 1
    }

    static var unseenItems: [Item] { unseenReleases.flatMap(\.items) }

    /// Everything the version in hand brought, newest build first — what the
    /// sheet shows when it is opened again by hand.
    static var thisVersionItems: [Item] {
        releases.filter { $0.version == currentVersion && $0.build <= currentBuild }.flatMap(\.items)
    }

    /// Real parents should see the notes once per RELEASE, not on every internal
    /// upload. Testers need the opposite. Both fall out of the same list: on the
    /// App Store a release is one entry, on TestFlight it is many.
    @MainActor
    static var shouldShow: Bool {
        guard UserDefaults.standard.string(forKey: seenKey) != nil else {
            UserDefaults.standard.set(seenToken, forKey: seenKey)   // fresh install → just record
            return false
        }
        // Only on a build this install has not opened yet — the version floor
        // above widens the content, and must not bring the sheet back daily.
        guard (seenBuild ?? 0) < currentBuild else { return false }
        return !unseenItems.isEmpty
    }

    @MainActor
    static func markShown() {
        UserDefaults.standard.set(seenToken, forKey: seenKey)
    }
}
