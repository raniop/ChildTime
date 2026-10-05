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

    /// The passcode FIRST — Rani: "אנחנו חייבים להסביר להורה שהוא חייב לשים
    /// סיסמא". Without it, the same Settings page that a parent uses to remove
    /// Tofy lets a child switch Tofy off and open everything.
    ///
    /// Two paths, because there are two kinds of family: a child managed from
    /// the parent's own iPhone (Family Sharing — Dan, on Rani's phone), and a
    /// child whose iPhone manages itself. Labels in ” ” are Apple's own, from
    /// Rani's screenshots of a Hebrew iPhone.
    static var steps: [Step] {
        [
            Step(id: 1, title: tr("הַכִּי חָשׁוּב: קוֹד לְ”זמן מסך”"),
                 detail: tr("בְּלִי קוֹד, הַיֶּלֶד יָכוֹל לְכַבּוֹת אֶת טוֹפִי בַּהַגְדָּרוֹת — וְהַכֹּל נִפְתָּח. אֵיפֹה מַגְדִּירִים? בַּכַּפְתּוֹר \"אֵיךְ זֶה נִרְאֶה בָּאַיְפוֹן?\" לְמַטָּה, צַעַד אַחַר צַעַד.")),
            // The labels in quotes are Apple's OWN, letter for letter as the
            // iPhone shows them — no niqqud, so a parent can find them by eye.
            Step(id: 2, title: tr("כַּבּוּ \"השבתה\" וְ\"הגבלות יישומים\""),
                 detail: tr("טוֹפִי עוֹשֶׂה אֶת זֶה עַכְשָׁו — שְׁתֵּי נְעִילוֹת מִתְנַגְּשׁוֹת.")),
            Step(id: 3, title: tr("בְּ\"אישור קבוע\" — רַק מָה שֶׁחַיָּב לִהְיוֹת פָּתוּחַ"),
                 detail: tr("אַפְּלִיקַצְיָה שֶׁנִּמְצֵאת שָׁם, טוֹפִי לֹא יָכוֹל לִנְעֹל.")),
        ]
    }
}

/// 👀 "איך זה נראה באייפון?" — opens the drawing of Apple's page.
struct ScreenTimeShowMeButton: View {
    var pages: [ScreenTimeLookalikePage] = ScreenTimeLookalikes.setup
    @State private var showing = false

    var body: some View {
        Button {
            Haptic.light()
            showing = true
        } label: {
            Label(tr("אֵיךְ זֶה נִרְאֶה בָּאַיְפוֹן?"), systemImage: "eye.fill")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.juicy)
        .sheet(isPresented: $showing) {
            ScreenTimeLookalikeView(pages: pages) { showing = false }
        }
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
                    Text(tr("טוֹפִי מְנַהֵל עַכְשָׁו אֶת הַנְּעִילָה. שְׁלוֹשָׁה דְּבָרִים בְּ\"זמן מסך\" שֶׁל אַפֶּל:"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    AppleScreenTimeStepsList(steps: AppleScreenTimeTips.steps)
                        .padding(16)
                        .glassPane(radius: 20)

                    // A picture of Apple's page — in-app, so allowed on a child's device.
                    ScreenTimeShowMeButton()

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
