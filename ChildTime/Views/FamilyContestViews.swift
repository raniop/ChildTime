import SwiftUI

// 🏆 The weekly family contest — the screens (Rani approved the mockups,
// 2026-10-24: reports/family-week-entry-cards.png, family-week-real-numbers.png).
// The child's copy carries niqqud; the parent's does not.

// MARK: - Kid home card

/// On the child's home, above the worlds: the jar alive in a card. When last
/// week just ended it turns gold and opens on the celebration.
struct FamilyContestKidCard: View {
    @ObservedObject private var store = FamilyContestStore.shared
    @ObservedObject private var history = LearningHistoryStore.shared
    @State private var open = false

    var body: some View {
        Group {
            if store.isActive, let me = store.me {
                Button { Haptic.light(); open = true } label: { card(me) }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $open) {
                        FamilyContestView(parent: false)
                            .presentationDragIndicator(.visible)
                    }
            }
        }
        .task { await store.refresh() }
        .onReceive(history.$days) { _ in store.recompute(); Task { await store.refresh() } }
    }

    private func card(_ me: FamilyContestStore.Row) -> some View {
        let girl = me.profile.gender == .girl
        let leader = store.champions.contains(me.id)
        return HStack(spacing: 14) {
            FamilyJar(fill: store.fillFraction, stages: store.stageFractions)
                .frame(width: 62, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("🏆 תַּחֲרוּת הַשָּׁבוּעַ"))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                if store.celebration != nil {
                    Text(tr("הַשָּׁבוּעַ נִגְמַר! לְחִיצָה לַתּוֹצָאוֹת 🎉"))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                } else {
                    Text(store.nextLine(parent: false))
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                    Text((girl ? tr("עָשִׂית \(me.standing.done) מִתּוֹךְ \(me.standing.goal) 🚀")
                               : tr("עָשִׂיתָ \(me.standing.done) מִתּוֹךְ \(me.standing.goal) 🚀")) + (leader ? " 👑" : ""))
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            Image(systemName: AppSymbol.forwardChevron).font(.system(size: 14, weight: .bold)).foregroundStyle(GlassInk.secondary)
        }
        .foregroundStyle(GlassInk.primary)
        .padding(14)
        .glassPane(radius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(store.celebration != nil ? AppColor.starGold : .clear, lineWidth: 2))
        .contentShape(Rectangle())
    }
}

// MARK: - Parent home card

/// On the parent's home, above the children: the jar and where each child is.
struct FamilyContestParentCard: View {
    @ObservedObject private var store = FamilyContestStore.shared
    @State private var open = false

