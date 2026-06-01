import SwiftUI
import Combine
import UIKit

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
    @ObservedObject private var push = PushManager.shared
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var resettingProfile: Profile? = nil
    @State private var deletingProfile: Profile? = nil
    @State private var refreshTrigger = 0
    @State private var lastRefreshed = Date()
    @State private var showingSettings = false
    @State private var showingLinking = false
    @State private var showingCreateChild = false
    @State private var showingKidMode = false
    @State private var qrChild: Profile? = nil
    @State private var qrCode: String? = nil
    /// After creating a child we offer to connect their device right away.
    @State private var pendingQRChild: Profile? = nil
    /// Flips to true when the child device redeems the code — shows success then
    /// auto-closes the QR sheet.
    @State private var childDeviceLinked = false
    /// A connected device pending removal (e.g. linked to the wrong child).
    @State private var deviceToRemove: ChildDevice? = nil

    /// Rows recomputed on each refresh so values stay live as the kid plays.
    /// The parent is a MONITOR that never plays, so the cloud snapshot is the
    /// source of truth: whenever we have one for a child, use it. (The old
    /// revision/timestamp comparison made the parent show stale local data when
    /// revisions diverged — e.g. after a +minutes transaction or a child-device
    /// reinstall reset the revision.) Local vault is only a fallback before the
    /// first cloud snapshot arrives.
    private var rows: [(profile: Profile, snapshot: ProgressSnapshot)] {
        _ = refreshTrigger
        let locals = ProgressVault.shared.allSnapshots(for: profiles.profiles)
        let mapped: [(profile: Profile, snapshot: ProgressSnapshot)] = locals.map { row in
            if let remoteSnap = remote.remoteSnapshots[row.profile.id] {
                return (row.profile, remoteSnap)
            }
            return row
        }
        // Whoever is playing LIVE floats to the top — dynamic, re-sorts on each
        // 5s tick / presence update. Stable for the rest (keeps profile order).
        return mapped.enumerated()
            .sorted { a, b in
                let aLive = isChildPlayingNow(a.element.profile)
                let bLive = isChildPlayingNow(b.element.profile)
                if aLive != bLive { return aLive }      // live first
                // Then most-recently-active child first (by last device heartbeat).
                let aSeen = lastActivity(a.element.profile)
                let bSeen = lastActivity(b.element.profile)
                if aSeen != bSeen { return aSeen > bSeen }
                return a.offset < b.offset              // stable fallback
            }
            .map { $0.element }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // A real, branded control center — vibrant, not a grey list.
                AppGradient.dreamy.ignoresSafeArea()
                FloatingOrbs.home()
                SparkleField(count: 20, size: 12)

                if profiles.profiles.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            if isRoot {
                                if !push.authorized { notificationsBanner }
                                familySummaryCard
                                linkCallout
                                if !profiles.profiles.isEmpty { kidModeButton }
                            }
                            syncStatusCard
                            insightNotificationsCard
                            ForEach(rows, id: \.profile.id) { row in
                                profileCard(profile: row.profile, snapshot: row.snapshot)
                            }
                            .animation(.spring(response: 0.5, dampingFraction: 0.85),
                                       value: rows.map(\.profile.id))
                        }
                        .padding(AppSpacing.lg)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                        // These cards are authored with `.trailing` == right,
                        // so render them LTR; Hebrew text still flows RTL within
                        // each label. (Forcing RTL here would flip them left.)
                        .environment(\.layoutDirection, .leftToRight)
                    }
                    .refreshable {
                        // Pull-to-refresh: actually re-fetch every child's cloud
                        // state and give the listeners a beat to deliver.
                        remote.refreshNow()
                        refreshTrigger &+= 1
                        lastRefreshed = .now
                        try? await Task.sleep(nanoseconds: 700_000_000)
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
            .confirmationDialog(
                deletingProfile.map { "למחוק את \($0.name)?" } ?? "",
                isPresented: Binding(
                    get: { deletingProfile != nil },
                    set: { if !$0 { deletingProfile = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("מחק ילד/ה", role: .destructive) {
                    if let p = deletingProfile {
                        profiles.remove(p)   // removes locally + from the cloud
                    }
                    deletingProfile = nil
                }
                Button("בטל", role: .cancel) { deletingProfile = nil }
            } message: {
                Text("הילד/ה והנתונים שלו יימחקו מהמשפחה לצמיתות. תוכלו ליצור אותו מחדש בכל עת. מכשיר שמחובר לילד הזה יתנתק.")
            }
            .sheet(isPresented: $showingSettings) {
                ParentSettingsView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showingKidMode) {
                KidModeEntryView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showingLinking) {
                FamilyLinkingView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showingCreateChild, onDismiss: {
                // Next step after creating: connect that child's device (skippable).
                if let p = pendingQRChild {
                    pendingQRChild = nil
                    qrCode = nil
                    qrChild = p
                }
            }) {
                ProfileEditorView(mode: .create) { newProfile in
                    profiles.add(newProfile)
                    HouseholdManager.shared.upsertChild(newProfile)
                    pendingQRChild = newProfile
                } onDelete: { _ in }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(item: $qrChild) { child in
                childQRSheet(for: child)
            }
            .confirmationDialog(
                deviceToRemove.map { "להסיר את \"\($0.name)\"?" } ?? "",
                isPresented: Binding(
                    get: { deviceToRemove != nil },
                    set: { if !$0 { deviceToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("הסר מכשיר", role: .destructive) {
                    if let d = deviceToRemove { household.removeChildDevice(id: d.id) }
                    deviceToRemove = nil
                }
                Button("ביטול", role: .cancel) { deviceToRemove = nil }
            } message: {
                Text("המכשיר יוסר מהרשימה. אם הוא עדיין פתוח אצל הילד הוא עשוי להופיע שוב — כדי לקשר אותו לילד אחר, סרקו בו מחדש את ה-QR של הילד הנכון.")
            }
            .onAppear {
                refreshTrigger &+= 1
                lastRefreshed = .now
                remote.refreshNow()   // pull fresh child state on open
                rescheduleInsights()
                Task { await push.refreshAuthorizationStatus() }
                // Co-parent who chose "join existing family" on login →
                // auto-open the linking sheet to enter the invite code.
                if isRoot, settings.pendingJoinFamily {
                    settings.pendingJoinFamily = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingLinking = true
                    }
                }
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
                    Text(freqShortLabel(f)).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Compact labels for the 4-segment frequency control so Hebrew text
    /// doesn't truncate (the full names live in `displayName`). "ביום" is
    /// implied by the card title above.
    private func freqShortLabel(_ f: ParentSettings.InsightFrequency) -> String {
        switch f {
        case .off:    return "כבוי"
        case .once:   return "פעם"
        case .twice:  return "פעמיים"
        case .thrice: return "3 פעמים"
        }
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
        VStack(spacing: AppSpacing.lg) {
            Text("👨‍👩‍👧‍👦")
                .font(.system(size: 64))
            Text("בּוֹאוּ נְצַרֵף אֶת הַיְּלָדִים")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("צְרוּ פְּרוֹפִיל לְכָל יֶלֶד/ה כָּאן. אַחַר כָּךְ כָּל יֶלֶד יְקַבֵּל קוֹד QR — סוֹרְקִים אוֹתוֹ בַּמַּכְשִׁיר שֶׁל הַיֶּלֶד, וְהוּא נִכְנָס יְשִׁירוֹת לְשַׂחֵק.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            linkButton
            if !push.authorized {
                notificationsBanner.frame(maxWidth: 460)
            }
        }
        .padding(AppSpacing.lg)
    }

    /// Shown on the parent control screen when notifications are off — taps
    /// re-prompt (if possible) or open iOS Settings.
    private var notificationsBanner: some View {
        Button {
            Task {
                await push.requestAuthorization()
                if !push.authorized, let url = URL(string: UIApplication.openSettingsURLString) {
                    await MainActor.run { openURL(url) }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("הַהַתְרָאוֹת כָּבוּיוֹת")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("הַפְעִילוּ כְּדֵי לְקַבֵּל עֲדְכּוּנִים עַל הַיֶּלֶד")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                Image(systemName: "chevron.left").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColor.flameOrange.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
    }

    /// The parent's primary action — create a child profile. Each child then
    /// gets a QR to set up their own device.
    private var linkButton: some View {
        Button {
            Haptic.light()
            showingCreateChild = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                Text("צְרוּ יֶלֶד/ה")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .glow(AppColor.starGold, radius: 12)
        }
        .buttonStyle(.juicy)
        .frame(maxWidth: 460)
    }

    private var linkCallout: some View { linkButton }

    /// Hand the phone to a child: lock it to ChildTime + approved apps until the
    /// parent exits with their code.
    private var kidModeButton: some View {
        Button {
            Haptic.light()
            showingKidMode = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                Text("תֵּן לַיֶּלֶד לְשַׂחֵק")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(AppGradient.purpleDream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .glow(AppColor.gemPurple, radius: 12)
        }
        .buttonStyle(.juicy)
        .frame(maxWidth: 460)
    }

    /// Per-child QR + code for setting up that child's own device.
    private func childQRSheet(for child: Profile) -> some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            if childDeviceLinked {
                // Auto-shown the moment the child's device joins.
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(AppColor.successMint)
                        .glow(AppColor.successMint, radius: 16)
                    Text("הַמַּכְשִׁיר שֶׁל \(child.name) חֻבַּר! 🎉")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.xl)
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: AppSpacing.lg) {
                    Text("חַבְּרוּ אֶת הַמַּכְשִׁיר שֶׁל \(child.name)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let code = qrCode {
                        // Encode a Universal Link so the iPhone's native Camera
                        // can scan it and open Tofy straight into joining.
                        QRCodeView(text: JoinLink.url(forPayload: code), size: 230)
                        Text(String(code.split(separator: "|").first ?? ""))
                            .font(.system(size: 26, weight: .heavy, design: .monospaced))
                            .kerning(4)
                            .foregroundStyle(.white)
                    } else {
                        ProgressView().tint(.white).scaleEffect(1.3).frame(height: 230)
                    }

                    Text("בַּמַּכְשִׁיר שֶׁל \(child.name): פִּתְחוּ אֶת טוֹפִּי, בַּחֲרוּ \"הַמַּכְשִׁיר שֶׁל הַיֶּלֶד\", וְסִרְקוּ אֶת הַקּוֹד — וְהוּא יִכָּנֵס יְשִׁירוֹת לְשַׂחֵק.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)

                    Button("סְגוֹר") { closeQRSheet() }
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(.white.opacity(0.18), in: Capsule())

                    Text("אֶפְשָׁר לְדַלֵּג וּלְחַבֵּר אֶת הַמַּכְשִׁיר אַחַר כָּךְ — מֵהַמָּסָךְ הָרָאשִׁי.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: 460)
            }
        }
        .task(id: child.id) {
            childDeviceLinked = false
            qrCode = await HouseholdManager.shared.makeChildJoinCode(for: child.id.uuidString)
            if let code = qrCode {
                HouseholdManager.shared.watchInviteRedemption(payload: code)
            }
        }
        .onChange(of: household.redeemedInviteCode) { _, redeemed in
            guard redeemed != nil, qrChild != nil, !childDeviceLinked else { return }
            Haptic.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { childDeviceLinked = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { closeQRSheet() }
        }
        .onDisappear { HouseholdManager.shared.stopWatchingInviteRedemption() }
    }

    private func closeQRSheet() {
        HouseholdManager.shared.stopWatchingInviteRedemption()
        qrChild = nil
        qrCode = nil
        childDeviceLinked = false
    }

    /// Quick family-wide summary for today — minutes earned, questions answered,
    /// and how many kids were active. Only meaningful when kids are linked.
    @ViewBuilder
    private var familySummaryCard: some View {
        let theRows = rows
        if !theRows.isEmpty {
            // Use the synced snapshot counts so this reflects the kid's other
            // device (local learning history doesn't sync).
            let questionsPerKid = theRows.map { $0.snapshot.answeredToday }
            let minutesToday = theRows.reduce(0) { $0 + $1.snapshot.minutesEarnedToday }
            let questionsToday = questionsPerKid.reduce(0, +)
            let activeKids = questionsPerKid.filter { $0 > 0 }.count

            HStack(spacing: 10) {
                summaryTile("⏱", "\(minutesToday)", "דק' מסך היום")
                summaryTile("❓", "\(questionsToday)", "שאלות היום")
                summaryTile("🔥", "\(activeKids)/\(theRows.count)", "ילדים פעילים")
            }
            // Read right-to-left like the rest of the Hebrew UI (the dashboard
            // body is forced LTR for the .trailing-authored cards).
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private func summaryTile(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(emoji).font(.system(size: 22))
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(.white.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1))
        )
    }

    private func profileCard(profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let isActive = profile.id == profiles.activeID
        let activeUnlockSecs: Int = {
            guard let end = s.unlockEndsAt else { return 0 }
            return max(0, Int(end.timeIntervalSinceNow))
        }()
        let lp = LearningProfile(snapshot: s, enabledTopics: settings.enabledTopics, age: profile.age)
        let engine = InsightsEngine(history: LearningHistoryStore.shared.history(for: profile.id), profile: lp)
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
                    Button(role: .destructive) {
                        deletingProfile = profile
                    } label: {
                        Label("מחק ילד/ה", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 6) {
                        if isChildPlayingNow(profile) {
                            HStack(spacing: 4) {
                                Circle().fill(AppColor.successMint).frame(width: 7, height: 7)
                                Text("מְשַׂחֵק עַכְשָׁיו")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColor.successMint.opacity(0.9)))
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
                statCell(emoji: "❓", value: "\(s.answeredToday)", label: "שאלות היום")
                statCell(emoji: "🎯", value: s.answeredToday > 0 ? "\(Int(Double(s.correctToday) / Double(s.answeredToday) * 100))%" : "—", label: "הצלחה היום")
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

            // Set up this child's own device (QR / code) — primary action.
            if isRoot {
                Button {
                    Haptic.light()
                    qrCode = nil
                    qrChild = profile
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 20, weight: .bold))
                        Text((household.devicesByChild[profile.id.uuidString]?.isEmpty == false)
                             ? "חַבְּרוּ מַכְשִׁיר נוֹסָף לְ\(profile.name)"
                             : "חַבְּרוּ אֶת הַמַּכְשִׁיר שֶׁל \(profile.name)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.left").font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 14).padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(AppGradient.purpleDream, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                    .glow(AppColor.gemPurple, radius: 10)
                }
                .buttonStyle(.juicy)
            }

            // Connected devices for this child.
            connectedDevicesView(for: profile)

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

                Spacer()
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

    /// Which devices this child plays on, with how long ago each was active.
    @ViewBuilder
    private func connectedDevicesView(for profile: Profile) -> some View {
        let devices = household.devicesByChild[profile.id.uuidString] ?? []
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 6) {
                Spacer()
                Text(devices.isEmpty ? "אֵין מַכְשִׁירִים מְחֻבָּרִים" : "\(devices.count) מַכְשִׁירִים מְחֻבָּרִים")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Image(systemName: "ipad.and.iphone")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.gemPurple)
            }
            ForEach(devices) { device in
                HStack(spacing: 10) {
                    Button {
                        Haptic.light()
                        deviceToRemove = device
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(device.name)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(deviceSeenText(device))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: device.sfSymbol)
                        .font(.system(size: 18))
                        .foregroundStyle(AppColor.gemPurple)
                        .frame(width: 26)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.5))
        )
    }

    /// True when any of the child's devices sent a heartbeat in the last ~75s
    /// (the play screen refreshes every 30s) — i.e. the child is playing now.
    private func isChildPlayingNow(_ profile: Profile) -> Bool {
        _ = refreshTrigger   // recompute on the dashboard's 5s tick
        let devices = household.devicesByChild[profile.id.uuidString] ?? []
        return devices.contains { -$0.lastSeenAt.timeIntervalSinceNow < 75 }
    }

    /// Most recent time any of the child's devices was seen — used to order the
    /// dashboard by who played last (most recent on top). `.distantPast` if the
    /// child has no connected device yet.
    private func lastActivity(_ profile: Profile) -> Date {
        _ = refreshTrigger
        let devices = household.devicesByChild[profile.id.uuidString] ?? []
        return devices.map(\.lastSeenAt).max() ?? .distantPast
    }

    private func deviceSeenText(_ device: ChildDevice) -> String {
        let elapsed = Int(-device.lastSeenAt.timeIntervalSinceNow)
        if elapsed < 90 { return "פָּעִיל עַכְשָׁיו 🟢" }
        if elapsed < 3600 { return "נִרְאָה לִפְנֵי \(elapsed / 60) דַּקּוֹת" }
        if elapsed < 86400 { return "נִרְאָה לִפְנֵי \(elapsed / 3600) שָׁעוֹת" }
        return "נִרְאָה לִפְנֵי \(elapsed / 86400) יָמִים"
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
        Haptic.light()
        // Edit the child's CLOUD snapshot directly (revision-bumping transaction)
        // so it reaches the child's device regardless of which profile is active
        // on this parent device.
        remote.adjustChildMinutes(childID: profile.id, deltaMinutes: deltaMinutes)
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
