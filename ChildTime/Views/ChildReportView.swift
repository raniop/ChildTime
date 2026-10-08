import SwiftUI
import StoreKit

/// The parent's report on ONE child: is my kid using it, actually learning,
/// strong where / struggling where, and what can I do. Rani: a parent should
/// understand the child's state in a few seconds — this is not an analytics
/// console. No stars, diamonds, hearts or flames here; those belong to the kid.
///
/// Everything shown is derived on-device from the child's own `dailyStats`
/// (`InsightsEngine` + `ChildReport.swift`). No third party ever sees it.
struct ChildReportView: View {
    let profile: Profile
    let snapshot: ProgressSnapshot
    /// Seconds left in an OPEN play window (0 = none) and which pocket pays for it.
    let liveSecondsLeft: Int
    let liveIsGift: Bool
    let devices: [ChildDevice]

    /// The page's live banner + quick actions (gift / lock / chores), owned by
    /// the dashboard — it holds the remote commands, sheets and alerts. Shown
    /// right under the name, above the numbers.
    var topActions: AnyView? = nil
    // Parent actions, owned by the dashboard (it holds the sheets and alerts).
    let onAddDevice: () -> Void
    let onRemoveDevice: (ChildDevice) -> Void

    @EnvironmentObject private var settings: ParentSettings
    @ObservedObject private var historyStore = LearningHistoryStore.shared
    @State private var period: ReportPeriod = .today
    @State private var expandedTopic: Topic? = nil
    @State private var autoCollapsed = false
    @State private var isRefreshing = false
    @Environment(\.requestReview) private var requestReview

    private var engine: InsightsEngine {
        InsightsEngine(history: historyStore.history(for: profile.id),
                       profile: LearningProfile(snapshot: snapshot,
                                                enabledTopics: profile.playableTopics,
                                                age: profile.age))
    }
    private var isGirl: Bool { profile.gender == .girl }
    private func g(_ m: String, _ f: String) -> String { isGirl ? f : m }

    var body: some View {
        VStack(spacing: 14) {
            header
            let insight = engine.dailyInsight(name: profile.name, isGirl: isGirl, period: period, minutesToday: snapshot.minutesEarnedToday)
            let tip = parentTip
            if insight != nil || tip != nil {
                insightCard(insight, tip: tip)
            }
            topicsCard
            worldsCard
            improvementCard
            learningTrendCard
            screenTimeCard
            masteryCards
            devicesCard
        }
        .environment(\.layoutDirection, .app)
        .task(id: profile.id) {
            // The parent's phone never recorded this child's play — pull the
            // history down so week/month and the trends are real, not empty.
            isRefreshing = true
            await historyStore.fetchRemoteHistory(for: profile.id)
            isRefreshing = false
            // A report full of real learning is the moment to ask the parent
            // for a rating (parent device only — this view is parent-side).
            if ReviewPrompter.shouldAsk(history: historyStore.history(for: profile.id),
                                        totalAnswered: snapshot.totalAnswered) {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                ReviewPrompter.markAsked()
                requestReview()
            }
        }
    }

    // MARK: - Header: snapshot + period

