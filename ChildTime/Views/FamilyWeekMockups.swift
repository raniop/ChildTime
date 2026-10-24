#if DEBUG
import SwiftUI

/// 🏆 Mockups for the weekly sibling contest (Rani, 2026-10-24: "תחרויות
/// שבועיות… בוא נתחיל קודם כל בין הילדים"). Two screens, as the child sees
/// them: mid-week (the family jar + the champion race, each against their own
/// goal) and the Saturday-night celebration. Hebrew only, not wired to data.
///   DEMO_SCREEN=familyweek · DEMO_SCREEN=familyweekend
struct FamilyWeekMockup: View {
    private let kids: [(Profile, Int)] = [
        (Profile(name: "נוֹעָה", gender: .girl, character3DID: "bunny"), 74),
        (Profile(name: "דָּן", gender: .boy, character3DID: "penguin"), 65),
        (Profile(name: "יוֹאָב", gender: .boy, character3DID: "fox"), 40),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text(verbatim: "🏆").font(.system(size: 50))
                    Text(verbatim: "תַּחֲרוּת הַשָּׁבוּעַ")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text(verbatim: "נִשְׁאֲרוּ 3 יָמִים ⏳")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
                .padding(.top, 8)

                jarCard
                raceCard
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
            .foregroundStyle(GlassInk.primary)
        }
        .background(GlassBackdrop().ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
    }

    // 🫙 Together: one jar for all the siblings.
    /// Stages on the jar (Rani, 2026-10-24: "אולי צריך לשים שלבים על הצנצנת"):
    /// every mark is a prize for everyone, so a slow week still gets somewhere.
    private let stages: [(at: Int, minutes: Int)] = [(400, 10), (800, 20), (1200, 30)]   // Rani: 10 / 20 / 30
    private let filled = 820, goal = 1200
    private let jarW: CGFloat = 140, jarH: CGFloat = 210, lidH: CGFloat = 18

    private var jarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: "🫙 צִנְצֶנֶת הַמִּשְׁפָּחָה")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                Spacer()
                Text(verbatim: "\(filled)/\(goal)")
                    .font(.system(size: 22, weight: .black, design: .rounded)).monospacedDigit()
                    .environment(\.layoutDirection, .leftToRight)
            }
            Text(verbatim: "כָּל תְּשׁוּבָה נְכוֹנָה שֶׁל כָּל אֶחָד מִכֶּם מְמַלֵּאת אֶת הַצִּנְצֶנֶת. כְּשֶׁהִיא מַגִּיעָה לְקַו, כֻּלָּם מְקַבְּלִים דַּקּוֹת 🎁")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // The jar, and each line carried out of the glass to its prize.
            HStack(alignment: .top, spacing: 0) {
                FamilyJar(fill: Double(filled) / Double(goal), stages: stages.map { Double($0.at) / Double(goal) })
                    .frame(width: jarW, height: jarH)
                GeometryReader { g in
                    ForEach(stages.indices, id: \.self) { i in
                        let st = stages[i]
                        let y = lidH + (jarH - lidH) * (1 - CGFloat(st.at) / CGFloat(goal) * FamilyJar.headroom)
                        prizeTag(st.at, st.minutes, done: filled >= st.at,
                                 next: filled < st.at && (i == 0 || filled >= stages[i - 1].at))
                            .frame(width: g.size.width, alignment: .leading)
                            .position(x: g.size.width / 2, y: y)
                    }
                }
                .frame(height: jarH)
            }
            Text(verbatim: "עוֹד 380 תְּשׁוּבוֹת נְכוֹנוֹת בְּיַחַד, וְכֻלָּם מְקַבְּלִים 30 דַּקּוֹת!")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPane(radius: 16)
    }

    /// ─── 🎁 30 דקות לכולם · 300 — the dashes continue the line on the glass.
    private func prizeTag(_ at: Int, _ minutes: Int, done: Bool, next: Bool) -> some View {
        let tint = next ? Color(hex: "FFD66B") : Color.white.opacity(done ? 0.55 : 0.85)
        return HStack(spacing: 0) {
            Path { p in p.move(to: CGPoint(x: 0, y: 1)); p.addLine(to: CGPoint(x: 22, y: 1)) }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .frame(width: 22, height: 2)
            HStack(spacing: 6) {
                Text(verbatim: done ? "✅" : "🎁").font(.system(size: 16))
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "\(minutes) דַּקּוֹת לְכֻלָּם")
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    Text(verbatim: done ? "הִשַּׂגְנוּ! 🎉" : "בְּ־\(at) תְּשׁוּבוֹת")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(next ? Color(hex: "FFD66B").opacity(0.28) : Color.white.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(next ? Color(hex: "FFD66B") : .clear, lineWidth: 1.5))
        }
        .opacity(done ? 0.8 : 1)
    }

    // 👑 Each against their own goal — the little one can win.
    private var raceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(verbatim: "👑 אַלּוּף הַשָּׁבוּעַ")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                Spacer()
                Text(verbatim: "כָּל אֶחָד מוּל הַיַּעַד שֶׁלּוֹ")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
            }
            ForEach(kids.indices, id: \.self) { i in
                let (p, pct) = kids[i]
                HStack(spacing: 12) {
                    ZStack(alignment: .top) {
                        ProfileAvatarView(profile: p, size: 46)
                        if i == 0 { Text(verbatim: "👑").font(.system(size: 22)).offset(y: -18) }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(p.name).font(.system(size: 16, weight: .heavy, design: .rounded))
                            if p.name == "דָּן" {
                                Text(verbatim: "(אַתָּה)").font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(GlassInk.secondary)
                            }
                            Spacer()
                            Text(verbatim: "\(pct)%")
                                .font(.system(size: 16, weight: .black, design: .rounded)).monospacedDigit()
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.18))
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(i == 0 ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color(hex: "7CF3FF")))
                                    .frame(width: g.size.width * CGFloat(pct) / 100)
                            }
                        }
                        .frame(height: 10)
                    }
                }
                .padding(.vertical, 4)
            }
            Divider().overlay(Color.white.opacity(0.2))
            Text(verbatim: "הַיַּעַד שֶׁלְּךָ הַשָּׁבוּעַ: 450 תְּשׁוּבוֹת נְכוֹנוֹת. כְּבָר עָשִׂיתָ 292 🚀")
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "כָּל מִי שֶׁמַּגִּיעַ לַיַּעַד מְקַבֵּל 10 דַּקּוֹת, וְהָאַלּוּף מְקַבֵּל עוֹד 20 🎁")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPane(radius: 16)
    }
}

