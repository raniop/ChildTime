import SwiftUI

/// 👀 "איך זה נראה באייפון?" — drawings of Apple's own Settings pages, one
/// after another, with a gold ring around exactly the row to touch and what to
/// do there.
///
/// Rani: "צריך להתייחס לאנשים כאילו אין להם מושג איך עושים כל דבר!". Every
/// label is Apple's, letter for letter — Hebrew from Rani's screenshots of a
/// Hebrew iPhone (Apple's own ” quotes included), English from his English one
/// — and the pages are drawn in Apple's light grouped style, not Tofy's, so
/// they look like the place the parent is about to go.
///
/// A picture, not a link: Apple offers no public way to open these pages.
struct ScreenTimeLookalikeRow: Identifiable {
    enum Kind {
        /// An icon, a title (and a subtitle), and a chevron.
        case nav(symbol: String, tint: Color)
        /// An app row with an on/off switch ("טופי" under the apps with access).
        case appToggle
        /// A plain switch row ("הכללת נתוני אתרים").
        case toggle
        /// A blue or red text button ("שינוי קוד הגישה…").
        case action(Color)
    }
    let id: String
    let kind: Kind
    let title: String
    var subtitle: String = ""
    /// What to do here — the row gets the gold ring when set.
    var note: String? = nil
}

struct ScreenTimeLookalikePage: Identifiable {
    let id: String
    /// Above the drawing: which step this is, and how to get here.
    let caption: String
    /// The page's own title bar, as the iPhone shows it.
    let title: String
    let sections: [(header: String, rows: [ScreenTimeLookalikeRow])]
}

