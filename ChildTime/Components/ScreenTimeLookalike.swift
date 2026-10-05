import SwiftUI

/// 👀 "איך זה נראה באייפון?" — a drawing of Apple's own Settings → זמן מסך page,
/// with a gold ring around exactly the rows to touch and what to do there.
///
/// Rani: "אולי שווה לשים איזה כפתור קטן שמציג בדיוק את הכפתורים האלה — צריך
/// להתייחס לאנשים כאילו אין להם מושג איך עושים כל דבר!". The labels are
/// Apple's, letter for letter as the iPhone shows them (from Rani's screenshot),
/// and the page is drawn in Apple's light grouped style rather than Tofy's, so
/// it looks like the place the parent is about to go — not like Tofy.
///
/// It is a picture, not a link: Apple offers no public way to open that page.
struct ScreenTimeLookalikeRow: Identifiable {
    let id: String
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    /// What to do here — the row gets the gold ring when set.
    var note: String? = nil
}

struct ScreenTimeLookalikeView: View {
    let title: String
    let sections: [(header: String, rows: [ScreenTimeLookalikeRow])]
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "F2F2F7").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "6B6B70"))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)

                    // The page's own title bar, as the iPhone draws it.
                    Text(tr("זמן מסך"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)

                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.header)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color(hex: "6B6B70"))
                                .padding(.horizontal, 6)
                            VStack(spacing: 0) {
                                ForEach(Array(section.rows.enumerated()), id: \.element.id) { i, row in
                                    rowView(row)
                                    if i < section.rows.count - 1 {
                                        Rectangle().fill(Color(hex: "E3E3E8")).frame(height: 1)
                                            .padding(.leading, 18).padding(.trailing, 64)
                                    }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
                        }
                    }

                    Button(action: onClose) {
                        Text(tr("הֵבַנְתִּי"))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color(hex: "6C4CF1")))
                    }
                    .buttonStyle(.juicy)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .app)
    }

    private func rowView(_ row: ScreenTimeLookalikeRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Image(systemName: row.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(row.tint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.black)
                    if !row.subtitle.isEmpty {
                        Text(row.subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "6B6B70"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: AppSymbol.forwardChevron)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "C4C4C7"))
            }
            if let note = row.note {
                Text("👆 " + note)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AppColor.starGold))
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
}

/// The two pages a Tofy parent is sent to, as data.
enum ScreenTimeLookalikes {
    /// Settings → זמן מסך, the "הגבלות שימוש" block — Downtime, App Limits,
    /// Always Allowed (and Screen Distance, untouched, so the page looks real).
    static var usageLimits: [(header: String, rows: [ScreenTimeLookalikeRow])] {
        [(header: tr("הגבלות שימוש"), rows: [
            .init(id: "downtime", symbol: "moon.zzz.fill", tint: Color(hex: "5E5CE6"),
                  title: tr("השבתה"), subtitle: tr("כבויה"),
                  note: tr("לִבְדֹּק שֶׁכָּתוּב \"כבויה\"")),
            .init(id: "limits", symbol: "hourglass", tint: Color(hex: "FF9500"),
                  title: tr("הגבלות יישומים"), subtitle: tr("קביעת הגבלת זמן ליישומים"),
                  note: tr("לְמַחֹק כָּל הַגְבָּלָה שֶׁיֵּשׁ שָׁם")),
            .init(id: "always", symbol: "checkmark.seal.fill", tint: Color(hex: "34C759"),
                  title: tr("אישור קבוע"), subtitle: tr("בחירת יישומים שיאושרו תמיד"),
                  note: tr("לְהַשְׁאִיר רַק מָה שֶׁחַיָּב לִהְיוֹת פָּתוּחַ")),
            .init(id: "distance", symbol: "chevron.up.2", tint: Color(hex: "0A84FF"),
                  title: tr("מרחק מהמסך"), subtitle: tr("הפחתת מאמץ העיניים")),
        ])]
    }
}