    var body: some View {
        Group {
            if store.isActive {
                Button { Haptic.light(); open = true } label: { card }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $open) {
                        FamilyContestView(parent: true)
                            .presentationDragIndicator(.visible)
                    }
            }
        }
        .task { await store.refresh() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                FamilyJar(fill: store.fillFraction, stages: store.stageFractions)
                    .frame(width: 56, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tr("🏆 תחרות השבוע")).font(.system(size: 18, weight: .heavy, design: .rounded))
                        Spacer()
                        Text(store.daysLeftLine(parent: true))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.secondary)
                    }
                    Text(tr("צנצנת המשפחה: \(store.filled) מתוך \(store.target)"))
                        .font(.system(size: 14, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(store.nextLine(parent: true))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            HStack(spacing: 8) {
                ForEach(store.rows) { row in
                    HStack(spacing: 8) {
                        ProfileAvatarView(profile: row.profile, size: 30)
                            .overlay(alignment: .top) {
                                if store.champions.contains(row.id) { Text(verbatim: "👑").font(.system(size: 14)).offset(y: -11) }
                            }
                        Text(Question.stripNiqqud(row.profile.name)).font(.system(size: 14, weight: .heavy, design: .rounded))
                        Text(verbatim: "\(row.standing.percent)%")
                            .font(.system(size: 14, weight: .black, design: .rounded)).monospacedDigit()
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 8).frame(height: 40).frame(maxWidth: .infinity)
                    .background(Color.white.opacity(store.champions.contains(row.id) ? 0.2 : 0.1),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            Text(store.single ? tr("הילד מול השבוע שעבר שלו, ואתם מוסיפים לצנצנת משימות משפחתיות")
                              : tr("כל ילד מול היעד שלו, לפי מה שעשה בשבועות הקודמים"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
        }
        .foregroundStyle(GlassInk.primary)
        .padding(14)
        .glassPane(radius: 16)
        .contentShape(Rectangle())
    }
}

// MARK: - The full screen

struct FamilyContestView: View {
    let parent: Bool
    @ObservedObject private var store = FamilyContestStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCelebration = false
    @State private var sendingTask = false

    private let jarW: CGFloat = 140, jarH: CGFloat = 210, lidH: CGFloat = 18

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.2), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(parent ? tr("סגירה") : tr("סְגִירָה"))
                }
                .clearOfBar()
                VStack(spacing: 4) {
                    Text(verbatim: "🏆").font(.system(size: 46))
                    Text(parent ? tr("תחרות השבוע") : tr("תַּחֲרוּת הַשָּׁבוּעַ"))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text(store.daysLeftLine(parent: parent))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
                jarCard
                if store.single { selfRaceCard } else { raceCard }
                if parent && store.single { familyTasksCard }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
            .foregroundStyle(GlassInk.primary)
        }
        .background(GlassBackdrop().ignoresSafeArea())
        .environment(\.layoutDirection, .app)
        .task { await store.refresh(force: true) }
        .onAppear { if !parent && store.celebration != nil { showCelebration = true } }
        .fullScreenCover(isPresented: $showCelebration, onDismiss: { store.celebration = nil }) {
            if let c = store.celebration { FamilyContestCelebrationView(celebration: c) }
        }
    }

    // 🫙
    private var jarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(parent ? tr("🫙 צנצנת המשפחה") : tr("🫙 צִנְצֶנֶת הַמִּשְׁפָּחָה"))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                Spacer()
                Text(verbatim: "\(store.filled)/\(store.target)")
                    .font(.system(size: 22, weight: .black, design: .rounded)).monospacedDigit()
                    .environment(\.layoutDirection, .leftToRight)
            }
            Text(explainLine)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 0) {
                FamilyJar(fill: store.fillFraction, stages: store.stageFractions)
                    .frame(width: jarW, height: jarH)
                GeometryReader { g in
                    ForEach(Array(store.stages.enumerated()), id: \.offset) { i, at in
                        let f = store.target > 0 ? CGFloat(at) / CGFloat(store.target) : 0
                        prizeTag(i, at)
                            .frame(width: g.size.width, alignment: .leading)
                            .position(x: g.size.width / 2, y: lidH + (jarH - lidH) * (1 - f * FamilyJar.headroom))
                    }
                }
                .frame(height: jarH)
            }
            Text(store.nextLine(parent: parent))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPane(radius: 16)
    }

    private var explainLine: String {
        switch (parent, store.single) {
        case (true, false): return tr("כל תשובה נכונה של כל אחד מהילדים ממלאת את הצנצנת. בכל קו, כל הילדים מקבלים דקות 🎁")
        case (true, true): return tr("כל תשובה נכונה ממלאת את הצנצנת, וגם אתם מוסיפים לה משימות משפחתיות. בכל קו הילד מקבל דקות 🎁")
        case (false, false): return tr("כָּל תְּשׁוּבָה נְכוֹנָה שֶׁל כָּל אֶחָד מִכֶּם מְמַלֵּאת אֶת הַצִּנְצֶנֶת. כְּשֶׁהִיא מַגִּיעָה לְקַו, כֻּלָּם מְקַבְּלִים דַּקּוֹת 🎁")
        case (false, true): return tr("כָּל תְּשׁוּבָה נְכוֹנָה מְמַלֵּאת אֶת הַצִּנְצֶנֶת, וְגַם אַבָּא וְאִמָּא מוֹסִיפִים לָהּ. כְּשֶׁהִיא מַגִּיעָה לְקַו, מְקַבְּלִים דַּקּוֹת 🎁")
        }
    }

    /// ─── 🎁 20 דקות לכולם · ב־800 — the dashes continue the line on the glass.
    private func prizeTag(_ i: Int, _ at: Int) -> some View {
        let done = store.filled >= at && at > 0
        let next = !done && (i == 0 || store.filled >= store.stages[i - 1])
        let minutes = FamilyContest.stagePrizes[min(i, 2)]
        let tint = next ? Color(hex: "FFD66B") : Color.white.opacity(done ? 0.55 : 0.85)
        let title: String = {
            switch (parent, store.single) {
            case (true, false): return tr("\(minutes) דקות לכולם")
            case (true, true): return tr("\(minutes) דקות")
            case (false, false): return tr("\(minutes) דַּקּוֹת לְכֻלָּם")
            case (false, true): return tr("\(minutes) דַּקּוֹת")
            }
        }()
        let sub = done ? (parent ? tr("הושג 🎉") : tr("הִשַּׂגְנוּ! 🎉"))
                       : (parent ? tr("ב־\(at) תשובות") : tr("בְּ־\(at) תְּשׁוּבוֹת"))
        return HStack(spacing: 0) {
            Path { p in p.move(to: CGPoint(x: 0, y: 1)); p.addLine(to: CGPoint(x: 22, y: 1)) }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .frame(width: 22, height: 2)
            HStack(spacing: 6) {
                Text(verbatim: done ? "✅" : "🎁").font(.system(size: 16))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    Text(sub).font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary).monospacedDigit()
                }
                .lineLimit(1).minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(next ? Color(hex: "FFD66B").opacity(0.28) : Color.white.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(next ? Color(hex: "FFD66B") : .clear, lineWidth: 1.5))
        }
        .opacity(done ? 0.8 : 1)
    }

    // 👑 Siblings, each against their own goal.
    private var raceCard: some View {
        let meID = parent ? nil : store.me?.id
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(parent ? tr("👑 אלוף השבוע") : tr("👑 אַלּוּף הַשָּׁבוּעַ"))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                Spacer()
                Text(parent ? tr("כל ילד מול היעד שלו") : tr("כָּל אֶחָד מוּל הַיַּעַד שֶׁלּוֹ"))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
            }
            ForEach(store.rows) { row in
                let lead = store.champions.contains(row.id)
                HStack(spacing: 12) {
                    ProfileAvatarView(profile: row.profile, size: 46)
                        .overlay(alignment: .top) { if lead { Text(verbatim: "👑").font(.system(size: 22)).offset(y: -18) } }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(parent ? Question.stripNiqqud(row.profile.name) : row.profile.name)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                            if row.id == meID {
                                Text(row.profile.gender == .girl ? tr("(אַתְּ)") : tr("(אַתָּה)"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(GlassInk.secondary)
                            }
                            Spacer()
                            if parent {
                                Text(tr("\(row.standing.done) מתוך \(row.standing.goal)"))
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(GlassInk.secondary).monospacedDigit()
                            }
                            Text(verbatim: "\(row.standing.percent)%")
                                .font(.system(size: 16, weight: .black, design: .rounded)).monospacedDigit()
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        bar(row.standing.fraction, gold: lead)
                    }
                }
                .padding(.vertical, 4)
            }
            if let me = store.me, !parent {
                Divider().overlay(Color.white.opacity(0.2))
                Text(goalLine(me))
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(parent ? tr("מי שמגיע ליעד מקבל \(FamilyContest.goalPrize) דקות, והאלוף עוד \(FamilyContest.championPrize) 🎁")
                        : tr("כָּל מִי שֶׁמַּגִּיעַ לַיַּעַד מְקַבֵּל \(FamilyContest.goalPrize) דַּקּוֹת, וְהָאַלּוּף מְקַבֵּל עוֹד \(FamilyContest.championPrize) 🎁"))
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPane(radius: 16)
    }

    // 🔁 One child: this week against last week.
    private var selfRaceCard: some View {
        let row = store.rows.first
        let girl = row?.profile.gender == .girl
        let now = row?.standing.done ?? 0
        let last = row.flatMap { store.lastWeekDone[$0.id] } ?? 0
        let top = max(now, last, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text(parent ? tr("🔁 מול השבוע שעבר") : (girl ? tr("🔁 אַתְּ מוּל הַשָּׁבוּעַ שֶׁעָבַר") : tr("🔁 אַתָּה מוּל הַשָּׁבוּעַ שֶׁעָבַר")))
                .font(.system(size: 19, weight: .heavy, design: .rounded))
            ForEach(0..<2, id: \.self) { i in
                let value = i == 0 ? now : last
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(i == 0 ? (parent ? tr("השבוע") : tr("הַשָּׁבוּעַ")) : (parent ? tr("שבוע שעבר") : tr("שָׁבוּעַ שֶׁעָבַר")))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                        Spacer()
                        Text(verbatim: "\(value)").font(.system(size: 16, weight: .black, design: .rounded)).monospacedDigit()
                    }
                    bar(Double(value) / Double(top), gold: i == 0 && now > last)
                }
            }
            if let me = row, !parent {
                Text(goalLine(me))
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(parent ? tr("עובר את השבוע שעבר: כתר ועוד \(FamilyContest.championPrize) דקות. מגיע ליעד: עוד \(FamilyContest.goalPrize) 🎁")
                        : tr("מִי שֶׁעוֹבֵר אֶת הַשָּׁבוּעַ שֶׁעָבַר מְקַבֵּל כֶּתֶר 👑 וְעוֹד \(FamilyContest.championPrize) דַּקּוֹת"))
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassPane(radius: 16)
    }

    // ➕ Parents add to a one-child jar.
    private var familyTasksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("➕ משימה משפחתית")).font(.system(size: 19, weight: .heavy, design: .rounded))
            Text(tr("עשיתם משהו יחד? כל משימה מוסיפה \(FamilyContest.boostPerTask) לצנצנת"))
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
            ForEach([tr("📖 קראנו יחד"), tr("🧹 עזרה בבית"), tr("🎲 שיחקנו משחק")], id: \.self) { label in
                Button {
                    guard !sendingTask, let id = store.rows.first?.id else { return }
                    sendingTask = true
                    Task {
                        if await store.addFamilyTask(for: id) { Haptic.success() } else { Haptic.warning() }
                        sendingTask = false
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.juicy)
                .disabled(sendingTask)
            }
        }
        .padding(16)
        .glassPane(radius: 16)
    }

    private func goalLine(_ me: FamilyContestStore.Row) -> String {
        let girl = me.profile.gender == .girl
        if me.standing.reachedGoal { return girl ? tr("הִגַּעְתְּ לַיַּעַד שֶׁלָּךְ! 🎯") : tr("הִגַּעְתָּ לַיַּעַד שֶׁלְּךָ! 🎯") }
        return girl ? tr("הַיַּעַד שֶׁלָּךְ הַשָּׁבוּעַ: \(me.standing.goal) תְּשׁוּבוֹת נְכוֹנוֹת. כְּבָר עָשִׂית \(me.standing.done) 🚀")
                    : tr("הַיַּעַד שֶׁלְּךָ הַשָּׁבוּעַ: \(me.standing.goal) תְּשׁוּבוֹת נְכוֹנוֹת. כְּבָר עָשִׂיתָ \(me.standing.done) 🚀")
    }

    private func bar(_ f: Double, gold: Bool) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.18))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gold ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color(hex: "7CF3FF")))
                    .frame(width: g.size.width * CGFloat(min(1, max(0, f))))
            }
        }
        .frame(height: 10)
    }
}

