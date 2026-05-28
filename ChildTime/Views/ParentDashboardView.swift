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
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var auth: AuthManager
    @StateObject private var remote = RemoteSyncManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var resettingProfile: Profile? = nil
    @State private var refreshTrigger = 0
    @State private var lastRefreshed = Date()

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
                            ForEach(rows, id: \.profile.id) { row in
                                profileCard(profile: row.profile, snapshot: row.snapshot)
                            }
                        }
                        .padding(AppSpacing.lg)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("מבט-על על המשפחה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סיום") { dismiss() }
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
            .onAppear {
                refreshTrigger &+= 1
                lastRefreshed = .now
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
            Image(systemName: synced ? "checkmark.icloud.fill" : "icloud.slash")
                .foregroundStyle(synced ? AppColor.successMint : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
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
                }
                if let err = remote.lastError, synced {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.85))
                }
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
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

        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                ProfileAvatarView(profile: profile, size: 54)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.name)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        if isActive {
                            Text("פעיל")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppColor.successMint))
                        }
                    }
                    Text("\(profile.age.label) • \(profile.gender?.displayName ?? "לא צוין")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
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
            }

            HStack(spacing: 10) {
                statCell(emoji: "⏱", value: "\(s.pendingMinutes)", label: "דק' זמינות")
                statCell(emoji: "🎮", value: activeUnlockSecs > 0 ? formatTime(activeUnlockSecs) : "—", label: "זמן פעיל")
                statCell(emoji: "🏆", value: "\(s.totalScore)", label: "ניקוד")
            }
            HStack(spacing: 10) {
                statCell(emoji: "⭐", value: "\(s.stars)", label: "כוכבים")
                statCell(emoji: "💎", value: "\(s.gems)", label: "מטבעות")
                statCell(emoji: "🔥", value: "\(s.dayStreak)", label: "רצף ימים")
            }

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