/// 🎉 Saturday night: the crown, the jar, and what each child got.
struct FamilyWeekEndMockup: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)
            Text(verbatim: "הַשָּׁבוּעַ נִגְמַר! 🎉")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            ZStack(alignment: .top) {
                ProfileAvatarView(profile: Profile(name: "נוֹעָה", gender: .girl, character3DID: "bunny"), size: 130)
                Text(verbatim: "👑").font(.system(size: 56)).offset(y: -44)
            }
            .padding(.top, 30)
            Text(verbatim: "נוֹעָה אַלּוּפַת הַשָּׁבוּעַ!")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(AppGradient.gold)
            Text(verbatim: "הִשְׁלִימָה 92% מֵהַיַּעַד שֶׁלָּהּ וְקִבְּלָה עוֹד 20 דַּקּוֹת")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)

            VStack(spacing: 10) {
                row("🫙", "הַצִּנְצֶנֶת הִתְמַלְּאָה!", "כֻּלָּם מְקַבְּלִים 15 דַּקּוֹת")
                row("💪", "גַּם אַתָּה הִגַּעְתָּ לַיַּעַד שֶׁלְּךָ!", "קִבַּלְתָּ עוֹד 10 דַּקּוֹת")
            }
            .padding(.horizontal, 16)

            Spacer()
            Text(verbatim: "סַךְ הַכֹּל קִבַּלְתָּ הַשָּׁבוּעַ 25 דַּקּוֹת 🎁")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
            Text(verbatim: "אֵיזֶה כֵּיף!")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "3A2700"))
                .frame(maxWidth: .infinity).frame(height: 58)
                .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
            Text(verbatim: "תַּחֲרוּת חֲדָשָׁה מַתְחִילָה מָחָר בַּבֹּקֶר")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .padding(.bottom, 10)
        }
        .foregroundStyle(GlassInk.primary)
        .background(GlassBackdrop().ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func row(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: icon).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.system(size: 16, weight: .heavy, design: .rounded))
                Text(verbatim: detail).font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
            }
            Spacer()
        }
        .padding(14)
        .glassPane(radius: 16)
    }
}

#endif