// MARK: - The week's end

struct FamilyContestCelebrationView: View {
    let celebration: FamilyContestStore.Celebration
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = FamilyContestStore.shared

    private var me: Profile? { ProfileStore.shared.profiles.first { $0.id == ProgressVault.shared.boundProfileID } }
    private var girl: Bool { me?.gender == .girl }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)
            Text(tr("הַשָּׁבוּעַ נִגְמַר! 🎉"))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            if let hero = heroProfile {
                ProfileAvatarView(profile: hero, size: 130)
                    .overlay(alignment: .top) {
                        if celebration.iWasChampion || !celebration.championIDs.isEmpty {
                            Text(verbatim: "👑").font(.system(size: 56)).offset(y: -44)
                        }
                    }
                    .padding(.top, 30)
            }
            Text(headline)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppGradient.gold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            VStack(spacing: 10) {
                if celebration.jarFull {
                    row("🫙", tr("הַצִּנְצֶנֶת הִתְמַלְּאָה!"))
                }
                if celebration.reachedGoal {
                    row("🎯", girl ? tr("הִגַּעְתְּ לַיַּעַד שֶׁלָּךְ!") : tr("הִגַּעְתָּ לַיַּעַד שֶׁלְּךָ!"))
                }
            }
            .padding(.horizontal, 16)
            Spacer()
            Text(celebration.minutes > 0
                 ? (girl ? tr("בְּסוֹף הַשָּׁבוּעַ קִבַּלְתְּ עוֹד \(celebration.minutes) דַּקּוֹת 🎁")
                         : tr("בְּסוֹף הַשָּׁבוּעַ קִבַּלְתָּ עוֹד \(celebration.minutes) דַּקּוֹת 🎁"))
                 : tr("בַּשָּׁבוּעַ הַחָדָשׁ מְמַלְּאִים שׁוּב 💪"))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Button { Haptic.success(); dismiss() } label: {
                Text(tr("אֵיזֶה כֵּיף!"))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "3A2700"))
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.juicy)
            .padding(.horizontal, 16)
            Text(tr("תַּחֲרוּת חֲדָשָׁה כְּבָר הִתְחִילָה 🚀"))
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .padding(.bottom, 10)
        }
        .foregroundStyle(GlassInk.primary)
        .background(GlassBackdrop().ignoresSafeArea())
        .environment(\.layoutDirection, .app)
    }

    private var champions: [Profile] {
        ProfileStore.shared.profiles.filter { celebration.championIDs.contains($0.id) }
    }

    private var heroProfile: Profile? { celebration.iWasChampion ? me : (champions.first ?? me) }

    private var headline: String {
        if celebration.single {
            if celebration.iWasChampion { return girl ? tr("שָׁבַרְתְּ אֶת הַשִּׂיא שֶׁלָּךְ! 🏆") : tr("שָׁבַרְתָּ אֶת הַשִּׂיא שֶׁלְּךָ! 🏆") }
            return tr("שָׁבוּעַ שֶׁל לְמִידָה! 💪")
        }
        if celebration.iWasChampion {
            return girl ? tr("אַתְּ אַלּוּפַת הַשָּׁבוּעַ!") : tr("אַתָּה אַלּוּף הַשָּׁבוּעַ!")
        }
        guard let c = champions.first else { return tr("שָׁבוּעַ שֶׁל לְמִידָה! 💪") }
        if champions.count > 1 {
            return tr("\(champions.map(\.name).joined(separator: ", ")) אַלּוּפֵי הַשָּׁבוּעַ!")
        }
        return c.gender == .girl ? tr("\(c.name) אַלּוּפַת הַשָּׁבוּעַ!") : tr("\(c.name) אַלּוּף הַשָּׁבוּעַ!")
    }

    private func row(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: icon).font(.system(size: 30))
            Text(title).font(.system(size: 16, weight: .heavy, design: .rounded))
            Spacer()
        }
        .padding(14)
        .glassPane(radius: 16)
    }
}
