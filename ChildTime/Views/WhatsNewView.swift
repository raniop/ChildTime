import SwiftUI

/// ✨ "מה חדש" — a once-per-update popup on the PARENT dashboard (Rani: every
/// release should tell parents what's new, in simple friendly Hebrew).
///
/// How it works: `items(for:)` maps the CURRENT build number to its release
/// notes. On dashboard appear, if this build hasn't been shown yet (and it's
/// not a fresh install), the sheet pops once and the build is marked seen.
///
/// ⚠️ RELEASE CHECKLIST: when bumping CURRENT_PROJECT_VERSION, add a case here
/// with that build's highlights — otherwise the popup silently skips.
enum WhatsNewContent {
    struct Item: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let line: String
    }

    static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Release notes per build. Builds without an entry show nothing.
    static func items(for build: String) -> [Item]? {
        switch build {
        case "133":
            return [
                Item(emoji: "🧹", title: "מטלות הבית",
                     line: "הילדים עוזרים בבית ובוחרים פרס — דקות משחק או כסף לקופה. אתם מאשרים (אפשר ישר מההתראה, עם תמונה!)"),
                Item(emoji: "⌚️", title: "טופי על ה-Apple Watch",
                     line: "מבט מהיר על המשפחה מהיד, והתראות מטלה עם תמונת ההוכחה"),
                Item(emoji: "🎓", title: "שאלות מותאמות לכיתה",
                     line: "כל שאלה באפליקציה מתויגת עכשיו לפי תוכנית הלימודים — כל ילד מקבל בדיוק את הרמה שלו"),
                Item(emoji: "🎒", title: "חגיגת שנה חדשה",
                     line: "מסך חגיגי לילדים ולכם לכבוד העלייה כיתה"),
                Item(emoji: "🧩", title: "ווידג'טים משודרגים",
                     line: "מטלות וקופת כסף בווידג'טים, ווידג'טים חדשים למסך הנעילה, ועדכון חי"),
                Item(emoji: "💪", title: "ותיקוני באגים רבים",
                     line: "מתנות שמגיעות תמיד, התראות ברורות יותר, ועוד המון ליטושים"),
            ]
        default:
            return nil
        }
    }

    private static let seenKey = "whatsNew.shownForBuild"

    /// Show once per build — and never on a fresh install (nothing is "new").
    @MainActor
    static var shouldShow: Bool {
        let d = UserDefaults.standard
        guard let seen = d.string(forKey: seenKey) else {
            d.set(currentBuild, forKey: seenKey)   // fresh install → just record
            return false
        }
        return seen != currentBuild && items(for: currentBuild) != nil
    }

    @MainActor
    static func markShown() {
        UserDefaults.standard.set(currentBuild, forKey: seenKey)
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
                }
                .padding(.top, 28)
                .padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(WhatsNewContent.items(for: WhatsNewContent.currentBuild) ?? []) { item in
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
