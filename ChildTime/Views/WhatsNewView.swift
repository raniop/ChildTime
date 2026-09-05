import SwiftUI

/// ✨ "מה חדש" — a once-per-update popup on the PARENT dashboard (Rani: every
/// release should tell parents what's new, in simple friendly Hebrew).
///
/// How it works: `items(for:)` maps the MARKETING version to its release notes.
/// On dashboard appear, if this version hasn't been shown yet (and it's not a
/// fresh install), the sheet pops once and the version is marked seen.
///
/// Keyed on the marketing version, NOT the build number: a release goes through
/// many internal builds, and parents should see one set of notes for the release
/// they actually received — not a popup on every TestFlight upload, and not a
/// meaningless "141".
///
/// Versions read `YYYY.M.N` — year, month, release within that month (2026.9.1).
/// It stays valid for Apple (≤3 integers), always sorts forward (2026.10 > 2026.9,
/// 2027.1 > 2026.12), and tells a parent at a glance how fresh their app is.
///
/// ⚠️ RELEASE CHECKLIST: when bumping MARKETING_VERSION, add a case here with
/// that version's highlights — otherwise the popup silently skips. Bumping only
/// CURRENT_PROJECT_VERSION (a new build of the same release) needs nothing.
enum WhatsNewContent {
    struct Item: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let line: String
    }

    /// What the parent sees, e.g. "2026.9.1". See `AppInfo` for the scheme.
    static var currentVersion: String { AppInfo.version }

    /// Release notes per marketing version. Versions without an entry show nothing.
    static func items(for version: String) -> [Item]? {
        switch version {
        case "2026.9.1":
            return [
                Item(emoji: "🔒", title: "חלון משחק אחד — בכל המכשירים יחד",
                     line: "כשהילד פותח דקות באייפון, האייפד מראה שהחלון פתוח שם ומציע להעביר אותו לכאן. אותן דקות לא נפתחות פעמיים, והמגבלה היומית נספרת פעם אחת לכל הילד"),
                Item(emoji: "🔁", title: "מעבירים את הזמן בלחיצה אחת",
                     line: "האייפד לא ייפתח עד שהאייפון באמת ננעל — ורק אז הדקות שנשארו עוברות אליו. בלי כפילויות ובלי דקות שנעלמות"),
                Item(emoji: "🔓", title: "נעילה מרחוק שתמיד עובדת",
                     line: "גם אם המכשיר של הילד כבוי או תקוע, 'נעל עכשיו (מרחוק)' סוגר את זמן המשחק — והילד יכול לפתוח מיד במכשיר השני"),
                Item(emoji: "📶", title: "עובד גם בלי אינטרנט",
                     line: "אם נפתח חלון בלי רשת, ברגע שהחיבור חוזר האפליקציה מסדרת הכול לבד — ובלי לקחת מהילד דקות שהרוויח"),
                Item(emoji: "🕐", title: "שינוי שעון כבר לא מזכה בזמן",
                     line: "הזזת השעון במכשיר לא מוסיפה דקות, לא פותחת מחדש פרסים יומיים ולא משאירה אפליקציות פתוחות"),
                Item(emoji: "🧹", title: "מסך מטלות חדש וצבעוני",
                     line: "כפתור 'עשיתי!' בצבע של הילד/ה, כתר וברכת 'אלוף/אלופה', וקטגוריה נפרדת של 'בוצעו היום'. הפרס תמיד דקות משחק"),
                Item(emoji: "📖", title: "עשרות קטעי קריאה חדשים",
                     line: "קטעי הבנת הנקרא לכל הכיתות, מותאמים לחומר הנלמד בבית הספר — עם הרבה פחות חזרות"),
                Item(emoji: "🎓", title: "שאלות מותאמות לכיתה",
                     line: "כל שאלה באפליקציה מתויגת לפי תוכנית הלימודים — כל ילד מקבל בדיוק את הרמה שלו"),
                Item(emoji: "👪", title: "מסך הורים חדש — במבט של כמה שניות",
                     line: "לכל ילד כרטיס פשוט: דקות היום מתוך המקסימום, שאלות, נכונות ואחוז הצלחה. לחיצה פותחת דוח מלא — במה הילד חזק, מה כדאי לתרגל, האם הוא משתפר, ותובנה יומית עם המלצה. בלי כוכבים ויהלומים — אלה של הילדים"),
                Item(emoji: "🎲", title: "\"הרפתקה חכמה\" נקראת עכשיו טופי טיים",
                     line: "אותו מסלול חכם שמתאים את השאלות לילד — עם שם קצר יותר וקובייה. זה החלק החינמי של טופי"),
                Item(emoji: "👑", title: "טופי+ הוא מנוי משפחתי",
                     line: "קונים פעם אחת, בטלפון של ההורה — וכל המכשירים של כל הילדים נפתחים. במכשיר של הילד אין יותר מסך תשלום: יש כפתור 'בקש מאבא או אמא', והבקשה מגיעה ישר לטלפון שלכם"),
                Item(emoji: "🪟", title: "עיצוב זכוכית חדש",
                     line: "כרטיסים שקופים־למחצה מעל הגרדיאנט של טופי — נקי, קליל וקריא"),
                Item(emoji: "🧬", title: "ההתקדמות של כל ילד נשארת שלו",
                     line: "תיקנו תקלה נדירה שבה במכשיר משותף ההתקדמות של ילד אחד יכלה להיכתב אצל אח או אחות. עכשיו זה פשוט לא אפשרי"),
                Item(emoji: "💛", title: "יציב יותר, בטוח יותר",
                     line: "המון שיפורים שקטים לשמירה על ההתקדמות, הפרטיות והפרסים של הילדים בכל המכשירים"),
            ]
        default:
            return nil
        }
    }

    // Deliberately the SAME key as when this was build-keyed: an existing install
    // holds a build number there, which can never equal a version string, so the
    // first launch after updating shows the notes exactly once — which is right.
    private static let seenKey = "whatsNew.shownForBuild"

    /// A TestFlight build carries a sandbox receipt; the App Store one does not.
    private static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// What "already seen" is measured against.
    ///
    /// Real parents should see the notes once per RELEASE — not on every internal
    /// upload, which is why this moved off the build number. But a release goes
    /// through a dozen TestFlight builds while it is being tested, and whoever is
    /// testing needs to see the sheet on each of them. So: per build on
    /// TestFlight, per version on the App Store.
    static var seenToken: String {
        isTestFlight ? "\(currentVersion) (\(AppInfo.build))" : currentVersion
    }

    /// Show once per version — and never on a fresh install (nothing is "new").
    @MainActor
    static var shouldShow: Bool {
        let d = UserDefaults.standard
        guard let seen = d.string(forKey: seenKey) else {
            d.set(seenToken, forKey: seenKey)   // fresh install → just record
            return false
        }
        return seen != seenToken && items(for: currentVersion) != nil
    }

    @MainActor
    static func markShown() {
        UserDefaults.standard.set(seenToken, forKey: seenKey)
    }
}

struct WhatsNewView: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("✨").font(.system(size: 44))
                    Text("מה חדש בטופי?")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("הנה מה שהוספנו בעדכון האחרון")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    // The version itself, so a parent can say WHICH Tofy they have.
                    Text("גרסה \(WhatsNewContent.currentVersion)")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(.white.opacity(0.15), in: Capsule())
                        .padding(.top, 4)
                }
                .padding(.top, 28)
                .padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(WhatsNewContent.items(for: WhatsNewContent.currentVersion) ?? []) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Text(item.emoji).font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(item.line)
                                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    Haptic.success()
                    onDone()
                } label: {
                    Text("מעולה, תודה! 💛")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .frame(maxWidth: 420)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: [.white, Color(hex: "FFE9A3")],
                                           startPoint: .top, endPoint: .bottom),
                            in: Capsule())
                        .glow(Color(hex: "FFD23F"), radius: 12)
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
