import SwiftUI
import Charts

/// The "personal coach" deep-dive for one child: daily / weekly / monthly
/// summaries, per-topic confidence, strengths & challenges, coaching insights,
/// recommended parent actions, and trend charts. Opens from the dashboard card.
struct ChildInsightsView: View {
    let profile: Profile
    let snapshot: ProgressSnapshot
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.dismiss) private var dismiss

    enum Period: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var label: String {
            switch self {
            case .day: return "היום"; case .week: return "השבוע"; case .month: return "החודש"
            }
        }
    }
    @State private var period: Period = .week

    private var lp: LearningProfile {
        LearningProfile(snapshot: snapshot, enabledTopics: settings.enabledTopics, age: profile.age)
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
                periodPicker
                summaryGrid
                if period != .day { trendCharts }
                confidenceSection
                strengthsChallenges
                coachingSection
                actionsSection
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            // Sections are authored with `.trailing` == right, so render LTR;
            // Hebrew still flows RTL within each label.
            .environment(\.layoutDirection, .leftToRight)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var periodPicker: some View {
        Picker("תקופה", selection: $period) {
            ForEach(Period.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var summaryGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 10) {
            metric("❓", "\(summary.questions)", "שאלות")
            metric("✅", "\(summary.correct)", "נכונות")
            metric("💡", "\(summary.wrong)", "טעויות")
            metric("🎮", "\(summary.minutesEarned)", "דק' שנצברו")
            metric("⏱️", "\(summary.minutesUsed)", "דק' שנוצלו")
            metric("🔥", "\(summary.longestStreak)", "רצף הכי ארוך")
            metric("📚", "\(summary.learningMinutes)", "דק' למידה")
            metric("🎯", "\(Int(summary.accuracy * 100))%", "דיוק")
            metric("📅", "\(summary.activeDays)", "ימי פעילות")
            metric("🙋", "\(Int(summary.voluntaryLearningRate * 100))%", "למידה מרצון")
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    @ViewBuilder
    private var trendCharts: some View {
        let days = period == .week ? 7 : 30
        let acc = engine.accuracySeries(days: days)
        let mins = engine.minutesSeries(days: days)
        if acc.contains(where: { $0.accuracy > 0 }) || mins.contains(where: { $0.minutes > 0 }) {
            VStack(alignment: .trailing, spacing: 14) {
                card(title: "מגמת דיוק") {
                    Chart(acc, id: \.date) { p in
                        LineMark(x: .value("יום", p.date), y: .value("דיוק", p.accuracy * 100))
                            .foregroundStyle(AppColor.successMint)
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .frame(height: 130)
                }
                card(title: "דקות שנצברו") {
                    Chart(mins, id: \.date) { p in
                        BarMark(x: .value("יום", p.date), y: .value("דקות", p.minutes))
                            .foregroundStyle(AppColor.flameOrange)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 130)
                }
            }
        }
    }

    private var confidenceSection: some View {
        card(title: "ציון ביטחון לפי תחום") {
            VStack(spacing: 10) {
                let rows = engine.confidenceByTopic
                if rows.isEmpty {
                    Text("עוד אוספים נתונים…").font(.caption).foregroundStyle(.secondary)
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
        card(title: "חוזקות ואתגרים") {
            VStack(alignment: .trailing, spacing: 10) {
                topicRow("מצטיין ב", engine.strengths, AppColor.successMint, empty: "עוד נגלה")
                topicRow("מתאמן על", engine.challenges, AppColor.flameOrange, empty: "אין כרגע")
                if !engine.discovering.isEmpty {
                    topicRow("מגלה", engine.discovering, AppColor.gemPurple, empty: "")
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
        card(title: "מה אומרים הנתונים") {
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
        card(title: "המלצות להורה") {
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
        .background(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}
