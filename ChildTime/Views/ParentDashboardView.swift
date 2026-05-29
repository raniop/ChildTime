import SwiftUI
import Combine

/// Dashboard the parent opens from Parent Settings — shows every profile
/// (every kid in the family) with their current time / score / progress
/// at a glance, with reset actions.
///
/// v1 reads from local UserDefaults (works without any account). v2 will
/// layer Firestore sync on top so the dashboard reflects state even when
/// the kid is on a different device.
struct ParentDashboardView: View {
    /// When true this is the device's HOME screen (parent device), not a sheet —
    /// so there's no "Done" button and we expose Settings via a gear instead.
    var isRoot: Bool = false

    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var auth: AuthManager
    @StateObject private var remote = RemoteSyncManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var resettingProfile: Profile? = nil
    @State private var refreshTrigger = 0
    @State private var lastRefreshed = Date()
    @State private var showingSettings = false

    /// Rows recomputed on each refresh so values stay live as the kid plays.
    /// Prefers a remote snapshot when one is available and newer than the
    /// local copy — that's how the parent sees the kid's other device.
    private var rows: [(profile: Profile, snapshot: ProgressSnapshot)] {
        _ = refreshTrigger
        let locals = ProgressVault.shared.allSnapshots(for: profiles.profiles)
        return locals.map { row in
            guard let remoteSnap = remote.remoteSnapshots[row.profile.id] else {
                return row
            }
            // Prefer remote if it has a higher revision OR newer timestamp.
            let useRemote =
                remoteSnap.revision > row.snapshot.revision ||
                (remoteSnap.revision == row.snapshot.revision &&
                 remoteSnap.lastModifiedAt > row.snapshot.lastModifiedAt)
            return (row.profile, useRemote ? remoteSnap : row.snapshot)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.dreamy.ignoresSafeArea().opacity(0.4)
                Color(.systemGroupedBackground).ignoresSafeArea().opacity(0.6)

                if profiles.profiles.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            syncStatusCard
                            insightNotificationsCard
                            ForEach(rows, id: \.profile.id) { row in
                                profileCard(profile: row.profile, snapshot: row.snapshot)
                            }
                        }
                        .padding(AppSpacing.lg)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                        // These cards are authored with `.trailing` == right,
                        // so render them LTR; Hebrew text still flows RTL within
                        // each label. (Forcing RTL here would flip them left.)
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
            .navigationTitle("מבט-על על המשפחה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isRoot {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                        }
                    } else {
                        Button("סיום") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        refreshTrigger &+= 1
                        lastRefreshed = .now
                    } label: {
                        Label("רענון", systemImage: "arrow.clockwise")
                    }
                }
            }
            .confirmationDialog(
                resettingProfile.map { "לאפס את ההתקדמות של \($0.name)?" } ?? "",
                isPresented: Binding(
                    get: { resettingProfile != nil },
                    set: { if !$0 { resettingProfile = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("אפס דקות + ניקוד", role: .destructive) {
                    if let p = resettingProfile { resetProgress(for: p) }
                    resettingProfile = nil
                }
                Button("בטל", role: .cancel) { resettingProfile = nil }
            } message: {
                Text("פעולה זו תאפס דקות משחק שנצברו, ניקוד הסשן, ועונש טעויות. לא ימחק שמות, פרופילים או פריטי קוסמטיקה.")
            }
            .sheet(isPresented: $showingSettings) {
                ParentSettingsView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .onAppear {
                refreshTrigger &+= 1
                lastRefreshed = .now
                rescheduleInsights()
            }
            .onChange(of: settings.parentInsightFrequency) { _, freq in
                if freq != .off {
                    Task { await PushManager.shared.requestAuthorization() }
                }
                rescheduleInsights()
            }
            // Tick every 5s so 'minutes remaining' counts down live.
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                refreshTrigger &+= 1
                lastRefreshed = .now
            }
        }
    }

    // MARK: - Sub-views

    private var syncStatusCard: some View {
        let synced = auth.isSignedIn && remote.isActive
        return HStack(spacing: 12) {
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(synced ? "סנכרון בין מכשירים פעיל" : "מצב מקומי בלבד")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                if synced {
                    if let when = remote.lastUploadAt {
                        Text("סנכרון אחרון: \(relativeTime(when))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("מסנכרן… (מכשירים אחרים יקבלו עדכון תוך שניות)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("כדי לראות את הילד ממכשיר אחר, התחבר ב-Parent Settings → סנכרון בין מכשירים.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                if let err = remote.lastError, synced {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.trailing)
                }
            }
            Image(systemName: synced ? "checkmark.icloud.fill" : "icloud.slash")
                .foregroundStyle(synced ? AppColor.successMint : .secondary)
                .font(.title3)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var insightNotificationsCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 8) {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("התראות תובנות להורה")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text("עדכונים קצרים ואישיים על כל ילד — במה השתפר, איפה התקשה ומה לתרגל.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.gemPurple)
            }

            Picker("תדירות", selection: $settings.parentInsightFrequency) {
                ForEach(ParentSettings.InsightFrequency.allCases) { f in
                    Text(f.displayName).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func rescheduleInsights() {
        InsightNotificationScheduler.reschedule(
            rows: rows,
            enabledTopics: settings.enabledTopics,
            frequency: settings.parentInsightFrequency
        )
    }

    private func relativeTime(_ when: Date) -> String {
        let elapsed = Int(-when.timeIntervalSinceNow)
        if elapsed < 5 { return "ממש עכשיו" }
        if elapsed < 60 { return "לפני \(elapsed) שניות" }
        if elapsed < 3600 { return "לפני \(elapsed / 60) דק'" }
        return "לפני \(elapsed / 3600) שעות"
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Text("👨‍👩‍👧‍👦")
                .font(.system(size: 60))
            Text("עוד אין פרופילים במשפחה")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
            Text("חזור ל-Parent Settings ולחץ \"החלף פרופיל\" כדי ליצור את הראשון.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func profileCard(profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let isActive = profile.id == profiles.activeID
        let activeUnlockSecs: Int = {
            guard let end = s.unlockEndsAt else { return 0 }
            return max(0, Int(end.timeIntervalSinceNow))
        }()
        let lp = LearningProfile(snapshot: s, enabledTopics: settings.enabledTopics, age: profile.age)
        let engine = InsightsEngine(history: LearningHistoryStore.shared.history(for: profile.id), profile: lp)
        let today = engine.today
        let status = overallStatus(engine: engine, lp: lp, hasData: s.totalAnswered >= 4)

        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                Menu {
                    if !isActive {
                        Button {
                            profiles.setActive(profile)
                        } label: {
                            Label("עבור לפרופיל זה", systemImage: "person.crop.circle.fill")
                        }
                    }
                    Button(role: .destructive) {
                        resettingProfile = profile
                    } label: {
                        Label("אפס התקדמות", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 6) {
                        if isActive {
                            Text("פעיל")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppColor.successMint))
                        }
                        Text(profile.name)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                    }
                    Text("\(profile.age.label) • \(profile.gender?.displayName ?? "לא צוין")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let status {
                        Text(status.text)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(status.color))
                    }
                }
                ProfileAvatarView(profile: profile, size: 54)
            }

            // Today at a glance.
            HStack(spacing: 10) {
                statCell(emoji: "⏱", value: "\(s.minutesEarnedToday)", label: "זמן מסך היום")
                statCell(emoji: "❓", value: "\(today.questions)", label: "שאלות היום")
                statCell(emoji: "🎯", value: today.questions > 0 ? "\(Int(today.accuracy * 100))%" : "—", label: "הצלחה היום")
            }
            HStack(spacing: 10) {
                statCell(emoji: "🔥", value: "\(s.dayStreak)", label: "רצף ימים")
                statCell(emoji: "⭐", value: "\(s.stars)", label: "כוכבים")
                statCell(emoji: "🎮", value: s.pendingMinutes > 0 ? "\(s.pendingMinutes)" : (activeUnlockSecs > 0 ? formatTime(activeUnlockSecs) : "—"), label: "דק' זמינות")
            }

            // Learning profile — what the Smart Feed has learned about this kid.
            learningProfileCard(for: profile, snapshot: s)

            // Actionable coaching — where to reinforce + concrete tips.
            coachingCard(for: profile, snapshot: s)

            // Full analytics deep-dive (daily/weekly/monthly + coaching).
            NavigationLink {
                ChildInsightsView(profile: profile, snapshot: s)
                    .environmentObject(settings)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("תובנות מלאות")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.left").font(.caption)
                }
                .foregroundStyle(AppColor.gemPurple)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColor.gemPurple.opacity(0.12)))
            }
            .buttonStyle(.plain)

            // Daily cap line (if enabled)
            if settings.dailyCapEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                    Text("נצבר היום: \(s.minutesEarnedToday) / \(settings.maxMinutesPerDay) דק'")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // Quick actions
            HStack(spacing: 10) {
                Button {
                    quickAdjust(profile: profile, deltaMinutes: 10)
                } label: {
                    Text("+10 דק'")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(AppColor.successMint.opacity(0.25)))
                        .overlay(Capsule().stroke(AppColor.successMint, lineWidth: 1))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.borderless)
                .disabled(!isActive)

                Button {
                    quickAdjust(profile: profile, deltaMinutes: -5)
                } label: {
                    Text("−5 דק'")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange.opacity(0.25)))
                        .overlay(Capsule().stroke(Color.orange, lineWidth: 1))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.borderless)
                .disabled(!isActive)

                Spacer()

                if !isActive {
                    Text("ניתן לערוך רק את הפרופיל הפעיל")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(isActive ? AppColor.successMint.opacity(0.6) : .clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private func learningProfileCard(for profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let lp = LearningProfile(snapshot: s, enabledTopics: settings.enabledTopics, age: profile.age)
        let favorites = Array(lp.favorites.prefix(3))
        let strong = Array(lp.strong.prefix(3))
        let weak = Array(lp.weak.prefix(3))
        let discovering = Array(lp.discovering.prefix(3))

        // Only show once the kid has actually played enough to have signals.
        if s.totalAnswered >= 4 {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    Spacer()
                    Text("פרופיל למידה")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.gemPurple)
                }
                if !strong.isEmpty   { topicLine("חזק ב", topics: strong, tint: AppColor.starGold) }
                if !favorites.isEmpty { topicLine("אוהב", topics: favorites, tint: AppColor.successMint) }
                if !weak.isEmpty     { topicLine("כדאי לחזק", topics: weak, tint: AppColor.flameOrange) }
                if !discovering.isEmpty { topicLine("מגלה", topics: discovering, tint: AppColor.gemPurple) }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.5))
            )
        }
    }

    /// "המלצות להורה" — surfaces where the child needs reinforcement (the
    /// topics they get wrong most) plus the CoachingEngine's concrete, low-effort
    /// tips. Only appears once the kid has played enough to have signal.
    @ViewBuilder
    private func coachingCard(for profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let lp = LearningProfile(snapshot: s, enabledTopics: settings.enabledTopics, age: profile.age)
        let history = LearningHistoryStore.shared.history(for: profile.id)
        let engine = InsightsEngine(history: history, profile: lp)
        let coach = CoachingEngine(childName: profile.name, insights: engine, profile: lp)
        let actions = Array(coach.recommendedActions().prefix(3))
        let weak = Array(lp.weak.prefix(2))

        if s.totalAnswered >= 4 {
            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 6) {
                    Spacer()
                    Text("המלצות להורה")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.starGold)
                }

                // Where the child struggles most — what to reinforce.
                if !weak.isEmpty {
                    HStack(spacing: 6) {
                        Spacer()
                        ForEach(weak) { t in
                            Text("\(t.emoji) \(t.displayName)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppColor.flameOrange.opacity(0.18)))
                                .overlay(Capsule().stroke(AppColor.flameOrange.opacity(0.5), lineWidth: 1))
                        }
                        Text("כדאי לחזק:")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                // Concrete tips.
                ForEach(actions) { act in
                    HStack(alignment: .top, spacing: 8) {
                        Text(act.emoji).font(.system(size: 14))
                        Text(act.text)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColor.starGold.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .stroke(AppColor.starGold.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    /// Overall one-glance status for the child: progressing / needs reinforcement
    /// / discovering. Returns nil until there's enough data.
    private func overallStatus(engine: InsightsEngine, lp: LearningProfile, hasData: Bool) -> (text: String, color: Color)? {
        guard hasData else { return nil }
        let acc = engine.thisWeek.accuracy
        if acc >= 0.75 || engine.weeklyAccuracyDelta >= 8 {
            return ("מתקדם יפה 🎉", AppColor.successMint)
        }
        if engine.challenges.isEmpty, !engine.discovering.isEmpty {
            return ("מגלה עניין חדש 🔭", AppColor.gemPurple)
        }
        if !engine.challenges.isEmpty {
            return ("צריך חיזוק 💪", AppColor.flameOrange)
        }
        return ("מתקדם יפה 🎉", AppColor.successMint)
    }

    private func topicLine(_ label: String, topics: [Topic], tint: Color) -> some View {
        HStack(spacing: 6) {
            Spacer()
            ForEach(topics) { t in
                Text("\(t.emoji) \(t.displayName)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(tint.opacity(0.18)))
                    .overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
            }
            Text("\(label):")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func statCell(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 18))
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.6))
        )
    }

    // MARK: - Actions

    private func resetProgress(for profile: Profile) {
        Haptic.warning()
        ProgressVault.shared.resetProfile(profile.id)
        // Push immediately so the kid's other device picks up the reset
        // within seconds rather than waiting for the debounced upload.
        remote.pushNow()
        refreshTrigger &+= 1
    }

    /// Quick +/- minute adjustment. Only works on the active profile (the
    /// one with state in memory). For non-active profiles we'd need to
    /// edit the snapshot directly — kept out of v1 to avoid stale-data
    /// races; the parent can switch to that profile first.
    private func quickAdjust(profile: Profile, deltaMinutes: Int) {
        guard profile.id == profiles.activeID else { return }
        Haptic.light()
        if deltaMinutes > 0 {
            _ = ProgressStore.shared.grantMinutesCapped(deltaMinutes)
        } else {
            _ = ProgressStore.shared.spendPendingMinutes(-deltaMinutes)
        }
        refreshTrigger &+= 1
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ParentDashboardView()
        .environmentObject(ProfileStore.shared)
        .environmentObject(ParentSettings.shared)
        .environmentObject(AuthManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