    private var header: some View {
        let s = engine.summary(period)
        let cap = profile.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled,
                                           globalMax: settings.maxMinutesPerDay)
        let minutes = period == .today
            ? (cap.enabled ? "\(snapshot.minutesEarnedToday)/\(cap.minutes)" : "\(snapshot.minutesEarnedToday)")
            : "\(s.minutesEarned)"
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProfileAvatarView(profile: profile, size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    // "כיתה ג׳ · משחק עכשיו באייפד" — grade, then where the window is open.
                    HStack(spacing: 6) {
                        Text(Profile.gradeNameForParent(profile.effectiveGrade))
                        if liveSecondsLeft > 0 {
                            Text("·")
                            LivePulseDot()
                            let kind = devices.first?.kind ?? ""
                            Text(tr("\(g(tr("מְשַׂחֵק"), tr("מְשַׂחֶקֶת"))) עַכְשָׁיו") + (kind == "ipad" ? tr(" בָּאַיְפֵּד") : kind == "iphone" ? tr(" בָּאַיְפוֹן") : ""))
                        }
                    }
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
                }
                Spacer()
                if isRefreshing { ProgressView().tint(.white) }
            }
            if let topActions { topActions }
            // The four numbers that answer "is my kid using it and learning?"
            HStack(spacing: 0) {
                snap("\(s.questions)", tr("שְׁאֵלוֹת"))
                snap(s.questions > 0 ? pct(s.accuracy) : "0%", tr("הַצְלָחָה"))
                snap(minutes, tr("דַּקּוֹת"))   // minutes EARNED, not the wallet — see the dashboard note
                snap("\(snapshot.dayStreak)", snapshot.dayStreak == 1 ? tr("יוֹם רֶצֶף") : tr("יְמֵי רֶצֶף"))   // "1 ימי רצף" read wrong
            }
            .padding(.vertical, 10)
            .glassPane(radius: 16, shadow: false)
            // Period filter — drives every card below.
            HStack(spacing: 4) {
                ForEach(ReportPeriod.allCases) { p in
                    Button {
                        Haptic.light()
                        withAnimation(.easeInOut(duration: 0.2)) { period = p; expandedTopic = nil }
                    } label: {
                        Text(p.title)
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(period == p ? Color.white.opacity(0.92) : .clear,
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .foregroundStyle(period == p ? AppColor.dreamyIndigo : .white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .glassPane(radius: 12, shadow: false)
        }
    }

    private func snap(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insight

    /// The coaching engine's top concrete tip for the parent — what the old
    /// child card showed as a separate "המלצות להורה" box, now the insight
    /// card's second line. Period-independent, so it rides along every tab.
    private var parentTip: CoachingEngine.RecommendedAction? {
        guard snapshot.totalAnswered >= 4 else { return nil }
        let lp = LearningProfile(snapshot: snapshot, enabledTopics: profile.playableTopics, age: profile.age)
        return CoachingEngine(childName: profile.name, insights: engine, profile: lp, isGirl: isGirl)
            .recommendedActions().first
    }

    private func insightCard(_ i: DailyInsight?, tip: CoachingEngine.RecommendedAction?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(period == .today ? tr("💡 תּוֹבְנַת הַיּוֹם") : period == .week ? tr("💡 תּוֹבְנַת הַשָּׁבוּעַ") : tr("💡 תּוֹבְנַת הַחֹדֶשׁ"))
                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
            if let i {
                Text(i.body)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                if let rec = i.recommendation {
                    Divider().overlay(Color.white.opacity(0.35))
                    Text(tr("מֻמְלָץ: \(rec)"))
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let tip, tip.text != i?.recommendation {
                if i != nil, i?.recommendation == nil { Divider().overlay(Color.white.opacity(0.35)) }
                Text("\(tip.emoji) \(tip.text)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(GlassInk.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        // The one WARM pane on the page (mockup `.insight`): gold glass so it leads the eye.
        .background(LinearGradient(colors: [Color(hex: "FFE082").opacity(0.66), Color(hex: "FFB840").opacity(0.52)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color(hex: "FFEBAA").opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
    }

    // MARK: - Topics

    // MARK: - 🏆 Worlds (tiers)

    /// The child's worlds by how far they got: tier, room, and a couple they
    /// never visited (where to nudge next). Reads the synced snapshot, so it
    /// is right on the parent's phone too.
    private var worldsCard: some View {
        let stageOf: (World) -> Int = { w in
            min(ProgressStore.championStage, max(snapshot.worldStage[w.id] ?? 0, snapshot.worldProgress[w.id] ?? 0))
        }
        let visited: (World) -> Bool = { w in snapshot.worldStage[w.id] != nil || (snapshot.worldProgress[w.id] ?? 0) > 0 }
        let candidates = Worlds.all.filter { !$0.isBonusWorld && profile.playableTopics.contains($0.topic) }
        let played = candidates.filter(visited).sorted { stageOf($0) > stageOf($1) }
        let notYet = Array(candidates.filter { !visited($0) }.prefix(2))
        let crowns = played.reduce(0) { $0 + min(stageOf($1) / 10, ProgressStore.worldTierCount) }
        return card(tr("🏆 הָעוֹלָמוֹת שֶׁל \(profile.name)"),
                    detail: crowns > 0 ? tr("👑 דַּרְגּוֹת שֶׁהֻשְׁלְמוּ: \(crowns)") : nil) {
            if played.isEmpty {
                empty(g(tr("עוֹד לֹא שִׂחֵק בְּאַף עוֹלָם."), tr("עוֹד לֹא שִׂחֲקָה בְּאַף עוֹלָם.")))
            } else {
                VStack(spacing: 0) {
                    ForEach(played) { w in
                        let st = stageOf(w)
                        worldRow(w, label: WorldTiers.parentLabel(tier: st / 10, room: st % 10),
                                 tint: WorldTiers.color(tier: st / 10))
                    }
                    ForEach(notYet) { w in
                        worldRow(w, label: g(tr("עוֹד לֹא בִּקֵּר"), tr("עוֹד לֹא בִּקְּרָה")), tint: nil)
                    }
                }
            }
        }
    }

    private func worldRow(_ w: World, label: String, tint: Color?) -> some View {
        HStack(spacing: 10) {
            Text(w.emoji).font(.system(size: 20))
            Text(w.name)
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                .lineLimit(2).minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(tint == nil ? GlassInk.secondary : Color(hex: "2A1D00"))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(tint ?? .white.opacity(0.18)))
        }
        .padding(.vertical, 8)
    }

    private var topicsCard: some View {
        let topics = engine.topicReports(period)
        return card(tr("בִּיצוּעִים לִימוּדִיִּים"), detail: tr("לְפִי נוֹשֵׂא, \(period.title.lowercased())")) {
            if topics.isEmpty {
                empty(tr("עוֹד לֹא נַעֲנוּ שְׁאֵלוֹת \(period.title.lowercased())."))
            } else {
                // The weakest topic opens on its own (the mockup shows math's
                // sub-skills right there); any row toggles on tap.
                let weakest = topics.reversed().first(where: { $0.verdict == .weak && !engine.skillReports($0.topic, period).isEmpty })
                    ?? topics.first(where: { $0.verdict == .weak })
                let open = expandedTopic ?? (autoCollapsed ? nil : weakest?.topic)
                VStack(spacing: 0) {
                    learningProfileLines
                    ForEach(topics) { t in
                        topicRow(t, open: open == t.topic)
                        if open == t.topic {
                            let skills = engine.skillReports(t.topic, period)
                            if skills.isEmpty {
                                Text(tr("אֵין עֲדַיִן פֵּרוּט לְפִי מְיֻמָּנוּת בְּנוֹשֵׂא זֶה."))
                                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(GlassInk.secondary)
                                    .padding(.vertical, 6)
                            } else {
                                ForEach(skills) { sk in
                                    HStack {
                                        Text(sk.name)
                                        Spacer()
                                        Text(pct(sk.accuracy))
                                            .fontWeight(.heavy).monospacedDigit()
                                            .foregroundStyle(sk.accuracy >= 0.65 ? GlassInk.good : GlassInk.weak)
                                    }
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .padding(.vertical, 8).padding(.horizontal, 10)
                                    .glassInset(radius: 11)
                                    .padding(.leading, 44).padding(.top, 6)
                                }
                            }
                        }
                        if t.id != topics.last?.id { Divider().overlay(Color.white.opacity(0.16)).padding(.vertical, 8) }
                    }
                }
            }
        }
    }

    private func topicRow(_ t: TopicReport, open: Bool) -> some View {
        Button {
            Haptic.light()
            withAnimation(.easeInOut(duration: 0.2)) {
                if open { expandedTopic = nil; autoCollapsed = true } else { expandedTopic = t.topic }
            }
        } label: {
            HStack(spacing: 10) {
                Text(t.topic.emoji).font(.system(size: 22)).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(t.topic.displayName)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .layoutPriority(1)
                        difficultyTag(t.topic)
                    }
                    // One count per string, so each takes its own singular ("שאלה אחת · נכונה
                    // אחת" — the two-count string read "1 שאלות · 1 נכונות").
                    Text(tr("\(t.answered) שְׁאֵלוֹת") + " · " + tr("\(t.correct) נְכוֹנוֹת") + (t.wrong > 0 ? tr(" · \(t.wrong) טְעֻיּוֹת") : ""))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary).monospacedDigit()
                }
                Spacer()
                verdictPill(t)
            }
            .foregroundStyle(GlassInk.primary)
        }
        .buttonStyle(.plain)
    }

    /// "חֲזָקָה בְּ… / אוֹהֶבֶת…" — what the Smart Feed has learned about this
    /// child (the old card's "פרופיל למידה"), above the topic rows.
    @ViewBuilder private var learningProfileLines: some View {
        let lp = LearningProfile(snapshot: snapshot, enabledTopics: profile.playableTopics, age: profile.age)
        let strong = Array(lp.strong.prefix(3))
        let favorites = Array(lp.favorites.prefix(3))
        if snapshot.totalAnswered >= 4, !strong.isEmpty || !favorites.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !strong.isEmpty { chipLine("💪 " + g(tr("חָזָק בְּ"), tr("חֲזָקָה בְּ")), strong) }
                if !favorites.isEmpty { chipLine("❤️ " + g(tr("אוֹהֵב"), tr("אוֹהֶבֶת")), favorites) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
            Divider().overlay(Color.white.opacity(0.16)).padding(.bottom, 8)
        }
    }

    /// A label and as many topic chips as fit on one line.
    private func chipLine(_ label: String, _ topics: [Topic]) -> some View {
        ViewThatFits(in: .horizontal) {
            ForEach((1...max(topics.count, 1)).reversed(), id: \.self) { n in
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .fixedSize()
                    ForEach(topics.prefix(n)) { t in
                        Text("\(t.emoji) \(t.displayName)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .fixedSize()
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.white.opacity(0.14), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// The level the adaptive engine serves in this topic now ("קַל"), plus
    /// "↓ בּוֹנֶה בִּטָּחוֹן" / "↑ מְאַתְגֵּר יוֹתֵר" when it moved away from the
    /// parent's base (the old card's "רמת קושי חכמה", per row).
    @ViewBuilder private func difficultyTag(_ topic: Topic) -> some View {
        if AdaptiveTopicLevel.hasSignal(snapshot) {
            let st = AdaptiveTopicLevel.state(for: topic, profile: profile, snapshot: snapshot)
            let hint: String? = st.direction.map { $0 == .eased ? "↓ " + tr("בּוֹנֶה בִּטָּחוֹן") : "↑ " + tr("מְאַתְגֵּר יוֹתֵר") }
            Text(st.served.displayName + (hint.map { " · " + $0 } ?? ""))
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .foregroundStyle(st.direction == .eased ? GlassInk.warn : st.direction == .raised ? GlassInk.good : GlassInk.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.white.opacity(0.10), in: Capsule())
        }
    }

    private func verdictPill(_ t: TopicReport) -> some View {
        let (label, color): (String, Color) = {
            switch t.verdict {
            case .strong: return (t.accuracy >= 0.95 ? tr("חָזָק מְאוֹד") : tr("חָזָק"), verdictColor(.strong))
            case .ok:     return (tr("בְּסֵדֶר"), verdictColor(.ok))
            case .weak:   return (tr("דּוֹרֵשׁ חִזּוּק"), verdictColor(.weak))
            case .tooFew: return (tr("עוֹד מְעַט"), GlassInk.tertiary)
            }
        }()
        return Text("\(pct(t.accuracy)) · \(label)")
            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Color.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }

    private func verdictColor(_ v: TopicReport.Verdict) -> Color {
        switch v {
        case .strong: return GlassInk.good
        case .ok:     return GlassInk.warn
        case .weak:   return GlassInk.weak
        case .tooFew: return GlassInk.tertiary
        }
    }

    // MARK: - Improvement

    @ViewBuilder private var improvementCard: some View {
        let deltas = engine.topicDeltas(period)
        let overall = engine.overallDelta(period)
        if period != .today, overall != nil || !deltas.isEmpty {
            card(tr("הַאִם \(profile.name) \(g(tr("מִשְׁתַּפֵּר"), tr("מִשְׁתַּפֶּרֶת")))?")) {
                VStack(alignment: .leading, spacing: 8) {
                    if let o = overall {
                        let up = o >= 0
                        Text(tr("\(up ? "📈" : "📉") \(up ? g(tr("הִשְׁתַּפֵּר"), tr("הִשְׁתַּפְּרָה")) : tr("יָרַד קְצָת")) בְּ-\(Int(abs(o).rounded()))%"))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(up ? GlassInk.good : GlassInk.weak)
                    }
                    HStack(spacing: 16) {
                        if let best = deltas.first, best.deltaPoints > 0 {
                            trendChip(tr("הַשִּׁפּוּר הַגָּדוֹל"), best.topic.displayName, best.deltaPoints)
                        }
                        if let worst = deltas.last, worst.deltaPoints < 0 {
                            trendChip(tr("דּוֹרֵשׁ חִזּוּק"), worst.topic.displayName, worst.deltaPoints)
                        }
                    }
                }
            }
        }
    }

    private func trendChip(_ label: String, _ topic: String, _ delta: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(GlassInk.secondary)
            HStack(spacing: 4) {
                Text(topic).font(.system(size: 13.5, weight: .heavy, design: .rounded))
                Text("\(delta >= 0 ? "↑" : "↓")\(Int(abs(delta).rounded()))%")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded)).monospacedDigit()
                    .foregroundStyle(delta >= 0 ? GlassInk.good : GlassInk.weak)
            }
        }
    }

    // MARK: - Charts

    private var chartDays: Int { period == .month ? 30 : 7 }

    private var learningTrendCard: some View {
        let points = engine.dayPoints(days: chartDays)
        return card(tr("מְגַמַּת לְמִידָה"), detail: tr("\(chartDays) יָמִים אַחֲרוֹנִים")) {
            if points.allSatisfy({ $0.questions == 0 }) {
                empty(tr("אֵין עֲדַיִן פְּעִילוּת בַּתְּקוּפָה הַזּוֹ."))
            } else {
                LearningTrendChart(points: points)
                    .frame(height: 130)
                legend([(tr("שְׁאֵלוֹת"), Color.white.opacity(0.4)), (tr("אֲחוּז הַצְלָחָה"), .white)])
            }
        }
    }

    private var screenTimeCard: some View {
        let points = engine.dayPoints(days: chartDays)
        return card(tr("זְמַן מָסָךְ"), detail: tr("\(g(tr("הִרְוִיחַ"), tr("הִרְוִיחָה"))) מוּל \(g(tr("נִצֵּל"), tr("נִצְּלָה")))")) {
            if points.allSatisfy({ $0.earned == 0 && $0.used == 0 }) {
                empty(tr("עוֹד לֹא נִפְתַּח זְמַן מָסָךְ בַּתְּקוּפָה הַזּוֹ."))
            } else {
                ScreenTimeChart(points: points)
                    .frame(height: 120)
                legend([(g(tr("הִרְוִיחַ"), tr("הִרְוִיחָה")), Color.white.opacity(0.4)), (g(tr("נִצֵּל"), tr("נִצְּלָה")), Color(hex: "7CF3FF"))])
            }
        }
    }

    private func legend(_ items: [(String, Color)]) -> some View {
        HStack(spacing: 14) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(items[i].1).frame(width: 10, height: 10)
                    Text(items[i].0)
                }
            }
        }
        .font(.system(size: 11.5, weight: .medium, design: .rounded))
        .foregroundStyle(GlassInk.secondary)
        .padding(.top, 4)
    }

    // MARK: - Mastered / practise

    @ViewBuilder private var masteryCards: some View {
        let done = engine.mastered(period)
        let todo = engine.toPractice(period)
        if !done.isEmpty || !todo.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                card(tr("✅ כְּבָר \(g(tr("שׁוֹלֵט"), tr("שׁוֹלֶטֶת")))")) {
                    if done.isEmpty { empty(tr("עוֹד לֹא — בְּקָרוֹב 😊")) }
                    else { list(done) }
                }
                card(tr("🎯 כְּדַאי לְתַרְגֵּל")) {
                    if todo.isEmpty { empty(tr("שׁוּם דָּבָר בּוֹלֵט 👏")) }
                    else { list(todo) }
                }
            }
        }
    }

    private func list(_ items: [(name: String, detail: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 1) {
                    Text(items[i].name).font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text(items[i].detail).font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6).padding(.horizontal, 9)
                .glassInset(radius: 10)
            }
        }
    }

    // MARK: - Devices

    private var devicesCard: some View {
        card(tr("הַמַּכְשִׁירִים שֶׁל \(profile.name)")) {
            VStack(spacing: 0) {
                ForEach(devices) { d in
                    HStack {
                        // Remove (e.g. linked to the wrong child) — the dashboard
                        // confirms before anything happens.
                        Menu {
                            Button(role: .destructive) { onRemoveDevice(d) } label: {
                                Label(tr("הסר מכשיר"), systemImage: "minus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(GlassInk.secondary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // "אייפד של נועה" — the kind + the child (iOS names every phone
                        // just "iPhone"); a custom device name rides along.
                        Text(tr("\(d.kind == "ipad" ? "📲" : "📱") \(d.kind == "ipad" ? tr("אַיְפֵּד") : tr("אַיְפוֹן")) שֶׁל \(profile.name)")
                             + ([tr("אייפד"), tr("אייפון"), "iPhone", "iPad", ""].contains(d.name) ? "" : " · \(d.name)"))
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        Spacer()
                        deviceStatus(d)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, d.shieldAuthorized == false ? 2 : 8)
                    // This is the device list a parent actually opens — the
                    // dashboard row that first got the warning is not shown on
                    // this path, so the green "● מחובר" was all they saw.
                    if d.shieldAuthorized == false, d.role != "parent" {
                        Label(tr("אֵין הַרְשָׁאַת ״זְמַן מָסָךְ״ בַּמַּכְשִׁיר הַזֶּה — נְעִילַת אַפְּלִיקַצְיוֹת לֹא תַּעֲבוֹד בּוֹ. פִּתְחוּ בּוֹ אֶת טוֹפִי ← ⚙️ ← בַּקָּשׁ הַרְשָׁאָה."),
                              systemImage: "exclamationmark.shield.fill")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColor.flameOrange)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)
                    }
                    // 🔒 The migration nudge. Screen Time is granted and apps are
                    // locked, but the allow-list is empty, so the device is still
                    // on the enumerated block-list and anything the child installs
                    // stays open. Only the parent can fix it (Apple's picker needs
                    // a human), and only on the child's device — so say exactly
                    // where to tap. Older devices report nil: say nothing then
                    // rather than cry wolf.
                    if d.newAppsLocked == false, d.shieldAuthorized != false, d.role != "parent" {
                        Label(tr("אפליקציה חדשה שהילד מתקין לא נעולה במכשיר הזה. פתחו בו את טופי ← ⚙️ ← ״לנעול גם אפליקציות חדשות״ ובחרו מה נשאר פתוח."),
                              systemImage: "lock.open.trianglebadge.exclamationmark")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)
                    }
                    if d.id != devices.last?.id { Divider().overlay(Color.white.opacity(0.16)) }
                }
                if devices.isEmpty {
                    empty(tr("עוֹד לֹא חֻבַּר מַכְשִׁיר."))
                }
                Button(action: onAddDevice) {
                    Label(devices.isEmpty ? tr("+ חַבְּרוּ מַכְשִׁיר") : tr("+ חִבּוּר מַכְשִׁיר נוֹסָף"), systemImage: "qrcode")
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(Color.white.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }

    private func deviceStatus(_ d: ChildDevice) -> some View {
        let live = liveSecondsLeft > 0
        let recent = Date().timeIntervalSince(d.lastSeenAt) < 120
        return Group {
            if live && recent {
                Text(tr("● \(g(tr("מְשַׂחֵק"), tr("מְשַׂחֶקֶת"))) עַכְשָׁיו")).foregroundStyle(GlassInk.good)
            } else if recent {
                Text(tr("● מְחֻבָּר")).foregroundStyle(GlassInk.good)
            } else {
                Text(tr("נִרְאָה \(relative(d.lastSeenAt))")).foregroundStyle(GlassInk.secondary)
            }
        }
        .font(.system(size: 12, weight: .heavy, design: .rounded))
    }

    // MARK: - Building blocks

    private func card<Content: View>(_ title: String, detail: String? = nil,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded))
                Spacer()
                if let detail {
                    Text(detail).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(GlassInk.secondary)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .foregroundStyle(GlassInk.primary)
        .glassPane(radius: 22)
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(GlassInk.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pct(_ x: Double) -> String { "\(Int((x * 100).rounded()))%" }
    private func mmss(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func relative(_ d: Date) -> String {
        let m = Int(Date().timeIntervalSince(d) / 60)
        if m < 60 { return tr("לִפְנֵי \(max(1, m)) דַּק׳") }
        if m < 60 * 24 { return tr("לִפְנֵי \(m / 60) שָׁע׳") }
        return tr("לִפְנֵי \(m / (60 * 24)) יָמִים")
    }
}

// MARK: - Charts (drawn to scale, no library)

/// Bars = questions per day; line = accuracy. Two scales, both real: bars to
/// the busiest day, the line to 0…100%.
struct LearningTrendChart: View {
    let points: [InsightsEngine.DayPoint]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let labelH: CGFloat = 18, topPad: CGFloat = 8, axisW: CGFloat = 36
            let plotH = h - labelH - topPad
            let plotX0 = axisW, plotW = w - 2 * axisW
            let n = max(points.count, 1)
            let slot = plotW / CGFloat(n)
            let barW = min(22, slot * 0.55)
            let maxQ = max(points.map(\.questions).max() ?? 1, 1)
            let xAt: (Int) -> CGFloat = { i in plotX0 + slot * (CGFloat(i) + 0.5) }
            ZStack(alignment: .topLeading) {
                // grid at 50 / 75 / 100 % with the numbers on the axes (Rani:
                // "להוסיף מספרים על הצירים") — % on one side, questions on the other.
                ForEach([0.5, 0.75, 1.0], id: \.self) { f in
                    let y = topPad + plotH * (1 - f)
                    Path { p in p.move(to: CGPoint(x: plotX0, y: y)); p.addLine(to: CGPoint(x: plotX0 + plotW, y: y)) }
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    Text("\(Int(f * 100))%")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(GlassInk.primary)
                        .position(x: w - axisW / 2, y: y)
                    Text("\(Int((Double(maxQ) * f).rounded()))")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(GlassInk.secondary)
                        .position(x: axisW / 2, y: y)
                }
                Text(tr("שְׁאֵלוֹת")).font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary).position(x: axisW / 2, y: topPad + plotH + labelH / 2)
                Text(tr("הַצְלָחָה")).font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.primary).position(x: w - axisW / 2, y: topPad + plotH + labelH / 2)
                // bars
                ForEach(points.indices, id: \.self) { i in
                    let p = points[i]
                    let bh = plotH * CGFloat(p.questions) / CGFloat(maxQ)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.30))
                        .frame(width: barW, height: max(bh, p.questions > 0 ? 3 : 0))
                        .position(x: xAt(i), y: topPad + plotH - bh / 2)
                }
                // accuracy line over days that have answers
                let active = points.indices.filter { points[$0].questions > 0 }
                if active.count >= 2 {
                    Path { path in
                        for (k, i) in active.enumerated() {
                            let pt = CGPoint(x: xAt(i), y: topPad + plotH * (1 - CGFloat(points[i].accuracy)))
                            k == 0 ? path.move(to: pt) : path.addLine(to: pt)
                        }
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                if let last = active.last {
                    let pt = CGPoint(x: xAt(last), y: topPad + plotH * (1 - CGFloat(points[last].accuracy)))
                    Circle().fill(Color.white.opacity(0.25)).frame(width: 16, height: 16).position(pt)
                    Circle().fill(Color.white).frame(width: 8, height: 8).position(pt)
                    Text("\(Int((points[last].accuracy * 100).rounded()))%")
                        .font(.system(size: 10, weight: .heavy, design: .rounded)).monospacedDigit()
                        .foregroundStyle(GlassInk.primary)
                        .position(x: xAt(last), y: max(8, pt.y - 14))
                }
                // weekday labels (only every ~4th on a 30-day view)
                ForEach(points.indices, id: \.self) { i in
                    if points.count <= 7 || i % 4 == 3 || i == points.count - 1 {
                        Text(points[i].weekday)
                            .font(.system(size: 9.5, weight: i == points.count - 1 ? .heavy : .medium, design: .rounded))
                            .foregroundStyle(i == points.count - 1 ? GlassInk.primary : GlassInk.secondary)
                            .position(x: xAt(i), y: h - labelH / 2)
                    }
                }
            }
        }
        .accessibilityLabel(tr("שְׁאֵלוֹת וַאֲחוּז הַצְלָחָה לְכָל יוֹם"))
    }
}

/// Paired bars per day: minutes earned vs minutes actually used, one scale.
struct ScreenTimeChart: View {
    let points: [InsightsEngine.DayPoint]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let labelH: CGFloat = 18, topPad: CGFloat = 8, axisW: CGFloat = 36
            let plotH = h - labelH - topPad
            let plotX0 = axisW, plotW = w - axisW
            let n = max(points.count, 1)
            let slot = plotW / CGFloat(n)
            let barW = min(11, slot * 0.28)
            let maxM = max(points.map { max($0.earned, $0.used) }.max() ?? 1, 1)
            let xAt: (Int) -> CGFloat = { i in plotX0 + slot * (CGFloat(i) + 0.5) }
            ZStack(alignment: .topLeading) {
                ForEach([0.0, 0.5, 1.0], id: \.self) { f in
                    let y = topPad + plotH * (1 - f)
                    if f > 0 {
                        Path { p in p.move(to: CGPoint(x: plotX0, y: y)); p.addLine(to: CGPoint(x: w, y: y)) }
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
                    // minutes on the axis (this side is the visual LEFT under RTL)
                    Text("\(Int((Double(maxM) * f).rounded()))")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(GlassInk.primary)
                        .position(x: axisW / 2, y: y)
                }
                Text(tr("דַּקּוֹת")).font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary).position(x: axisW / 2, y: h - labelH / 2)
                ForEach(points.indices, id: \.self) { i in
                    let p = points[i]
                    let cx = xAt(i)
                    let eh = plotH * CGFloat(p.earned) / CGFloat(maxM)
                    let uh = plotH * CGFloat(p.used) / CGFloat(maxM)
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.white.opacity(0.38))
                        .frame(width: barW, height: max(eh, p.earned > 0 ? 3 : 0))
                        .position(x: cx - barW * 0.6, y: topPad + plotH - eh / 2)
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color(hex: "7CF3FF"))
                        .frame(width: barW, height: max(uh, p.used > 0 ? 3 : 0))
                        .position(x: cx + barW * 0.6, y: topPad + plotH - uh / 2)
                    if points.count <= 7 || i % 4 == 3 || i == points.count - 1 {
                        Text(p.weekday)
                            .font(.system(size: 9.5, weight: i == points.count - 1 ? .heavy : .medium, design: .rounded))
                            .foregroundStyle(i == points.count - 1 ? GlassInk.primary : GlassInk.secondary)
                            .position(x: cx, y: h - labelH / 2)
                    }
                }
            }
        }
        .accessibilityLabel(tr("דַּקּוֹת שֶׁהוּרְוְחוּ וְדַקּוֹת שֶׁנֻּצְּלוּ לְכָל יוֹם"))
    }
}
