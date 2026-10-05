import SwiftUI

/// 🍏 What a parent needs to know about Apple's OWN Screen Time on a child's
/// device — the things Tofy cannot see or override.
///
/// Rani: "יש הרבה מצבים שהמכשיר של הילד כבר היה מוגדר עליו זמן מסך דרך אפל…
/// להדריך אותו שהוא חייב לבטל שם והכל דרך טופי עכשיו". There is no API that
/// tells an app what Apple's Screen Time is doing (Downtime, App Limits,
/// Always Allowed), so the honest thing is to say it at the right moment:
///  * once, right after the device joins (the parent is holding it) — words
///    only, no way out of the app: this sheet is on a CHILD's device and a
///    link out needs a parental gate (Kids Category, guideline 1.3);
///  * and in the parent's corner on the device, which IS behind the parent
///    code, with a button into Settings.
///
/// Apple offers no public link to the Screen Time page itself (a private
/// "prefs:" URL is a rejection), so the button opens Settings and says where
/// to go from there.
enum AppleScreenTimeTips {
    /// Set when a child device joins; the child's home shows the sheet once.
    static let pendingKey = "tips.appleScreenTime.pending"

    struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
    }

    static var steps: [Step] {
        [
            Step(id: 1, title: tr("כַּבּוּ \"זְמַן הַשְׁבָּתָה\" וּ\"מִגְבְּלוֹת יִשּׁוּמִים\""),
                 detail: tr("טוֹפִי עוֹשֶׂה אֶת זֶה עַכְשָׁו — שְׁתֵּי נְעִילוֹת מִתְנַגְּשׁוֹת.")),
            Step(id: 2, title: tr("בְּ\"אִשּׁוּר קָבוּעַ\" — רַק מָה שֶׁחַיָּב לִהְיוֹת פָּתוּחַ"),
                 detail: tr("אַפְּלִיקַצְיָה שֶׁנִּמְצֵאת שָׁם, טוֹפִי לֹא יָכוֹל לִנְעֹל.")),
            Step(id: 3, title: tr("הַגְדִּירוּ קוֹד לִזְמַן מָסָךְ"),
                 detail: tr("בְּלִי קוֹד, אֶפְשָׁר לְכַבּוֹת לְטוֹפִי אֶת הַגִּישָׁה בַּהַגְדָּרוֹת — וְהַכֹּל נִפְתָּח.")),
        ]
    }
}

/// The numbered list, shared by the sheet and the card.
struct AppleScreenTimeStepsList: View {
    let steps: [AppleScreenTimeTips.Step]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(step.id)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(AppColor.starGold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        if !step.detail.isEmpty {
                            Text(step.detail)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// Once, right after a child device joins. Words only — see the note above.
struct AppleScreenTimeTipsSheet: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("🍏").font(.system(size: 44))
                        .frame(maxWidth: .infinity)
                    Text(tr("הִגְדַּרְתֶּם בֶּעָבָר זְמַן מָסָךְ שֶׁל אַפֶּל בַּטֶּלֶפוֹן הַזֶּה?"))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tr("טוֹפִי מְנַהֵל עַכְשָׁו אֶת הַנְּעִילָה. כְּדֵי שֶׁשּׁוּם דָּבָר לֹא יִתְנַגֵּשׁ, בְּהַגְדָּרוֹת ← זְמַן מָסָךְ:"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    AppleScreenTimeStepsList(steps: AppleScreenTimeTips.steps)
                        .padding(16)
                        .glassPane(radius: 20)

                    Text(tr("אֶפְשָׁר לִמְצֹא אֶת זֶה תָּמִיד בְּהַגְדָּרוֹת הַהוֹרִים שֶׁל טוֹפִי בַּטֶּלֶפוֹן הַזֶּה."))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button {
                        Haptic.light()
                        onDone()
                    } label: {
                        Text(tr("הֵבַנְתִּי"))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "2A1E5C"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppGradient.gold, in: Capsule())
                    }
                    .buttonStyle(.juicy)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .app)
    }
}
