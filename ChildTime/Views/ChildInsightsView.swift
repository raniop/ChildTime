import SwiftUI
import Charts

/// The "personal coach" deep-dive for one child: daily / weekly / monthly
/// summaries, per-topic confidence, strengths & challenges, coaching insights,
/// recommended parent actions, and trend charts. Opens from the dashboard card.
struct ChildInsightsView: View {
    let profile: Profile
    let snapshot: ProgressSnapshot
    @EnvironmentObject var settings: ParentSettings
    @ObservedObject private var historyStore = LearningHistoryStore.shared
    @Environment(\.dismiss) private var dismiss

    enum Period: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var label: String {
            switch self {
            case .day: return tr("היום"); case .week: return tr("השבוע"); case .month: return tr("החודש")
            }
        }
    }
    @State private var period: Period = .week

    private var lp: LearningProfile {
        LearningProfile(snapshot: snapshot, enabledTopics: profile.playableTopics, age: profile.age)
    }
    private var history: [DailyStat] {
        LearningHistoryStore.shared.history(for: profile.id)
    }
    private var engine: InsightsEngine { InsightsEngine(history: history, profile: lp) }
    private var coach: CoachingEngine {
        CoachingEngine(childName: profile.name, insights: engine, profile: lp, isGirl: profile.gender == .girl)
    }
    private var summary: InsightsEngine.PeriodSummary {
        switch period {
        case .day: return engine.today
        case .week: return engine.thisWeek
        case .month: return engine.thisMonth
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 18) {
                snapshotStrip
                periodPicker
                summaryGrid
                if period != .day { trendCharts }
                confidenceSection
                strengthsChallenges
                interestsSection
                learningStyleSection
                persistenceSection
                focusSection
                coachingSection
                actionsSection
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            // Sections are authored with `.trailing` == right, so render LTR;
            // Hebrew still flows RTL within each label.
            .environment(\.layoutDirection, .appMirrored)
        }
        .background(AppGradient.dreamy.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // On the parent's device the child's day-by-day history isn't local —
            // pull it from Firestore so the week/month summaries aren't all zeros.
            await historyStore.fetchRemoteHistory(for: profile.id)
        }
    }

    // MARK: - Sections

    /// Quick top-line snapshot — independent of the period picker.
    private var snapshotStrip: some View {
        HStack(spacing: 8) {
            snapChip(engine.learningTrend.label, color: engine.learningTrend.color)
            if let s = engine.avgResponseSeconds {
                snapChip(tr("⏳ \(s) שְׁנִיּוֹת מַעֲנֶה"), color: .secondary)
            }
            snapChip(tr("🔥 \(snapshot.dayStreak) יְמֵי רֶצֶף"), color: AppColor.flameOrange)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func snapChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.14)))
    }

    @ViewBuilder private var interestsSection: some View {
        if !engine.gainedInterest.isEmpty || !engine.lostInterest.isEmpty {
            card(title: tr("תְּחוּמֵי עִנְיָן")) {
                VStack(alignment: .trailing, spacing: 10) {
                    topicRow(tr("צוֹבֵר עִנְיָן"), engine.gainedInterest, AppColor.gemPurple, empty: "")
                    if !engine.lostInterest.isEmpty {
                        topicRow(tr("אִבֵּד עִנְיָן"), engine.lostInterest, AppColor.flameOrange, empty: "")
                    }
                }
            }
        }
    }

    @ViewBuilder private var learningStyleSection: some View {
        if let style = engine.learningStyle {
            card(title: tr("סִגְנוֹן לְמִידָה")) {
                labeledRow(style)
            }
        }
    }

    @ViewBuilder private var persistenceSection: some View {
        if let p = engine.persistence {
            card(title: tr("הַתְמָדָה")) {
                labeledRow(p)
            }
        }
    }

    @ViewBuilder private var focusSection: some View {
        if let f = snapshot.focusInsight {
            card(title: tr("רִכּוּז וּשְׁעוֹת שִׂיא")) {
                labeledRow(InsightsEngine.Labeled(emoji: "⏰", title: f.title, detail: f.detail))
            }
        }
    }

    private func labeledRow(_ l: InsightsEngine.Labeled) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                Text(l.title).font(.system(size: 15, weight: .heavy, design: .rounded))
                Text(l.detail).font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(l.emoji).font(.system(size: 30))
        }
    }

    private var periodPicker: some View {
        Picker(tr("תקופה"), selection: $period) {
            ForEach(Period.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var summaryGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 10) {
            metric("❓", "\(summary.questions)", tr("שאלות"))
            metric("✅", "\(summary.correct)", tr("נכונות"))
            metric("💡", "\(summary.wrong)", tr("טעויות"))
            metric("🎮", "\(summary.minutesEarned)", tr("דק׳ שנצברו"))
            metric("⏱️", "\(summary.minutesUsed)", tr("דק׳ שנוצלו"))
            metric("🔥", "\(summary.longestStreak)", tr("רצף הכי ארוך"))
            metric("📚", "\(summary.learningMinutes)", tr("דק׳ למידה"))
            metric("🎯", "\(Int(summary.accuracy * 100))%", tr("דיוק"))
            metric("📅", "\(summary.activeDays)", tr("ימי פעילות"))
            metric("🙋", "\(Int(summary.voluntaryLearningRate * 100))%", tr("למידה מרצון"))
        }
    }

    private func metric(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(emoji).font(.system(size: 20))
            Text(value).font(.system(size: 19, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassPane(radius: 14, shadow: false)
    }

    @ViewBuilder
    private var trendCharts: some View {
        let days = period == .week ? 7 : 30
        let acc = engine.accuracySeries(days: days)
        let mins = engine.minutesSeries(days: days)
        if acc.contains(where: { $0.accuracy > 0 }) || mins.contains(where: { $0.minutes > 0 }) {
            VStack(alignment: .trailing, spacing: 14) {
                card(title: tr("מגמת דיוק")) {
                    Chart(acc, id: \.date) { p in
                        LineMark(x: .value(tr("יום"), p.date), y: .value(tr("דיוק"), p.accuracy * 100))
                            .foregroundStyle(AppColor.successMint)
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .frame(height: 130)
                }
                card(title: tr("דקות שנצברו")) {
                    Chart(mins, id: \.date) { p in
                        BarMark(x: .value(tr("יום"), p.date), y: .value(tr("דקות"), p.minutes))
                            .foregroundStyle(AppColor.flameOrange)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 130)
                }
            }
        }
    }

    private var confidenceSection: some View {
        card(title: tr("ציון ביטחון לפי תחום")) {
            VStack(spacing: 10) {
                let rows = engine.confidenceByTopic
                if rows.isEmpty {
                    Text(tr("עוד אוספים נתונים…")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(rows, id: \.topic) { row in
                        HStack(spacing: 10) {
                            Text("\(row.score)%")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .frame(width: 48, alignment: .leading)
                                .foregroundStyle(confidenceColor(row.score))
                            ProgressView(value: Double(row.score), total: 100)
                                .tint(confidenceColor(row.score))
                            Text("\(row.topic.emoji) \(row.topic.displayName)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .frame(width: 110, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func confidenceColor(_ score: Int) -> Color {
        if score >= 80 { return AppColor.successMint }
        if score >= 55 { return AppColor.starGold }
        return AppColor.flameOrange
    }

    private var strengthsChallenges: some View {
        card(title: tr("חוזקות ואתגרים")) {
            VStack(alignment: .trailing, spacing: 10) {
                topicRow(tr("מצטיין ב"), engine.strengths, AppColor.successMint, empty: tr("עוד נגלה"))
                topicRow(tr("מתאמן על"), engine.challenges, AppColor.flameOrange, empty: tr("אין כרגע"))
                if !engine.discovering.isEmpty {
                    topicRow(tr("מגלה"), engine.discovering, AppColor.gemPurple, empty: "")
                }
            }
        }
    }

    private func topicRow(_ label: String, _ topics: [Topic], _ tint: Color, empty: String) -> some View {
        HStack(spacing: 6) {
            Spacer()
            if topics.isEmpty {
                Text(empty).font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(topics.prefix(3), id: \.self) { t in
                    Text("\(t.emoji) \(t.displayName)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(tint.opacity(0.18)))
                        .overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
                }
            }
            Text("\(label):").font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var coachingSection: some View {
        card(title: tr("מה אומרים הנתונים")) {
            VStack(alignment: .trailing, spacing: 10) {
                ForEach(coach.insightCards()) { ins in
                    HStack(alignment: .top, spacing: 10) {
                        Spacer(minLength: 0)
                        Text(ins.text)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(ins.emoji).font(.system(size: 20))
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        card(title: tr("המלצות להורה")) {
            VStack(alignment: .trailing, spacing: 10) {
                ForEach(coach.recommendedActions()) { act in
                    HStack(alignment: .top, spacing: 10) {
                        Spacer(minLength: 0)
                        Text(act.text)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(act.emoji).font(.system(size: 20))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .trailing)
            content()
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .glassPane(radius: AppRadius.large)
    }
}