struct ScreenTimeLookalikeView: View {
    let pages: [ScreenTimeLookalikePage]
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "F2F2F7").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(pages) { page in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(page.caption)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(hex: "2A1E5C"))
                                .fixedSize(horizontal: false, vertical: true)
                            pageView(page)
                        }
                    }
                    Text(ScreenTimeLookalikes.notInFamilyNote)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "3A3A3C"))
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onClose) {
                        Text(tr("הֵבַנְתִּי"))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "6C4CF1")))
                    }
                    .buttonStyle(.juicy)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .app)
    }

    /// One iPhone page: its title bar, then its grouped sections.
    private func pageView(_ page: ScreenTimeLookalikePage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(page.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            ForEach(Array(page.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 8) {
                    if !section.header.isEmpty {
                        Text(section.header)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Color(hex: "6B6B70"))
                            .padding(.horizontal, 6)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(section.rows.enumerated()), id: \.element.id) { i, row in
                            rowView(row)
                            if i < section.rows.count - 1 {
                                Rectangle().fill(Color(hex: "E3E3E8")).frame(height: 1)
                                    .padding(.leading, 18).padding(.trailing, 64)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "F2F2F7")))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: "D1D1D6"), lineWidth: 1.5))
    }

    private func rowView(_ row: ScreenTimeLookalikeRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                switch row.kind {
                case .nav(let symbol, let tint):
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint))
                    titles(row)
                    Spacer(minLength: 0)
                    Image(systemName: AppSymbol.forwardChevron)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "C4C4C7"))
                case .appToggle:
                    Image("LaunchLogo")
                        .resizable().scaledToFill()
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "B39DFF")))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    titles(row)
                    Spacer(minLength: 0)
                    fakeSwitch
                case .toggle:
                    titles(row)
                    Spacer(minLength: 0)
                    fakeSwitch
                case .action(let color):
                    Text(row.title)
                        .font(.system(size: 17))
                        .foregroundStyle(color)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            if let note = row.note {
                Text("👆 " + note)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColor.starGold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay {
            if row.note != nil {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColor.starGold, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    .padding(3)
            }
        }
    }

    private func titles(_ row: ScreenTimeLookalikeRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.title)
                .font(.system(size: 17))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
            if !row.subtitle.isEmpty {
                Text(row.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "6B6B70"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Apple's green switch, drawn — on.
    private var fakeSwitch: some View {
        Capsule().fill(Color(hex: "34C759"))
            .frame(width: 52, height: 32)
            .overlay(alignment: .trailing) {
                Circle().fill(.white).frame(width: 28, height: 28).padding(2)
            }
            .environment(\.layoutDirection, .leftToRight)
    }
}

/// The pages a Tofy parent is sent to, as data. `child` is the child's name as
/// Apple shows it in the list (Settings → זמן מסך → the child).
enum ScreenTimeLookalikes {
    private static var childName: String {
        Question.stripNiqqud(ProfileStore.shared.active?.name ?? tr("הילד"))
    }

    /// The "הגבלות" block at the bottom of the child's Screen Time page.
    private static func restrictions(note manage: String?) -> (header: String, rows: [ScreenTimeLookalikeRow]) {
        (header: tr("הגבלות"), rows: [
            .init(id: "content", kind: .nav(symbol: "nosign", tint: Color(hex: "FF3B30")),
                  title: tr("הגבלת תוכן ופרטיות"), subtitle: tr("ניהול תכנים, יישומים והגדרות")),
            .init(id: "manage", kind: .nav(symbol: "lock.fill", tint: Color(hex: "0A84FF")),
                  title: tr("ניהול ”זמן מסך”"), subtitle: tr("פעיל"), note: manage),
        ])
    }

    /// "Downtime / App Limits / Always Allowed" at the top of the same page.
    private static var usageLimits: (header: String, rows: [ScreenTimeLookalikeRow]) {
        (header: tr("הגבלות שימוש"), rows: [
            .init(id: "downtime", kind: .nav(symbol: "moon.zzz.fill", tint: Color(hex: "5E5CE6")),
                  title: tr("השבתה"), subtitle: tr("כבויה"),
                  note: tr("לִבְדֹּק שֶׁכָּתוּב \"כבויה\"")),
            .init(id: "limits", kind: .nav(symbol: "hourglass", tint: Color(hex: "FF9500")),
                  title: tr("הגבלות יישומים"), subtitle: tr("קביעת הגבלת זמן ליישומים"),
                  note: tr("לְמַחֹק כָּל הַגְבָּלָה שֶׁיֵּשׁ שָׁם")),
            .init(id: "always", kind: .nav(symbol: "checkmark.seal.fill", tint: Color(hex: "34C759")),
                  title: tr("אישור קבוע"), subtitle: tr("בחירת יישומים שיאושרו תמיד"),
                  note: tr("לְהַשְׁאִיר רַק מָה שֶׁחַיָּב לִהְיוֹת פָּתוּחַ")),
        ])
    }

    /// The whole setup walk-through: the passcode first (the one that matters),
    /// then the limits that would fight Tofy's.
    static var setup: [ScreenTimeLookalikePage] {
        [
            .init(id: "p1",
                  caption: tr("1 · בַּטֶּלֶפוֹן שֶׁמְּנַהֵל אֶת הַיֶּלֶד (בְּדֶרֶךְ כְּלָל שֶׁלָּכֶם): הגדרות ← זמן מסך ← \(childName), וְגוֹלְלִים לְמַטָּה:"),
                  title: childName,
                  sections: [restrictions(note: tr("נִכְנָסִים לְכָאן"))]),
            .init(id: "p2",
                  caption: tr("2 · בְּתוֹךְ ניהול ”זמן מסך”:"),
                  title: tr("ניהול ”זמן מסך”"),
                  sections: [
                    (header: "", rows: [.init(id: "web", kind: .toggle, title: tr("הכללת נתוני אתרים"))]),
                    (header: "", rows: [.init(id: "code", kind: .action(Color(hex: "0A84FF")),
                                              title: tr("שינוי קוד הגישה עבור ”זמן מסך”"),
                                              note: tr("כָּאן מַגְדִּירִים קוֹד — וְשׁוֹמְרִים אוֹתוֹ רַק לָכֶם"))]),
                    (header: "", rows: [.init(id: "off", kind: .action(Color(hex: "FF3B30")),
                                              title: tr("כיבוי ”פעילות ביישומים ואתרים”"))]),
                  ]),
            .init(id: "p3",
                  caption: tr("3 · וּבְאוֹתוֹ דַּף שֶׁל \(childName), לְמַעְלָה:"),
                  title: childName,
                  sections: [usageLimits]),
        ]
    }

    /// The child is not in Family Sharing — their own iPhone manages itself.
    static var notInFamilyNote: String {
        tr("הַיֶּלֶד לֹא מְנֻהָל מֵהַטֶּלֶפוֹן שֶׁלָּכֶם? אוֹתָם דְּבָרִים, בַּטֶּלֶפוֹן שֶׁלּוֹ: הגדרות ← זמן מסך — וְאֶת הַקּוֹד מַגְדִּירִים בְּתַחְתִּית אוֹתוֹ דַּף.")
    }

    /// Deleting Tofy: switch off its Screen Time access, then delete.
    static var deletion: [ScreenTimeLookalikePage] {
        [
            .init(id: "d1",
                  caption: tr("בַּטֶּלֶפוֹן שֶׁמְּנַהֵל אֶת הַיֶּלֶד: הגדרות ← זמן מסך ← \(childName), וְגוֹלְלִים עַד לְמַטָּה:"),
                  title: childName,
                  sections: [
                    restrictions(note: nil),
                    (header: tr("יישומים עם גישה אל ”זמן מסך”"),
                     rows: [.init(id: "tofy", kind: .appToggle, title: tr("טופי"),
                                  note: tr("לְכַבּוֹת — וְאָז מוֹחֲקִים אֶת טוֹפִי כָּרָגִיל"))]),
                  ]),
        ]
    }
}
