import SwiftUI

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

    // Parent actions, owned by the dashboard (it holds the sheets and alerts).
    let onGift: (Int) -> Void
    let onLock: () -> Void
    let onLockAndRevoke: () -> Void
    let onAddDevice: () -> Void
    let onFullInsights: () -> Void

    @EnvironmentObject private var settings: ParentSettings
    @ObservedObject private var historyStore = LearningHistoryStore.shared
    @State private var period: ReportPeriod = .today
    @State private var expandedTopic: Topic? = nil
    @State private var isRefreshing = false

    private var engine: InsightsEngine {
        InsightsEngine(history: historyStore.history(for: profile.id),
                       profile: LearningProfile(snapshot: snapshot,
                                                enabledTopics: profile.enabledTopics,
                                                age: profile.age))
    }
    private var isGirl: Bool { profile.gender == .girl }
    private func g(_ m: String, _ f: String) -> String { isGirl ? f : m }

    var body: some View {
        VStack(spacing: 14) {
            header
            if let insight = engine.dailyInsight(name: profile.name, isGirl: isGirl, period: period) {
                insightCard(insight)
            }
            topicsCard
            improvementCard
            learningTrendCard
            screenTimeCard
            masteryCards
            devicesCard
            Button(action: onFullInsights) {
                Label("תּוֹבָנוֹת מְלֵאוֹת וְסִגְנוֹן לְמִידָה", systemImage: "sparkles")
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task(id: profile.id) {
            // The parent's phone never recorded this child's play — pull the
            // history down so week/month and the trends are real, not empty.
            isRefreshing = true
            await historyStore.fetchRemoteHistory(for: profile.id)
            isRefreshing = false
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
                    HStack(spacing: 6) {
                        if liveSecondsLeft > 0 {
                            LivePulseDot()
                            Text("\(g("מְשַׂחֵק", "מְשַׂחֶקֶת")) עַכְשָׁיו · נִשְׁאֲרוּ \(mmss(liveSecondsLeft))")
                        } else {
                            Text(Profile.gradeDisplayName(profile.effectiveGrade))
                        }
                    }
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
                }
                Spacer()
                if isRefreshing { ProgressView().tint(.white) }
            }
            // The four numbers that answer "is my kid using it and learning?"
            HStack(spacing: 0) {
                snap("\(s.questions)", "שְׁאֵלוֹת")
                snap(s.questions > 0 ? pct(s.accuracy) : "—", "הַצְלָחָה")
                snap(minutes, "דַּקּוֹת")
                snap("\(snapshot.dayStreak)", "יְמֵי רֶצֶף")
            }
            .padding(.vertical, 10)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            .background(period == p ? Color.white : .clear,
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .foregroundStyle(period == p ? AppColor.dreamyIndigo : .white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func insightCard(_ i: DailyInsight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(i.emoji) \(i.title)")
                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
            Text(i.body)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            if let rec = i.recommendation {
                Divider().overlay(Color(hex: "4A3B0A").opacity(0.18))
                Text("מֻמְלָץ: \(rec)")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Color(hex: "3B2E05"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LinearGradient(colors: [Color(hex: "FFF6D9"), Color(hex: "FFEFC2")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Topics

    private var topicsCard: some View {
        let topics = engine.topicReports(period)
        return card("בִּיצוּעִים לִימוּדִיִּים", detail: "לְפִי נוֹשֵׂא, \(period.title.lowercased())") {
            if topics.isEmpty {
                empty("עוֹד לֹא נֶעֶנוּ שְׁאֵלוֹת \(period.title.lowercased()).")
            } else {
                VStack(spacing: 0) {
                    ForEach(topics) { t in
                        topicRow(t)
                        if expandedTopic == t.topic {
                            let skills = engine.skillReports(t.topic, period)
                            if skills.isEmpty {
                                Text("אֵין עֲדַיִן פֵּרוּט לְפִי מְיֻמָּנוּת בְּנוֹשֵׂא זֶה.")
                                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 6)
                            } else {
                                ForEach(skills) { sk in
                                    HStack {
                                        Text(sk.name)
                                        Spacer()
                                        Text("\(sk.correct)/\(sk.answered)")
                                            .foregroundStyle(.secondary).monospacedDigit()
                                        Text(pct(sk.accuracy))
                                            .fontWeight(.heavy).monospacedDigit()
                                            .foregroundStyle(verdictColor(sk.accuracy >= 0.85 ? .strong : sk.accuracy >= 0.65 ? .ok : .weak))
                                            .frame(minWidth: 44, alignment: .leading)
                                    }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .padding(.vertical, 7).padding(.horizontal, 10)
                                    .background(Color(.tertiarySystemGroupedBackground),
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .padding(.leading, 44).padding(.top, 4)
                                }
                            }
                        }
                        if t.id != topics.last?.id { Divider().padding(.vertical, 8) }
                    }
                }
            }
        }
    }

    private func topicRow(_ t: TopicReport) -> some View {
        Button {
            Haptic.light()
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedTopic = expandedTopic == t.topic ? nil : t.topic
            }
        } label: {
            HStack(spacing: 10) {
                Text(t.topic.emoji).font(.system(size: 22)).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.topic.displayName)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text("\(t.answered) שְׁאֵלוֹת · \(t.correct) נְכוֹנוֹת" + (t.wrong > 0 ? " · \(t.wrong) טְעֻיּוֹת" : ""))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                verdictPill(t)
                Image(systemName: expandedTopic == t.topic ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func verdictPill(_ t: TopicReport) -> some View {
        let (label, color): (String, Color) = {
            switch t.verdict {
            case .strong: return (t.accuracy >= 0.95 ? "חָזָק מְאוֹד" : "חָזָק", verdictColor(.strong))
            case .ok:     return ("בְּסֵדֶר", verdictColor(.ok))
            case .weak:   return ("דּוֹרֵשׁ חִזּוּק", verdictColor(.weak))
            case .tooFew: return ("עוֹד מְעַט", Color.secondary)
            }
        }()
        return Text("\(pct(t.accuracy)) · \(label)")
            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func verdictColor(_ v: TopicReport.Verdict) -> Color {
        switch v {
        case .strong: return Color(hex: "22A06B")
        case .ok:     return Color(hex: "9A6A00")
        case .weak:   return AppColor.flameOrange
        case .tooFew: return .secondary
        }
    }

    // MARK: - Improvement

    @ViewBuilder private var improvementCard: some View {
        let deltas = engine.topicDeltas(period)
        let overall = engine.overallDelta(period)
        if period != .today, overall != nil || !deltas.isEmpty {
            card("הַאִם \(profile.name) \(g("מִשְׁתַּפֵּר", "מִשְׁתַּפֶּרֶת"))?") {
                VStack(alignment: .leading, spacing: 8) {
                    if let o = overall {
                        let up = o >= 0
                        Text("\(up ? "📈" : "📉") \(up ? g("הִשְׁתַּפֵּר", "הִשְׁתַּפְּרָה") : "יָרַד קְצָת") בְּ-\(Int(abs(o).rounded()))% \(period == .week ? "הַשָּׁבוּעַ" : "הַחֹדֶשׁ")")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(up ? Color(hex: "22A06B") : AppColor.flameOrange)
                    }
                    HStack(spacing: 16) {
                        if let best = deltas.first, best.deltaPoints > 0 {
                            trendChip("הַשִּׁפּוּר הַגָּדוֹל", best.topic.displayName, best.deltaPoints)
                        }
                        if let worst = deltas.last, worst.deltaPoints < 0 {
                            trendChip("דּוֹרֵשׁ חִזּוּק", worst.topic.displayName, worst.deltaPoints)
                        }
                    }
                }
            }
        }
    }

    private func trendChip(_ label: String, _ topic: String, _ delta: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(topic).font(.system(size: 13.5, weight: .heavy, design: .rounded))
                Text("\(delta >= 0 ? "↑" : "↓")\(Int(abs(delta).rounded()))%")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded)).monospacedDigit()
                    .foregroundStyle(delta >= 0 ? Color(hex: "22A06B") : AppColor.flameOrange)
            }
        }
    }

    // MARK: - Charts

    private var chartDays: Int { period == .month ? 30 : 7 }

    private var learningTrendCard: some View {
        let points = engine.dayPoints(days: chartDays)
        return card("מְגַמַּת לְמִידָה", detail: "\(chartDays) יָמִים אַחֲרוֹנִים") {
            if points.allSatisfy({ $0.questions == 0 }) {
                empty("אֵין עֲדַיִן פְּעִילוּת בַּתְּקוּפָה הַזּוֹ.")
            } else {
                LearningTrendChart(points: points)
                    .frame(height: 130)
                legend([("שְׁאֵלוֹת", Color(hex: "D9D2FF")), ("אֲחוּז הַצְלָחָה", AppColor.dreamyIndigo)])
            }
        }
    }

    private var screenTimeCard: some View {
        let points = engine.dayPoints(days: chartDays)
        return card("זְמַן מָסָךְ", detail: "\(g("הִרְוִיחַ", "הִרְוִיחָה")) מוּל \(g("נִצֵּל", "נִצְּלָה"))") {
            if points.allSatisfy({ $0.earned == 0 && $0.used == 0 }) {
                empty("עוֹד לֹא נִפְתַּח זְמַן מָסָךְ בַּתְּקוּפָה הַזּוֹ.")
            } else {
                ScreenTimeChart(points: points)
                    .frame(height: 120)
                legend([(g("הִרְוִיחַ", "הִרְוִיחָה"), Color(hex: "B7ABFF")), (g("נִצֵּל", "נִצְּלָה"), AppColor.dreamyTeal)])
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
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    // MARK: - Mastered / practise

    @ViewBuilder private var masteryCards: some View {
        let done = engine.mastered(period)
        let todo = engine.toPractice(period)
        if !done.isEmpty || !todo.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                card("✅ כְּבָר \(g("שׁוֹלֵט", "שׁוֹלֶטֶת"))") {
                    if done.isEmpty { empty("עוֹד לֹא — בְּקָרוֹב 😊") }
                    else { list(done) }
                }
                card("🎯 כְּדַאי לְתַרְגֵּל") {
                    if todo.isEmpty { empty("שׁוּם דָּבָר בּוֹלֵט 👏") }
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
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6).padding(.horizontal, 9)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Devices

    private var devicesCard: some View {
        card("הַמַּכְשִׁירִים שֶׁל \(profile.name)") {
            VStack(spacing: 0) {
                ForEach(devices) { d in
                    HStack {
                        Text("\(d.kind == "ipad" ? "📲" : "📱") \(d.name)")
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        Spacer()
                        deviceStatus(d)
                    }
                    .padding(.vertical, 8)
                    if d.id != devices.last?.id { Divider() }
                }
                if devices.isEmpty {
                    empty("עוֹד לֹא חֻבַּר מַכְשִׁיר.")
                }
                Button(action: onAddDevice) {
                    Label("חַבְּרוּ מַכְשִׁיר נוֹסָף", systemImage: "qrcode")
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.dreamyIndigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(AppColor.dreamyIndigo.opacity(0.5)))
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
                Text("● \(g("מְשַׂחֵק", "מְשַׂחֶקֶת")) עַכְשָׁיו").foregroundStyle(Color(hex: "22A06B"))
            } else if recent {
                Text("● מְחֻבָּר").foregroundStyle(Color(hex: "22A06B"))
            } else {
                Text("נִרְאָה \(relative(d.lastSeenAt))").foregroundStyle(.secondary)
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
                    Text(detail).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pct(_ x: Double) -> String { "\(Int((x * 100).rounded()))%" }
    private func mmss(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func relative(_ d: Date) -> String {
        let m = Int(Date().timeIntervalSince(d) / 60)
        if m < 60 { return "לִפְנֵי \(max(1, m)) דַּק׳" }
        if m < 60 * 24 { return "לִפְנֵי \(m / 60) שָׁע׳" }
        return "לִפְנֵי \(m / (60 * 24)) יָמִים"
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
            let labelH: CGFloat = 18, topPad: CGFloat = 8
            let plotH = h - labelH - topPad
            let n = max(points.count, 1)
            let slot = w / CGFloat(n)
            let barW = min(22, slot * 0.55)
            let maxQ = max(points.map(\.questions).max() ?? 1, 1)
            ZStack(alignment: .topLeading) {
                // grid at 50 / 75 / 100 %
                ForEach([0.5, 0.75, 1.0], id: \.self) { f in
                    Path { p in
                        let y = topPad + plotH * (1 - f)
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                    }.stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
                // bars
                ForEach(points.indices, id: \.self) { i in
                    let p = points[i]
                    let bh = plotH * CGFloat(p.questions) / CGFloat(maxQ)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: "D9D2FF"))
                        .frame(width: barW, height: max(bh, p.questions > 0 ? 3 : 0))
                        .position(x: slot * (CGFloat(i) + 0.5), y: topPad + plotH - bh / 2)
                }
                // accuracy line over days that have answers
                let active = points.indices.filter { points[$0].questions > 0 }
                if active.count >= 2 {
                    Path { path in
                        for (k, i) in active.enumerated() {
                            let pt = CGPoint(x: slot * (CGFloat(i) + 0.5),
                                             y: topPad + plotH * (1 - CGFloat(points[i].accuracy)))
                            k == 0 ? path.move(to: pt) : path.addLine(to: pt)
                        }
                    }
                    .stroke(AppColor.dreamyIndigo, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                if let last = active.last {
                    let pt = CGPoint(x: slot * (CGFloat(last) + 0.5),
                                     y: topPad + plotH * (1 - CGFloat(points[last].accuracy)))
                    Circle().fill(AppColor.dreamyIndigo.opacity(0.18)).frame(width: 16, height: 16).position(pt)
                    Circle().fill(AppColor.dreamyIndigo).frame(width: 8, height: 8).position(pt)
                }
                // weekday labels (only every ~4th on a 30-day view)
                ForEach(points.indices, id: \.self) { i in
                    if points.count <= 7 || i % 4 == 3 || i == points.count - 1 {
                        Text(points[i].weekday)
                            .font(.system(size: 9.5, weight: i == points.count - 1 ? .heavy : .medium, design: .rounded))
                            .foregroundStyle(i == points.count - 1 ? .primary : .secondary)
                            .position(x: slot * (CGFloat(i) + 0.5), y: h - labelH / 2)
                    }
                }
            }
        }
        .accessibilityLabel("שְׁאֵלוֹת וְאֲחוּז הַצְלָחָה לְכָל יוֹם")
    }
}

/// Paired bars per day: minutes earned vs minutes actually used, one scale.
struct ScreenTimeChart: View {
    let points: [InsightsEngine.DayPoint]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let labelH: CGFloat = 18, topPad: CGFloat = 8
            let plotH = h - labelH - topPad
            let n = max(points.count, 1)
            let slot = w / CGFloat(n)
            let barW = min(11, slot * 0.28)
            let maxM = max(points.map { max($0.earned, $0.used) }.max() ?? 1, 1)
            ZStack(alignment: .topLeading) {
                ForEach([0.5, 1.0], id: \.self) { f in
                    Path { p in
                        let y = topPad + plotH * (1 - f)
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                    }.stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
                ForEach(points.indices, id: \.self) { i in
                    let p = points[i]
                    let cx = slot * (CGFloat(i) + 0.5)
                    let eh = plotH * CGFloat(p.earned) / CGFloat(maxM)
                    let uh = plotH * CGFloat(p.used) / CGFloat(maxM)
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color(hex: "B7ABFF"))
                        .frame(width: barW, height: max(eh, p.earned > 0 ? 3 : 0))
                        .position(x: cx - barW * 0.6, y: topPad + plotH - eh / 2)
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(AppColor.dreamyTeal)
                        .frame(width: barW, height: max(uh, p.used > 0 ? 3 : 0))
                        .position(x: cx + barW * 0.6, y: topPad + plotH - uh / 2)
                    if points.count <= 7 || i % 4 == 3 || i == points.count - 1 {
                        Text(p.weekday)
                            .font(.system(size: 9.5, weight: i == points.count - 1 ? .heavy : .medium, design: .rounded))
                            .foregroundStyle(i == points.count - 1 ? .primary : .secondary)
                            .position(x: cx, y: h - labelH / 2)
                    }
                }
            }
        }
        .accessibilityLabel("דַּקּוֹת שֶׁהוּרְוְחוּ וְדַקּוֹת שֶׁנֻּצְּלוּ לְכָל יוֹם")
    }
}
