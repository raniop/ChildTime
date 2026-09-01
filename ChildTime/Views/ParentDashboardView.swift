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
    /// Confirm clearing a child's "protect my time" code (when the kid forgot it).
    @State private var pinResetProfile: Profile? = nil
    /// Confirm 'lock + revoke all parent-given minutes' (a deliberate act).
    @State private var revokeGiftProfile: Profile? = nil
    @State private var navPath: [UUID] = []   // pushed child-detail pages (pop on delete)
    @State private var gridDeleteProfile: Profile? = nil   // long-press delete from the grid
    @State private var showingReorder = false               // manual child order sheet
    @State private var statExplain: StatExplain? = nil      // tapped-stat explanation
    @State private var refreshTrigger = 0
    @State private var lastRefreshed = Date()
    @State private var showingSettings = false
    @State private var showingCreateChild = false
    @State private var showingKidMode = false
    @State private var friendsProfile: Profile?
    @State private var difficultyProfile: Profile?
    @State private var choresProfile: Profile?    // 🧹 chores sheet
    @State private var showSchoolYearParty = false
    @State private var showWhatsNew = false
    @StateObject private var choreStore = ChoreStore.shared
    @State private var screenTimeProfile: Profile?
    @State private var editProfile: Profile?
    @State private var remoteGrantMsg: String?
    /// Live remote-lock status sheet — real send/ack progress, not a static alert.
    @State private var commandStatus: RemoteCommandStatusRequest?
    @State private var worldsProfile: Profile?
    @State private var showingFeedback = false
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
            var snap = remote.remoteSnapshots[row.profile.id] ?? row.snapshot
            // Fold in any parent minute grant still in flight to the child's device,
            // so a +10/−5 shows immediately and doesn't appear to "revert".
            let adj = remote.pendingAdjustments[row.profile.id, default: 0]
            if adj != 0 { snap.pendingMinutes = max(0, snap.pendingMinutes + adj) }
            return (row.profile, snap)
        }
        // Stable order so the grid never reshuffles when a child starts/stops
        // playing: the parent's MANUAL order first (household.childOrder — drag
        // to reorder), then alphabetical (Hebrew א,ב,ג…) for anyone not placed
        // yet (e.g. a newly created child).
        let manual = household.effectiveChildOrder
        let rank: [String: Int] = Dictionary(uniqueKeysWithValues: manual.enumerated().map { ($1, $0) })
        return mapped.sorted { a, b in
            let ra = rank[a.profile.id.uuidString], rb = rank[b.profile.id.uuidString]
            switch (ra, rb) {
            case let (x?, y?): return x < y
            case (_?, nil):    return true
            case (nil, _?):    return false
            default:           return a.profile.name.localizedCompare(b.profile.name) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
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
                                // The two primary actions side by side (iPhone and
                                // iPad alike) — stacking wasted a whole row. RTL
                                // priority: "create child" on the RIGHT, "let the
                                // child play" on the left. Text scales down on
                                // narrow phones (both buttons allow it).
                                if !profiles.profiles.isEmpty {
                                    HStack(spacing: 10) {
                                        kidModeButton
                                        linkButton
                                    }
                                    // 🧹 Standing chores row — ALWAYS here, right
                                    // under the two primary buttons (Rani), so
                                    // approvals never hide in a menu.
                                    choresApprovalBanner
                                } else {
                                    linkCallout
                                }
                            }
                            childrenGrid

                            // Manual order — a discreet entry under the grid (also in
                            // each card's long-press menu). Only meaningful with 2+.
                            if rows.count >= 2 {
                                Button {
                                    Haptic.light()
                                    showingReorder = true
                                } label: {
                                    Label("סַדְּרוּ אֶת הַיְלָדִים", systemImage: "arrow.up.arrow.down")
                                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(.white.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            // Secondary status/settings cards live BELOW the
                            // children — the kids are what the parent opens the
                            // dashboard for; sync + insight-notification settings
                            // are glance-and-forget.
                            syncStatusCard
                            insightNotificationsCard

                            // Time-transfer requests live BELOW the children.

                            if rows.count >= 2 { familyComparison(rows) }

                            // Feedback to the team — a plain button BELOW everything
                            // (replaces the floating bubble that overlapped a child
                            // card on smaller screens).
                            if isRoot {
                                Button { showingFeedback = true } label: {
                                    Label("פִידְבֵּק וְהַצָּעוֹת", systemImage: "text.bubble.fill")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(.white.opacity(0.14), in: Capsule())
                                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, AppSpacing.sm)
                                .accessibilityLabel("שליחת פידבק לצוות")
                            }
                        }
                        .padding(AppSpacing.lg)
                        .frame(maxWidth: 720)
                        // Pin the content to EXACTLY the scroll container's width.
                        // A vertical ScrollView can only drift sideways if its
                        // content's cross-axis (horizontal) size exceeds the
                        // viewport; locking it to the container width removes that
                        // possibility outright — belt to the `.scrollBounceBehavior`
                        // suspenders below, and to the LTR-container fix.
                        .containerWidthLock()
                    }
                    // Never allow horizontal scrolling/bounce — this is a
                    // vertical-only page. On some iOS versions the RTL→LTR
                    // container flip left a hair of horizontal slack that became
                    // a draggable sideways drift; `.basedOnSize` disables the
                    // horizontal axis entirely when the content already fits.
                    .noHorizontalBounce()
                    .refreshable {
                        // Pull-to-refresh: actually re-fetch every child's cloud
                        // state and give the listeners a beat to deliver.
                        remote.refreshNow()
                        refreshTrigger &+= 1
                        lastRefreshed = .now
                        try? await Task.sleep(nanoseconds: 700_000_000)
                    }
                    // Force the WHOLE scroll container (not just its content) to LTR.
                    // The cards are authored with `.trailing` == right; Hebrew text
                    // still flows RTL inside each label. Applying this only to the
                    // inner content while the ScrollView stayed RTL created a
                    // container/content mismatch that let the page drift sideways —
                    // matching the container fixes it so it scrolls vertically only.
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // Keep the title floating over the app gradient. Without this, iOS pops
            // a translucent system material strip behind the inline title the moment
            // the page scrolls — which clashes badly with the gradient on iPad.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // A personal hello instead of a static title: time-of-day
                    // greeting + first name, and one live line that shows the app
                    // actually knows this family (from real data, rotates on entry).
                    VStack(spacing: 1) {
                        Text(greetingLine)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        if let sub = familyMomentLine {
                            Text(sub)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isRoot {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(.white)
                        }
                    } else {
                        Button("סיום") { dismiss() }
                    }
                }
            }
            // Push a full child page when a grid card is tapped (path-based so a
            // delete inside the page can pop back to the grid on its own).
            .navigationDestination(for: UUID.self) { id in
                childDetailScreen(for: id)
            }
            // Long-press → delete straight from the grid (its own state so it can't
            // clash with the detail page's delete dialog). An `alert` (not a
            // `confirmationDialog`) — the latter is a popover on iPad that, when
            // fired from a context menu, often has no anchor and never appears.
            .alert(
                gridDeleteProfile.map { "למחוק את \($0.name)?" } ?? "",
                isPresented: Binding(get: { gridDeleteProfile != nil },
                                     set: { if !$0 { gridDeleteProfile = nil } }),
                presenting: gridDeleteProfile
            ) { p in
                Button("מחק ילד/ה", role: .destructive) {
                    profiles.remove(p)
                    gridDeleteProfile = nil
                }
                Button("בטל", role: .cancel) { gridDeleteProfile = nil }
            } message: { _ in
                Text("הילד/ה והנתונים שלו יימחקו מהמשפחה לצמיתות. תוכלו ליצור אותו מחדש בכל עת. מכשיר שמחובר לילד הזה יתנתק.")
            }
            .sheet(isPresented: $showingSettings) {
                ParentSettingsView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showingReorder) {
                ChildOrderView(profiles: rows.map(\.profile)) { ordered in
                    household.setChildOrder(ordered.map(\.id))
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
            // Root-level alerts hosted on an invisible overlay — keeps the main
            // modifier chain small enough for the type-checker.
            .overlay(rootAlertsHost)
            .sheet(isPresented: $showingKidMode) {
                KidModeEntryView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(item: $friendsProfile) { p in
                ChildFriendsView(childID: p.id.uuidString, childName: p.name)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showWhatsNew, onDismiss: { WhatsNewContent.markShown() }) {
                WhatsNewView {
                    WhatsNewContent.markShown()
                    showWhatsNew = false
                }
            }
            .fullScreenCover(isPresented: $showSchoolYearParty) {
                ParentSchoolYearPartyView(profiles: rows.map(\.profile)) {
                    SchoolYearCelebration.markParentGreeted()
                    showSchoolYearParty = false
                }
            }
            .sheet(item: $choresProfile) { p in
                ChoresParentView(profile: p)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(item: $difficultyProfile) { p in
                ChildDifficultyView(profileID: p.id)
                    .environmentObject(profiles)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(item: $screenTimeProfile) { p in
                ChildScreenTimeView(profileID: p.id)
                    .environmentObject(profiles)
                    .environmentObject(settings)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(item: $editProfile) { p in
                ProfileEditorView(mode: .edit(p)) { updated in
                    profiles.update(updated)
                } onDelete: { profile in
                    editProfile = nil          // close the editor sheet
                    profiles.remove(profile)
                    navPath = []  // pop the (now-deleted) detail page
                }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(item: $worldsProfile) { p in
                ChildWorldsView(profileID: p.id)
                    .environmentObject(profiles)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showingFeedback) {
                ParentFeedbackView()
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
            .onAppear {
                refreshTrigger &+= 1
                lastRefreshed = .now
                remote.refreshNow()   // pull fresh child state on open
                choreStore.startIfNeeded()   // 🧹 live chores + approval banner
                // ☀️ September: a full-screen "great school year" party on the
                // parent side too (Rani) — once per school year.
                if isRoot, SchoolYearCelebration.shouldGreetParent, !rows.isEmpty {
                    showSchoolYearParty = true
                } else if isRoot, WhatsNewContent.shouldShow {
                    // ✨ Once per app UPDATE: what's new, in parent language.
                    showWhatsNew = true
                }
                rescheduleInsights()
                WidgetBridge.writeFamily(rows)   // keep the family home-screen widget fresh
                pushWatchGlance()                // ⌚️ and the Apple Watch app
                Task {
                    // Parents NEED push — live events and reports are the core
                    // value. Ask AUTOMATICALLY, but only once there's a child to
                    // hear about (context beats a cold login-screen popup, and
                    // the empty dashboard stays prompt-free). iOS shows this
                    // dialog once ever; decliners keep the red banner as the
                    // manual path.
                    if !rows.isEmpty {
                        await PushManager.shared.requestAuthorizationIfNotDetermined()
                    }
                    await push.refreshAuthorizationStatus()
                }
            }
            .onChangeCompat(of: settings.parentInsightFrequency) { _, freq in
                if freq != .off {
                    Task { await PushManager.shared.requestAuthorization() }
                }
                rescheduleInsights()
            }
            // One stable ticker (a .task, not body-recreated Timer publishers):
            // 5s → live 'minutes remaining' countdown; every 20s → re-attach any
            // dropped Firestore listeners so live updates can't silently stall.
            .task(id: isRoot) {
                var elapsed = 0
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if Task.isCancelled { break }
                    refreshTrigger &+= 1
                    lastRefreshed = .now
                    elapsed += 5
                    if elapsed % 20 == 0 { remote.refreshNow() }
                }
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
    /// 🧹 Standing chores row under the two primary buttons — urgent orange
    /// when a kid is waiting for an approval, calm glass otherwise. Always
    /// visible (Rani) so the chores world is one tap away.
    private var choresApprovalBanner: some View {
        let items = choreStore.pendingApproval
        let urgent = !items.isEmpty
        return Button {
            // Jump straight to the child who's waiting; otherwise the first child.
            let target = items.first.flatMap { first in
                profiles.profiles.first(where: { $0.id.uuidString == first.childID })
            } ?? rows.first?.profile
            if let target { choresProfile = target }
        } label: {
            // The dashboard container is forced LTR (cards author .trailing ==
            // right) — so: chevron on the LEFT edge, text block right-aligned,
            // 🧹 on the RIGHT edge, like every other card here.
            HStack(spacing: 10) {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                    .opacity(urgent ? 1 : 0.6)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(urgent
                         ? (items.count == 1 ? "מטלה מחכה לאישור שלכם!" : "\(items.count) מטלות מחכות לאישור שלכם!")
                         : "מטלות הבית")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    if urgent, let first = items.first,
                       let p = profiles.profiles.first(where: { $0.id.uuidString == first.childID }) {
                        Text("\(p.name): \(first.emoji) \(first.title)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .opacity(0.85)
                    } else if !urgent {
                        Text("אין בקשות ממתינות · ניהול מטלות ופרסים")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .opacity(0.8)
                    }
                }
                .multilineTextAlignment(.trailing)
                Text("🧹").font(.system(size: 26))
            }
            .foregroundStyle(urgent ? .white : .primary)
            .padding(12)
            .background(
                Group {
                    if urgent {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "F4A261"), Color(hex: "E76F51")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(urgent ? Color.white.opacity(0.35) : Color(hex: "F4A261").opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

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
                // CENTERED between the icons — the right-hugging text left a
                // lopsided empty gap on the left (Rani, live E2E).
                VStack(alignment: .center, spacing: 2) {
                    Text("הַהַתְרָאוֹת כָּבוּיוֹת")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("הַפְעִילוּ כְּדֵי לְקַבֵּל עֲדְכּוּנִים עַל הַיֶּלֶד")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.md)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            // Same size as "צרו ילד/ה" — prominence comes from a vivid lime→emerald
            // green (distinct from the muted sync teal) plus a brighter glow + border.
            .background(
                LinearGradient(colors: [Color(hex: "3BE36E"), AppColor.successMint],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
            )
            .glow(AppColor.successMint, radius: 16)
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
                    Text("הַמַּכְשִׁיר שֶׁל \(child.name) חוּבַּר! 🎉")
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

                    // Numbered steps — parents missed that Tofy must be
                    // DOWNLOADED on the kid's device first (Rani, live E2E).
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("1️⃣  הוֹרִידוּ אֶת טוֹפִי מֵה־App Store בַּמַּכְשִׁיר שֶׁל \(child.name) (אַיְפֵּד אוֹ אַיְפוֹן)")
                        Text("2️⃣  פִּתְחוּ שָׁם אֶת טוֹפִי וּבַחֲרוּ \"הַמַּכְשִׁיר שֶׁל הַיֶּלֶד\"")
                        Text("3️⃣  סִרְקוּ אֶת הַקּוֹד — וְ\(child.name) נִכְנָס יְשִׁירוֹת לְשַׂחֵק 🎉")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, AppSpacing.lg)

                    ShareLink(item: URL(string: "https://tofyapp.com")!) {
                        Label("שִׁלְחוּ אֶת טוֹפִי לַמַּכְשִׁיר שֶׁל \(child.name)", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(.white.opacity(0.16), in: Capsule())
                    }

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
        .onChangeCompat(of: household.redeemedInviteCode) { _, redeemed in
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
        // Tappable — the family tiles explain themselves like the per-child stats.
        Button {
            Haptic.light()
            statExplain = StatExplain(emoji: emoji, label: label, value: value, isFamily: true)
        } label: {
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
        .buttonStyle(.plain)
    }

    private func profileCard(profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let isActive = profile.id == profiles.activeID
        let live = liveWindow(profile)
        let liveSecs = live?.secondsLeft ?? 0
        // A GIFT window's countdown belongs to 💝, not 🎮 — otherwise a kid
        // playing pure gift time looks like he's burning minutes he earned.
        let liveIsGift = live?.isManual ?? false
        let lp = LearningProfile(snapshot: s, enabledTopics: profile.enabledTopics, age: profile.age)
        let engine = InsightsEngine(history: LearningHistoryStore.shared.history(for: profile.id), profile: lp)
        let status = overallStatus(engine: engine, lp: lp, hasData: s.totalAnswered >= 4)
        // This child's effective daily screen-time cap (per-child override, else global).
        let cap = profile.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled, globalMax: settings.maxMinutesPerDay)

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
                    Menu {
                        Button("חֲצִי שָׁעָה") { remoteOpen(profile, 30) }
                        Button("שָׁעָה") { remoteOpen(profile, 60) }
                        Button("שְׁעָתַיִם") { remoteOpen(profile, 120) }
                        Button("4 שָׁעוֹת") { remoteOpen(profile, 240) }
                    } label: {
                        Label("תֵּן דַּקּוֹת מַתָּנָה 💝", systemImage: "gift.fill")
                    }
                    Button {
                        remoteLock(profile)
                    } label: {
                        Label("נְעַל עַכְשָׁיו (מֵרָחוֹק)", systemImage: "lock.fill")
                    }
                    Button(role: .destructive) {
                        revokeGiftProfile = profile
                    } label: {
                        Label("נְעַל וְאַפֵּס דַּקּוֹת מַתָּנָה", systemImage: "gift.circle")
                    }
                    Button {
                        allowAppRemoval(profile)
                    } label: {
                        Label("אַפְשֵׁר מְחִיקַת אַפְּלִיקַצְיוֹת (5 דַּק')", systemImage: "trash")
                    }
                    Button {
                        editProfile = profile
                    } label: {
                        Label("ערוך פרופיל (שם, גיל)", systemImage: "pencil")
                    }
                    Button {
                        choresProfile = profile
                    } label: {
                        Label("מטלות הבית 🧹", systemImage: "checklist")
                    }
                    Button {
                        difficultyProfile = profile
                    } label: {
                        Label("רמת קושי", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        screenTimeProfile = profile
                    } label: {
                        Label("זמן מסך יומי", systemImage: "hourglass")
                    }
                    Button {
                        worldsProfile = profile
                    } label: {
                        Label("עולמות פעילים", systemImage: "square.grid.2x2.fill")
                    }
                    Button {
                        friendsProfile = profile
                    } label: {
                        Label("חברים", systemImage: "person.2.fill")
                    }
                    // Shown only when the child actually set a play-protection
                    // code — the escape hatch for a forgotten code.
                    if profile.hasPlayPIN {
                        Button {
                            pinResetProfile = profile
                        } label: {
                            Label("אפס קוד הגנת זמן", systemImage: "lock.rotation")
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
                                Text("בְּטוֹפִי עַכְשָׁיו")
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
                    // 🎓 The grade drives ALL curriculum content — always visible
                    // here so the parent knows it's right, tappable to change.
                    // Flagged when the CHILD picked it (the kid-side picker).
                    Button { editProfile = profile } label: {
                        HStack(spacing: 4) {
                            Text("🎓").font(.system(size: 10))
                            if profile.grade != nil {
                                Text(Profile.gradeDisplayName(profile.effectiveGrade))
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                if profile.gradeSetByChild {
                                    Text("· נבחרה ע\"י הילד — בדקו")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                            } else {
                                Text("כיתה לא הוגדרה — הגדירו")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                            }
                            Image(systemName: "chevron.left")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(profile.grade == nil || profile.gradeSetByChild
                                         ? AppColor.flameOrange : Color.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(
                            (profile.grade == nil || profile.gradeSetByChild
                             ? AppColor.flameOrange : Color.secondary).opacity(0.12)))
                    }
                    .buttonStyle(.plain)
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

            // LIVE: an open play window right now — green, ticking, with the device.
            liveWindowBanner(profile, compact: false)

            // Stats, grouped so the card reads top-down: TODAY → PLAY MINUTES →
            // PROGRESS. Each group has a tiny caption; every cell stays tappable
            // for its explanation.
            VStack(alignment: .leading, spacing: 10) {
                statGroup("הַיּוֹם") {
                    statCell(emoji: "⏱",
                             value: cap.enabled ? "\(s.minutesEarnedToday)/\(cap.minutes)" : "\(s.minutesEarnedToday)",
                             label: "זמן מסך היום")
                    statCell(emoji: "❓", value: "\(s.answeredToday)", label: "שאלות היום")
                    statCell(emoji: "🎯", value: s.answeredToday > 0 ? "\(Int(Double(s.correctToday) / Double(s.answeredToday) * 100))%" : "—", label: "הצלחה היום")
                }
                // The two pockets side by side, never blurred: what the child
                // EARNED (or the live countdown of an open window) vs what the
                // parent GAVE. Same split as the kid's own home screen.
                statGroup("דַּקּוֹת מִשְׂחָק") {
                    // 🎮 = EARNED wallet only (or the live countdown of an open
                    // EARNED window). A GIFT window's countdown ticks under 💝 —
                    // each pocket shows its own open time, never the other's.
                    let earnedLive = liveSecs > 0 && !liveIsGift
                    let giftLive = liveSecs > 0 && liveIsGift
                    statCell(emoji: "🎮",
                             value: earnedLive ? formatTime(liveSecs) : (s.pendingMinutes > 0 ? "\(s.pendingMinutes)" : "—"),
                             label: earnedLive
                                ? "זמן מסך פתוח"
                                : (profile.gender == .girl ? "דק' שהרוויחה" : "דק' שהרוויח"))
                    statCell(emoji: "💝",
                             value: giftLive ? formatTime(liveSecs) : (giftShownFor(profile, s) > 0 ? "\(giftShownFor(profile, s))" : "—"),
                             label: giftLive ? "זמן מתנה פתוח" : "דק' מתנה מכם")
                }
                statGroup("הִתְקַדְּמוּת") {
                    statCell(emoji: "🔥", value: "\(s.dayStreak)", label: "רצף ימים")
                    statCell(emoji: "⭐", value: s.stars.currencyShort, label: "כוכבים (דירוג)")
                    statCell(emoji: "💎", value: s.diamonds.currencyShort, label: "יהלומים (חנות)")
                }
            }

            // (Friends are managed from the "⋯" menu — "חברים".)

            // The child's play-protection code — full parental transparency: the
            // parent SEES the code (to remind a forgetful kid) and can reset it.
            if profile.hasPlayPIN {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.starGold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("קוד הגנת זמן המשחק")
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        Text("הילד מזין אותו כדי לפתוח את הדקות שצבר")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(profile.playPIN ?? "")
                        .font(.system(size: 19, weight: .heavy, design: .monospaced))
                        .kerning(3)
                    Button("אפס") {
                        pinResetProfile = profile
                    }
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColor.starGold.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppColor.starGold.opacity(0.35), lineWidth: 1))
            }

            // Learning profile — what the Smart Feed has learned about this kid.
            learningProfileCard(for: profile, snapshot: s)

            // Smart difficulty — current per-topic level + where it adapted.
            adaptiveDifficultyCard(for: profile, snapshot: s)

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
                        Image(systemName: "chevron.left").font(.subheadline.weight(.bold))
                        Spacer()
                        Text((household.devicesByChild[profile.id.uuidString]?.isEmpty == false)
                             ? "חַבְּרוּ מַכְשִׁיר נוֹסָף לְ\(profile.name)"
                             : "חַבְּרוּ אֶת הַמַּכְשִׁיר שֶׁל \(profile.name)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Image(systemName: "qrcode")
                            .font(.system(size: 20, weight: .bold))
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
                    Image(systemName: "chevron.left").font(.caption)
                    Spacer()
                    Text("תובנות מלאות")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
                .foregroundStyle(AppColor.gemPurple)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColor.gemPurple.opacity(0.12)))
            }
            .buttonStyle(.plain)

            // Daily cap line (if enabled) — earned-out-of-max + any minutes banked
            // for tomorrow (bonus overflow once the daily cap was full).
            if cap.enabled {
                let maxedOut = s.minutesEarnedToday >= cap.minutes
                HStack(spacing: 6) {
                    Image(systemName: maxedOut ? "flag.checkered" : "timer")
                        .foregroundStyle(maxedOut ? AppColor.flameOrange : .secondary)
                    // When the day's allowance is fully earned, SAY so — a
                    // parent seeing 🎮 "—" next to 240/240 read it as minutes
                    // gone missing. Spell out where new earnings go (tomorrow)
                    // and that the 💝 gift pocket stays open today.
                    Text(maxedOut
                         ? "\(profile.gender == .girl ? "הגיעה" : "הגיע") לתקרה היומית (\(cap.minutes) דק') — מה \(profile.gender == .girl ? "שתרוויח" : "שירוויח") עכשיו נשמר למחר"
                           + ((s.carryOverMinutes ?? 0) > 0 ? " · 🎁 כבר \(s.carryOverMinutes ?? 0)" : "")
                           + (giftShownFor(profile, s) > 0 ? " · 💝 המתנה פתוחה גם היום" : "")
                         : "נצבר היום: \(s.minutesEarnedToday) / \(cap.minutes) דק'"
                           + ((s.carryOverMinutes ?? 0) > 0 ? "  ·  🎁 \(s.carryOverMinutes ?? 0) למחר" : ""))
                        .font(.caption)
                        .foregroundStyle(maxedOut ? .primary : .secondary)
                    Spacer()
                }
            }

            // Two clearly-separated pockets: what the child EARNED vs what the
            // parent GAVE. Give → gift pocket (💝). Take back → earned wallet.
            let giftShown = giftShownFor(profile, s)
            HStack(spacing: 6) {
                Image(systemName: "wallet.pass")
                    .foregroundStyle(.secondary)
                Text("🎮 \(s.pendingMinutes) דק' \(profile.gender == .girl ? "הרוויחה" : "הרוויח") מלמידה  ·  💝 \(giftShown) דק' מתנה מכם")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Quick actions
            HStack(spacing: 10) {
                Button {
                    quickGift(profile: profile, minutes: 10)
                } label: {
                    Text("💝 +10 מתנה")
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
                    Text("−5 מהמורווח")
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

    // MARK: - Child collection tile + per-child detail page

    /// One child as a 2-up collection tile: big avatar, name, mini glance.
    /// Tapping it pushes the full child page.
    /// Side-by-side family view: each child's top strength + interest + trend.
    /// Deliberately NO ranking or sibling competition — just helping the parent
    /// see each child individually.
    private func familyComparison(_ rows: [(profile: Profile, snapshot: ProgressSnapshot)]) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("הַשְׁוָאָה מִשְׁפַּחְתִּית")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("חוֹזְקָה וְעִנְיָן שֶׁל כָּל יֶלֶד — בְּלִי דֵּירוּג וְתַחֲרוּת")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
            ForEach(rows, id: \.profile.id) { row in
                let lp = LearningProfile(snapshot: row.snapshot, enabledTopics: row.profile.enabledTopics, age: row.profile.age)
                let engine = InsightsEngine(history: LearningHistoryStore.shared.history(for: row.profile.id), profile: lp)
                let strength = engine.strengths.first ?? engine.confidenceByTopic.first?.topic
                let interest = engine.gainedInterest.first ?? lp.favorites.first
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Text(engine.learningTrend.label)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if let interest { compChip("עִנְיָן", interest) }
                    if let strength { compChip("חוֹזְקָה", strength) }
                    Text(row.profile.name)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 56, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).fill(.white.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
    }

    private func compChip(_ label: String, _ topic: Topic) -> some View {
        Text("\(topic.emoji) \(topic.displayName)")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(.white.opacity(0.14)))
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }

    private func childCard(profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let isActive = profile.id == profiles.activeID
        let cap = profile.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled, globalMax: settings.maxMinutesPerDay)
        let timeToday = cap.enabled ? "\(s.minutesEarnedToday)/\(cap.minutes)" : "\(s.minutesEarnedToday)"
        let success = s.answeredToday > 0 ? "\(Int((Double(s.correctToday) / Double(s.answeredToday)) * 100))%" : "—"
        // 🎮 shows the EARNED wallet, or the live countdown of an open EARNED
        // window. A GIFT window's countdown ticks under 💝 instead — a kid
        // playing gift time must never look like he's burning earned minutes.
        let live = liveWindow(profile)
        let liveSecs = live?.secondsLeft ?? 0
        let liveIsGift = live?.isManual ?? false
        let earnedLive = liveSecs > 0 && !liveIsGift
        let giftLive = liveSecs > 0 && liveIsGift
        let available = earnedLive ? formatTime(liveSecs) : (s.pendingMinutes > 0 ? "\(s.pendingMinutes)" : "—")
        return VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ProfileAvatarView(profile: profile, size: 62)
                if isChildPlayingNow(profile) {
                    Circle().fill(AppColor.successMint)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }
            Text(profile.name)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
            gridStatusStrip(profile)
            VStack(spacing: 6) {
                HStack(spacing: 6) { miniStat("⏱", timeToday); miniStat("🎯", success) }
                HStack(spacing: 6) { miniStat("⭐", s.stars.currencyShort); miniStat("💎", s.diamonds.currencyShort) }
                // Green ONLY while a window is actually open — frozen time shows
                // its static number in neutral (it isn't ticking or burning).
                HStack(spacing: 6) { miniStat("🎮", available, live: earnedLive); miniStat("🔥", "\(s.dayStreak)") }
                // 💝 Parent gift pocket — kept apart from earned (🎮) even here.
                // An open GIFT window ticks down HERE, green, not under 🎮.
                HStack(spacing: 6) {
                    let gift = giftShownFor(profile, s)
                    miniStat("💝", giftLive ? formatTime(liveSecs) : (gift > 0 ? "\(gift)" : "—"), live: giftLive)
                    Color.clear.frame(maxWidth: .infinity).frame(height: 1)
                }
            }
            .padding(.top, 4)
            // Room for the overlaid "connect a device" pill (see the grid) — a
            // child with NO device is a family stuck mid-onboarding; the next
            // step should come to them, not hide in the detail page (Rani).
            if (household.devicesByChild[profile.id.uuidString] ?? []).isEmpty {
                Color.clear.frame(height: 34)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16).padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(isActive ? AppColor.successMint.opacity(0.6) : .clear, lineWidth: 2)
        )
    }

    /// ⋯ on a grid card: remote open / lock now (the two things a parent reaches
    /// for from the overview), plus open card / reorder / delete.
    private func gridCardMenu(_ profile: Profile) -> some View {
        Menu {
            Menu {
                Button("חֲצִי שָׁעָה") { remoteOpen(profile, 30) }
                Button("שָׁעָה") { remoteOpen(profile, 60) }
                Button("שְׁעָתַיִם") { remoteOpen(profile, 120) }
                Button("4 שָׁעוֹת") { remoteOpen(profile, 240) }
            } label: {
                Label("תֵּן דַּקּוֹת מַתָּנָה 💝", systemImage: "gift.fill")
            }
            Button {
                remoteLock(profile)
            } label: {
                Label("נְעַל עַכְשָׁיו (מֵרָחוֹק)", systemImage: "lock.fill")
            }
            Button(role: .destructive) {
                revokeGiftProfile = profile
            } label: {
                Label("נְעַל וְאַפֵּס דַּקּוֹת מַתָּנָה", systemImage: "gift.circle")
            }
            Divider()
            Button {
                navPath.append(profile.id)
            } label: { Label("פתח כרטיס", systemImage: "rectangle.portrait.and.arrow.right") }
            Button {
                choresProfile = profile
            } label: { Label("מַטְלוֹת הַבַּיִת 🧹", systemImage: "checklist") }
            if rows.count >= 2 {
                Button {
                    showingReorder = true
                } label: { Label("סדר את הילדים", systemImage: "arrow.up.arrow.down") }
            }
            Button(role: .destructive) {
                gridDeleteProfile = profile
            } label: { Label("מחק ילד/ה", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    /// ⌚️ Send the per-child glance to the paired Apple Watch (no-op without
    /// one). Playing-now == an open screen-time window right now.
    private func pushWatchGlance() {
        let glances = rows.map { row -> WatchBridge.ChildGlance in
            let s = row.snapshot
            let playing = (s.unlockEndsAt ?? .distantPast) > Date()
            let pending = choreStore.chores(forChild: row.profile.id)
                .filter { $0.isPendingApproval }.count
            return WatchBridge.ChildGlance(
                id: row.profile.id.uuidString,
                name: row.profile.name,
                emoji: row.profile.gender == .girl ? "👧" : "👦",
                earnedToday: s.minutesEarnedToday,
                playingNow: playing,
                pendingChores: pending,
                moneyBalance: choreStore.moneyBalance(forChild: row.profile.id))
        }
        WatchBridge.shared.pushFamilyGlance(glances)
    }

    // MARK: - Personal greeting (title area)

    /// "בוקר טוב, רני ☀️" — time-of-day + the parent's first name (or a plain
    /// hello for a guest / no name).
    private var greetingLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let (greet, emoji): (String, String) = {
            switch hour {
            case 5..<12:  return ("בֹּקֶר טוֹב", "☀️")
            case 12..<17: return ("צָהֳרַיִם טוֹבִים", "🌤️")
            case 17..<21: return ("עֶרֶב טוֹב", "🌆")
            default:      return ("לַיְלָה טוֹב", "🌙")
            }
        }()
        let first = (auth.displayName ?? "")
            .split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "\(greet)! \(emoji)" : "\(greet), \(first) \(emoji)"
    }

    /// One short line from real family data — picked by priority so it's always
    /// the most interesting true thing right now. nil when there are no kids.
    private var familyMomentLine: String? {
        let theRows = rows
        guard !theRows.isEmpty else { return nil }
        func g(_ p: Profile, _ m: String, _ f: String) -> String { p.gender == .girl ? f : m }

        // 1. Someone has a screen-time window OPEN right now (minutes burning) —
        //    named by its source: gift time (💝) is never dressed up as earned (🎮).
        if let (p, w) = theRows.lazy.compactMap({ r in liveWindow(r.profile).map { (r.profile, $0) } }).first {
            return w.isManual
                ? "\(p.name) \(g(p, "פָּתַח", "פָּתְחָה")) דַּקּוֹת מַתָּנָה עַכְשָׁיו 💝"
                : "\(p.name) \(g(p, "פָּתַח", "פָּתְחָה")) זְמַן מָסָךְ עַכְשָׁיו 🎮"
        }
        // 1b. Someone is inside Tofy right now (learning).
        if let live = theRows.first(where: { isChildPlayingNow($0.profile) }) {
            return "\(live.profile.name) בְּטוֹפִי עַכְשָׁיו — \(g(live.profile, "לוֹמֵד", "לוֹמֶדֶת")) 📚"
        }
        // 2. Best streak in the family (≥3 is worth celebrating).
        if let hot = theRows.max(by: { $0.snapshot.dayStreak < $1.snapshot.dayStreak }),
           hot.snapshot.dayStreak >= 3 {
            return "\(hot.profile.name) בְּרֶצֶף שֶׁל \(hot.snapshot.dayStreak) יָמִים 🔥"
        }
        // 3. Family activity today.
        let questions = theRows.reduce(0) { $0 + $1.snapshot.answeredToday }
        let idle = theRows.filter { $0.snapshot.answeredToday == 0 }
        if questions > 0, idle.count == 1, theRows.count > 1 {
            let kid = idle[0].profile
            return "\(kid.name) עוֹד לֹא \(g(kid, "שִׂחֵק", "שִׂחֲקָה")) הַיּוֹם — אוּלַי לְעוֹדֵד? 💛"
        }
        if questions > 0 {
            return "הַמִּשְׁפָּחָה עָנְתָה עַל \(questions) שְׁאֵלוֹת הַיּוֹם 👏"
        }
        // 4. Quiet day.
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "יוֹם חָדָשׁ, הַרְפַּתְקָאוֹת חֲדָשׁוֹת ✨" : "שֶׁקֶט הַיּוֹם — הַכֹּל בְּסֵדֶר 🌤️"
    }

    // MARK: - Live play window (what's happening RIGHT NOW)

    /// The child's currently OPEN play window, if any: seconds left, which
    /// device it's on, and whether it's a parent grant/gift or earned time.
    /// Derived from the live device rows (windowEndsAt reflects pauses), so it
    /// ticks down each dashboard refresh and vanishes the moment it closes.
    private func liveWindow(_ profile: Profile) -> (secondsLeft: Int, device: ChildDevice, isManual: Bool)? {
        _ = refreshTrigger   // recompute on the 5s tick
        let now = Date().timeIntervalSince1970
        let open = (household.devicesByChild[profile.id.uuidString] ?? [])
            .compactMap { d -> (Int, ChildDevice, Bool)? in
                guard let end = d.windowEndsAt, end > now else { return nil }
                return (Int(end - now), d, d.windowIsManual ?? false)
            }
        return open.max(by: { $0.0 < $1.0 })
    }

    /// The grid card's status strip — ALWAYS present at the same height so every
    /// card in the grid lines up. Live play window → green + ticking countdown;
    /// otherwise a calm neutral line that still says something useful (frozen
    /// time waiting, app open without a window, or simply "not playing now").
    @ViewBuilder
    private func gridStatusStrip(_ profile: Profile) -> some View {
        let live = liveWindow(profile)
        // Gendered — we know each child's gender, so never "משחק/ת".
        let girl = profile.gender == .girl
        let text: String = {
            // No countdown here — the 🎮/💝 stat below already ticks in green.
            if let live { return live.isManual ? "💝 זְמַן מַתָּנָה פָּתוּחַ" : "🎮 זְמַן מָסָךְ פָּתוּחַ" }
            if isChildPlayingNow(profile) { return "בְּטוֹפִי עַכְשָׁיו · \(girl ? "לוֹמֶדֶת" : "לוֹמֵד") 📚" }
            return "לֹא בְּטוֹפִי כָּרֶגַע"
        }()
        HStack(spacing: 6) {
            if live != nil { LivePulseDot() }
            Text(text)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(live != nil ? .white : Color.secondary)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(live != nil
                      ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "22C55E"), Color(hex: "16A34A")],
                                                     startPoint: .leading, endPoint: .trailing))
                      : AnyShapeStyle(Color.primary.opacity(0.05)))
        )
        .glow(live != nil ? Color(hex: "22C55E") : .clear, radius: live != nil ? 6 : 0)
        .animation(.easeInOut(duration: 0.3), value: live != nil)
    }

    /// Green, pulsing "playing NOW" strip: live countdown + the device it's on.
    /// Shown on the grid card (compact) and the detail card (full sentence).
    @ViewBuilder
    private func liveWindowBanner(_ profile: Profile, compact: Bool) -> some View {
        if let live = liveWindow(profile) {
            let deviceLabel = live.device.kind == "ipad" ? "בָּאַיְפֵּד" : (live.device.kind == "iphone" ? "בָּאַיְפוֹן" : "בַּמַּכְשִׁיר")
            let source = live.isManual ? "זְמַן שֶׁנָּתַתֶּם" : (profile.gender == .girl ? "זְמַן שֶׁהִרְוִיחָה" : "זְמַן שֶׁהִרְוִיחַ")
            // Authored RTL explicitly (the detail card is forced LTR): the pulse
            // dot leads on the RIGHT, Hebrew text is right-aligned, device icon
            // trails on the LEFT.
            HStack(spacing: 8) {
                LivePulseDot()
                if compact {
                    Text(live.isManual
                         ? "💝 זְמַן מַתָּנָה פָּתוּחַ · \(formatTime(live.secondsLeft))"
                         : "🎮 זְמַן מָסָךְ פָּתוּחַ · \(formatTime(live.secondsLeft))")
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(live.isManual
                             ? "\(profile.name) \(profile.gender == .girl ? "פָּתְחָה" : "פָּתַח") דַּקּוֹת מַתָּנָה \(deviceLabel) 💝"
                             : "\(profile.name) \(profile.gender == .girl ? "פָּתְחָה" : "פָּתַח") זְמַן מָסָךְ \(deviceLabel) 🎮")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                        Text("נִשְׁאֲרוּ \(formatTime(live.secondsLeft)) דַּקּוֹת · \(source)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .opacity(0.9)
                            .monospacedDigit()
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: live.device.sfSymbol)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 5 : 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: compact ? 10 : AppRadius.medium, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "22C55E"), Color(hex: "16A34A")],
                                         startPoint: .leading, endPoint: .trailing))
            )
            .glow(Color(hex: "22C55E"), radius: compact ? 6 : 10)
            .transition(.scale.combined(with: .opacity))
        }
    }

    /// Invisible host for the root-level alerts (revoke-gift confirm, remote
    /// open/lock confirm, family-tile explanations). Splitting them off the
    /// main body's modifier chain keeps the type-checker happy.
    private var rootAlertsHost: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        // "Lock + revoke gift" confirmation — a real consequence, so it asks.
        // Presented from either menu (root grid ⋯ / detail ⋯).
        .alert(
            revokeGiftProfile.map { "לִנְעֹל וּלְאַפֵּס אֶת דַּקּוֹת הַמַּתָּנָה שֶׁל \($0.name)?" } ?? "",
            isPresented: Binding(get: { revokeGiftProfile != nil && navPath.isEmpty },
                                 set: { if !$0 { revokeGiftProfile = nil } }),
            presenting: revokeGiftProfile
        ) { p in
            Button("נְעַל וְאַפֵּס", role: .destructive) {
                lockAndRevokeGift(p)
                revokeGiftProfile = nil
            }
            Button("בַּטֵּל", role: .cancel) { revokeGiftProfile = nil }
        } message: { p in
            Text(revokeGiftMessage(p))
        }
        // Live status for remote lock / lock+revoke — real send→cloud→device-ack
        // progress. A sheet (not an alert) so it can keep updating while shown.
        .sheet(item: $commandStatus) { req in
            RemoteCommandStatusSheet(request: req)
        }
        // Remote open/lock confirmation on the ROOT — the grid-card ⋯ menu
        // fires these without opening the child's page.
        .alert("שְׁלִיטָה מֵרָחוֹק", isPresented: Binding(
            get: { remoteGrantMsg != nil && navPath.isEmpty },
            set: { if !$0 { remoteGrantMsg = nil } })) {
            Button("הֵבַנְתִּי", role: .cancel) {}
        } message: {
            Text(remoteGrantMsg ?? "")
        }
        // Family-tile explanations present here (root); the per-child stat
        // alert lives on the detail page (dialogs must sit on the visible
        // page). Guarded so both never try to present at once: this one only
        // fires while the grid (root) is showing.
        .alert(
            statExplain.map { "\($0.emoji) \($0.label) — \($0.value)" } ?? "",
            isPresented: Binding(get: { statExplain != nil && navPath.isEmpty },
                                 set: { if !$0 { statExplain = nil } }),
            presenting: statExplain
        ) { _ in
            Button("הבנתי", role: .cancel) { statExplain = nil }
        } message: { s in
            Text(s.text)
        }
    }

    /// The children grid (pulled out of `body` — the type-checker choked on the
    /// full inline expression).
    private var childrenGrid: some View {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12),
                          GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(rows, id: \.profile.id) { row in
                    NavigationLink(value: row.profile.id) {
                        childCard(profile: row.profile, snapshot: row.snapshot)
                    }
                    .buttonStyle(.plain)
                    // ⋯ quick actions right on the card — the two
                    // remote controls (open / lock now) without
                    // opening the child's page. Overlaid on the link
                    // (not inside it) so the tap isn't swallowed.
                    // The grid is forced RTL, so "leading" = right; the ⋯ belongs
                    // on the LEFT corner (away from the avatar's status dot).
                    .overlay(alignment: .topTrailing) {
                        gridCardMenu(row.profile)
                            .padding(8)
                    }
                    // 📱 No device connected yet → the next onboarding step is a
                    // tap away, right on the card. Overlaid (not inside the
                    // NavigationLink) so the tap isn't swallowed by navigation.
                    .overlay(alignment: .bottom) {
                        if isRoot, (household.devicesByChild[row.profile.id.uuidString] ?? []).isEmpty {
                            Button {
                                Haptic.light()
                                qrCode = nil
                                qrChild = row.profile
                            } label: {
                                Label("חַבְּרוּ מַכְשִׁיר", systemImage: "qrcode")
                                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(AppGradient.purpleDream, in: Capsule())
                                    .glow(AppColor.gemPurple, radius: 6)
                            }
                            .buttonStyle(.borderless)
                            .padding(.bottom, 12)
                        }
                    }
                    .contextMenu {
                        Button {
                            navPath.append(row.profile.id)
                        } label: { Label("פתח כרטיס", systemImage: "rectangle.portrait.and.arrow.right") }
                        Button {
                            choresProfile = row.profile
                        } label: { Label("מַטְלוֹת הַבַּיִת 🧹", systemImage: "checklist") }
                        if rows.count >= 2 {
                            Button {
                                showingReorder = true
                            } label: { Label("סדר את הילדים", systemImage: "arrow.up.arrow.down") }
                        }
                        Button(role: .destructive) {
                            gridDeleteProfile = row.profile
                        } label: { Label("מחק ילד/ה", systemImage: "trash") }
                    }
                }
            }
            // RTL so the cards fill right-to-left — with an odd count
            // the lone card sits on the RIGHT, not the left.
            .environment(\.layoutDirection, .rightToLeft)
            .animation(.spring(response: 0.5, dampingFraction: 0.85),
                       value: rows.map(\.profile.id))
    }

    /// One compact stat in a grid card: emoji + value (⏱ time · 🎯 success ·
    /// ⭐ stars · 💎 diamonds · 🎮 available min · 🔥 streak).
    private func miniStat(_ emoji: String, _ value: String, live: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: 13))
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(live ? Color(hex: "15803D") : .primary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(live ? Color(hex: "22C55E").opacity(0.18) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(live ? Color(hex: "22C55E").opacity(0.7) : .clear, lineWidth: 1)
        )
    }

    /// The full per-child page (all stats, insights, settings menu) pushed when a
    /// card is tapped. Reuses the existing `profileCard` and looks the snapshot up
    /// live from `rows`, so it keeps refreshing while open and handles deletion.
    @ViewBuilder
    private func childDetailScreen(for id: UUID) -> some View {
        if let row = rows.first(where: { $0.profile.id == id }) {
            ScrollView {
                profileCard(profile: row.profile, snapshot: row.snapshot)
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 720)
                    .containerWidthLock()
            }
            .noHorizontalBounce()
            .environment(\.layoutDirection, .leftToRight)
            .background(AppGradient.dreamy.ignoresSafeArea())
            .navigationTitle(row.profile.name)
            .navigationBarTitleDisplayMode(.inline)
            // These dialogs live on the DETAIL page (not the root) so they present
            // IN-CONTEXT — at the root they only popped up after navigating back.
            // Delete also pops the page back to the grid.
            .alert(
                resettingProfile.map { "לאפס את ההתקדמות של \($0.name)?" } ?? "",
                isPresented: Binding(get: { resettingProfile != nil },
                                     set: { if !$0 { resettingProfile = nil } }),
                presenting: resettingProfile
            ) { p in
                Button("אפס דקות + ניקוד", role: .destructive) {
                    resetProgress(for: p)
                    resettingProfile = nil
                }
                Button("בטל", role: .cancel) { resettingProfile = nil }
            } message: { _ in
                Text("פעולה זו תאפס דקות משחק שנצברו, ניקוד הסשן, ועונש טעויות. לא ימחק שמות, פרופילים או פריטי קוסמטיקה.")
            }
            // "What does this number mean?" — tapped stat cell explanation.
            .alert(
                statExplain.map { "\($0.emoji) \($0.label) — \($0.value)" } ?? "",
                isPresented: Binding(get: { statExplain != nil && !navPath.isEmpty },
                                     set: { if !$0 { statExplain = nil } }),
                presenting: statExplain
            ) { _ in
                Button("הבנתי", role: .cancel) { statExplain = nil }
            } message: { s in
                Text(s.text)
            }
            .alert(
                pinResetProfile.map { "לאפס את קוד הגנת הזמן של \($0.name)?" } ?? "",
                isPresented: Binding(get: { pinResetProfile != nil },
                                     set: { if !$0 { pinResetProfile = nil } }),
                presenting: pinResetProfile
            ) { p in
                Button("אפס קוד", role: .destructive) {
                    var updated = p
                    // "" (not nil) — deliberate-clear sentinel; survives sync merges.
                    updated.playPIN = ""
                    profiles.update(updated)
                    pinResetProfile = nil
                }
                Button("בטל", role: .cancel) { pinResetProfile = nil }
            } message: { _ in
                Text("הקוד שהילד הגדיר לפתיחת זמן משחק יימחק. הילד יוכל להגדיר קוד חדש מהמכשיר שלו. שימושי כשהקוד נשכח.")
            }
            .alert(
                deletingProfile.map { "למחוק את \($0.name)?" } ?? "",
                isPresented: Binding(get: { deletingProfile != nil },
                                     set: { if !$0 { deletingProfile = nil } }),
                presenting: deletingProfile
            ) { p in
                Button("מחק ילד/ה", role: .destructive) {
                    profiles.remove(p)     // removes locally + from the cloud
                    navPath.removeAll()    // pop back to the family grid
                    deletingProfile = nil
                }
                Button("בטל", role: .cancel) { deletingProfile = nil }
            } message: { _ in
                Text("הילד/ה והנתונים שלו יימחקו מהמשפחה לצמיתות. תוכלו ליצור אותו מחדש בכל עת. מכשיר שמחובר לילד הזה יתנתק.")
            }
            // "Lock + revoke gift" confirmation on the DETAIL page (dialogs must sit
            // on the visible page — on the root it only appeared after popping back).
            .alert(
                revokeGiftProfile.map { "לִנְעֹל וּלְאַפֵּס אֶת דַּקּוֹת הַמַּתָּנָה שֶׁל \($0.name)?" } ?? "",
                isPresented: Binding(get: { revokeGiftProfile != nil && !navPath.isEmpty },
                                     set: { if !$0 { revokeGiftProfile = nil } }),
                presenting: revokeGiftProfile
            ) { p in
                Button("נְעַל וְאַפֵּס", role: .destructive) {
                    lockAndRevokeGift(p)
                    revokeGiftProfile = nil
                }
                Button("בַּטֵּל", role: .cancel) { revokeGiftProfile = nil }
            } message: { p in
                Text(revokeGiftMessage(p))
            }
            // Remote screen-time confirmation — also on the detail page so it shows
            // immediately where the parent tapped, not only after popping back.
            .alert("שְׁלִיטָה מֵרָחוֹק", isPresented: Binding(
                get: { remoteGrantMsg != nil && !navPath.isEmpty },
                set: { if !$0 { remoteGrantMsg = nil } })) {
                Button("הֵבַנְתִּי", role: .cancel) {}
            } message: {
                Text(remoteGrantMsg ?? "")
            }
            // Remove-linked-device confirmation — on the detail page too, since the
            // "remove device" button lives here; on the root it only popped up after
            // navigating back.
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
                Text("המכשיר יתנתק אוטומטית מהילד ויחזור למצב התחלתי (כאילו הותקן מחדש). ההתקדמות בענן נשמרת — כדי לחבר אותו שוב (או לילד אחר), סרקו בו מחדש את ה-QR של הילד הנכון.")
            }
        } else {
            Color.clear.background(AppGradient.dreamy.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func learningProfileCard(for profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let lp = LearningProfile(snapshot: s, enabledTopics: profile.enabledTopics, age: profile.age)
        let favorites = Array(lp.favorites.prefix(3))
        let strong = Array(lp.strong.prefix(3))
        let weak = Array(lp.weak.prefix(3))
        let discovering = Array(lp.discovering.prefix(3))

        // Hebrew labels inflect by gender — pick by this child's gender.
        let g: (String, String) -> String = { profile.gender == .girl ? $1 : $0 }

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
                if !strong.isEmpty   { topicLine(g("חזק ב","חזקה ב"), topics: strong, tint: AppColor.starGold) }
                if !favorites.isEmpty { topicLine(g("אוהב","אוהבת"), topics: favorites, tint: AppColor.successMint) }
                if !weak.isEmpty     { topicLine("כדאי לחזק", topics: weak, tint: AppColor.flameOrange) }
                if !discovering.isEmpty { topicLine(g("מגלה","מגלה"), topics: discovering, tint: AppColor.gemPurple) }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.5))
            )
        }
    }

    /// "רמת קושי חכמה" — the adaptive engine's current per-topic level and where
    /// it has nudged the difficulty up (mastering) or eased it (building
    /// confidence). Framed positively, per the app's tone.
    @ViewBuilder
    private func adaptiveDifficultyCard(for profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let levels = s.topicAdaptiveLevel ?? [:]
        // Topics the child has actually practiced, most-practiced first.
        let topics = profile.enabledTopics
            .filter { (s.topicAnswered[$0.rawValue] ?? 0) >= 1 }
            .sorted { (s.topicAnswered[$0.rawValue] ?? 0) > (s.topicAnswered[$1.rawValue] ?? 0) }
            .prefix(6)
        let g: (String, String) -> String = { profile.gender == .girl ? $1 : $0 }

        if s.totalAnswered >= 4, !topics.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    Spacer()
                    Text("רמת קושי חכמה")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                    Image(systemName: "dial.medium.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.gemPurple)
                }

                ForEach(Array(topics)) { topic in
                    let base = profile.difficulty(for: topic)
                    let level = levels[topic.rawValue] ?? AdaptiveDifficultyEngine.level(for: base)
                    let served = AdaptiveDifficultyEngine.difficulty(forLevel: level)
                    let baseLevel = AdaptiveDifficultyEngine.level(for: base)
                    let dir = adaptiveDirection(level: level, base: baseLevel)
                    HStack(spacing: 8) {
                        Spacer()
                        if let dir { dir.chip }
                        Text(served.displayName)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(AppColor.gemPurple.opacity(0.15)))
                            .overlay(Capsule().stroke(AppColor.gemPurple.opacity(0.4), lineWidth: 1))
                        Text("\(topic.emoji) \(topic.displayName)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }

                if let sentence = adaptiveSentence(for: Array(topics), levels: levels,
                                                   profile: profile, g: g) {
                    Text(sentence)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColor.gemPurple.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColor.gemPurple.opacity(0.2), lineWidth: 1))
            )
        }
    }

    private enum AdaptiveDir {
        case raised, eased
        @ViewBuilder var chip: some View {
            switch self {
            case .raised:
                Label("מאתגר יותר", systemImage: "arrow.up")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(AppColor.successMint.opacity(0.22)))
                    .foregroundStyle(AppColor.successMint)
            case .eased:
                Label("בונה ביטחון", systemImage: "arrow.down")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(AppColor.starGold.opacity(0.22)))
                    .foregroundStyle(Color(hex: "B8860B"))
            }
        }
    }

    private func adaptiveDirection(level: Double, base: Double) -> AdaptiveDir? {
        if level > base + 0.35 { return .raised }
        if level < base - 0.35 { return .eased }
        return nil
    }

    /// One warm, plain-language sentence about the most notable adaptation —
    /// a topic where the system raised the challenge, else one it eased.
    private func adaptiveSentence(for topics: [Topic], levels: [String: Double],
                                  profile: Profile, g: (String, String) -> String) -> String? {
        func dir(_ t: Topic) -> AdaptiveDir? {
            let base = AdaptiveDifficultyEngine.level(for: profile.difficulty(for: t))
            return adaptiveDirection(level: levels[t.rawValue] ?? base, base: base)
        }
        if let raised = topics.first(where: { dir($0) == .raised }) {
            return "\(profile.name) \(g("מתקדם","מתקדמת")) יפה ב\(raised.displayName), אז המערכת התחילה להוסיף שאלות מעט מאתגרות יותר."
        }
        if let eased = topics.first(where: { dir($0) == .eased }) {
            return "ב\(eased.displayName) המערכת הורידה מעט את הקושי כדי לבנות ביטחון והצלחה."
        }
        return nil
    }

    /// "המלצות להורה" — surfaces where the child needs reinforcement (the
    /// topics they get wrong most) plus the CoachingEngine's concrete, low-effort
    /// tips. Only appears once the kid has played enough to have signal.
    @ViewBuilder
    private func coachingCard(for profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        let lp = LearningProfile(snapshot: s, enabledTopics: profile.enabledTopics, age: profile.age)
        let history = LearningHistoryStore.shared.history(for: profile.id)
        let engine = InsightsEngine(history: history, profile: lp)
        let coach = CoachingEngine(childName: profile.name, insights: engine, profile: lp, isGirl: profile.gender == .girl)
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
            Text(":\(label)")
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
                Text(devices.isEmpty ? "אֵין מַכְשִׁירִים מְחוּבָּרִים" : "\(devices.count) מַכְשִׁירִים מְחוּבָּרִים")
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
        return devices.contains { -$0.lastSeenAt.timeIntervalSinceNow < 45 }
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
        // Tappable: every number on the child card explains itself (a parent
        // shouldn't have to guess what "דק' זמינות" or ⭐ vs 💎 mean).
        Button {
            Haptic.light()
            statExplain = StatExplain(emoji: emoji, label: label, value: value)
        } label: {
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
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    /// A captioned row of stat cells — the caption sits on the RIGHT (Hebrew)
    /// above the row, so the three groups on the card read as sections.
    private func statGroup<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(title)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)
            HStack(spacing: 8) { content() }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// Which stat the parent tapped for an explanation.
    struct StatExplain: Identifiable {
        let emoji: String
        let label: String
        let value: String
        var isFamily: Bool = false   // family-summary tile vs a per-child stat
        var id: String { (isFamily ? "family." : "child.") + label }

        /// Plain-Hebrew explanation of what the number means and how it's earned.
        var text: String {
            // Family-level tiles (top of the dashboard) — keyed by label because
            // they share emojis with the per-child stats but sum the whole family.
            if isFamily {
            switch label {
            case "דק' מסך היום":
                return "סך כל דקות זמן המסך שכל הילדים הרוויחו היום ביחד (מכל המכשירים). מתאפס בחצות. לפירוט לכל ילד — פתחו את הכרטיס שלו."
            case "שאלות היום":
                return "כמה שאלות ענו כל הילדים ביחד היום — בכל העולמות, במשחקים ובהרפתקה החכמה. מספר טוב לתחושה כללית של \"היה יום למידה או לא\"."
            case "ילדים פעילים":
                return "כמה מהילדים כבר ענו לפחות על שאלה אחת היום, מתוך כלל הילדים במשפחה. 1/2 = ילד אחד מתוך שניים שיחק היום."
            default: break
            }
            }
            switch emoji {
            case "⏱":
                return "כמה דקות זמן מסך הילד/ה הרוויח/ה היום, מתוך התקרה היומית שקבעתם (המספר אחרי הקו). כל כמה תשובות נכונות מזכות בדקות מסך (היחס נקבע בהגדרות). כשהתקרה מתמלאת (למשל 240/240) — הילד/ה ממשיך/ה ללמוד, אבל דקות חדשות נשמרות למחר (🎁), ו-🎮 יציג \"—\" אם הארנק כבר נוצל. דקות מתנה 💝 אינן כפופות לתקרה."
            case "❓":
                return "כמה שאלות הילד/ה ענה/תה היום — בכל העולמות, במשחקים ובהרפתקה החכמה. מתאפס בחצות."
            case "🎯":
                return "אחוז התשובות הנכונות מתוך כל השאלות של היום. \"—\" = עוד לא ענה/תה היום. מתחת ל-50% לאורך זמן? כדאי להוריד רמת קושי מהתפריט ⋯."
            case "🔥":
                return "כמה ימים ברצף הילד/ה שיחק/ה בטופי (לפחות שאלה אחת ביום). יום שמדלגים עליו מאפס את הרצף — זה מה שמניע לחזור מחר."
            case "⭐":
                return "כוכבים = הדירוג. הם רק עולים ולעולם לא נגמרים — הם מה שקובע את הרמה של הילד/ה ואת המקום בלוח החברים. אי אפשר לבזבז אותם."
            case "💎":
                return "יהלומים = הארנק של החנות. מרוויחים לאט יותר מכוכבים (בערך 1 לתשובה), ומוציאים אותם על דמויות ופריטים בחנות. יורדים כשקונים — זה תקין."
            case "🎮":
                return "דקות משחק שהילד/ה הרוויח/ה מלמידה ועוד לא פתח/ה (הארנק המורווח). דקות שאתם נותנים (💝 מתנה) נשמרות בנפרד ולא נספרות כאן. כשיש חלון פתוח של זמן מורווח — רואים כאן ספירה לאחור (חלון של מתנה סופר תחת 💝). \"—\" = אין דקות ממתינות."
            case "💝":
                return "דקות שאתם נתתם במתנה ועוד לא נפתחו — נשמרות בנפרד לגמרי מהדקות שהילד/ה הרוויח/ה, אותו מספר בכל מכשיר. הילד/ה פותח/ת אותן מתי שרוצה, וכשהמתנה פתוחה — הספירה לאחור מופיעה כאן (ולא ב-🎮). בכל נתינה אפשר לתת עד מה שנשאר עד חצות; מה שלא נוצל נשאר למחר."
            default:
                return "נתון מסכם על הפעילות של הילד/ה בטופי."
            }
        }
    }

    // MARK: - Actions


    /// 💝 Give minutes — the ONE way a parent hands the child time. It lands in
    /// the child's synced gift pocket (same 💝 on every device); the child opens
    /// it when THEY choose — never a surprise unlock on a device they may not
    /// even be holding. Capped per day: you can't give more than there is left
    /// until midnight (a 20:00 gift tops out at 240 min total for today).
    /// Unused gift carries over — the cap is on GIVING, not on holding.
    private func remoteOpen(_ profile: Profile, _ minutes: Int) {
        let (allowed, capLeft) = giftAllowance(for: profile, wanting: minutes)
        guard allowed > 0 else {
            // Only reachable in the last minute before midnight (capLeft == 0).
            Haptic.warning()
            remoteGrantMsg = "עוֹד רֶגַע חֲצוֹת — אֵין מַה לָּתֵת לְהַיּוֹם. מִיָּד אַחֲרֵי חֲצוֹת אֶפְשָׁר לָתֵת שׁוּב."
            return
        }
        Haptic.success()
        remote.giftChildMinutes(childID: profile.id, minutes: allowed)
        refreshTrigger &+= 1
        // Live status sheet: cloud-commit + device-ack for the gift, honestly —
        // replaces the optimistic alert that claimed success before anything
        // actually happened.
        let note = allowed < minutes
            ? "ביקשתם \(minutes) — זה המקסימום שנשאר להיום, עד חצות."
            : nil
        commandStatus = RemoteCommandStatusRequest(profile: profile,
                                                   kind: .gift(minutes: allowed, note: note))
    }

    /// How much of `wanting` may be given RIGHT NOW: each single give is capped
    /// at the minutes left until midnight (22:30 + "שעתיים" → 90), nothing more.
    /// Deliberately NO daily accumulator: the synced given-today counter plus
    /// gifts still in flight to an offline device once summed to a full day and
    /// locked the button while the child had 0 minutes (Rani, 20.8).
    private func giftAllowance(for profile: Profile, wanting: Int) -> (allowed: Int, capLeft: Int) {
        let capLeft = ProgressStore.minutesUntilMidnight()
        return (min(wanting, capLeft), capLeft)
    }

    /// Open a 5-minute app-deletion window on the child's device from afar —
    /// deletion is normally hard-blocked there (Screen Time denyAppRemoval).
    private func allowAppRemoval(_ profile: Profile) {
        Haptic.medium()
        household.allowAppRemovalRemotely(toChildID: profile.id)
        let connected = (household.devicesByChild[profile.id.uuidString]?.isEmpty == false)
        remoteGrantMsg = connected
            ? "נִפְתָּח חַלּוֹן שֶׁל 5 דַּקּוֹת לִמְחִיקַת אַפְּלִיקַצְיוֹת בַּמַּכְשִׁיר שֶׁל \(profile.name) — מִיָּדִי כְּשֶׁטּוֹפִי פָּתוּחַ שָׁם. אַחַר כָּךְ הַנְּעִילָה חוֹזֶרֶת לְבַד."
            : "אֵין כָּרֶגַע מַכְשִׁיר מְחֻבָּר לְ\(profile.name) — הַחַלּוֹן יִפָּתַח בָּרֶגַע שֶׁהַמַּכְשִׁיר יִתְחַבֵּר."
    }

    private func remoteLock(_ profile: Profile) {
        Haptic.warning()
        household.lockRemoteScreenTime(toChildID: profile.id)
        // Live status sheet instead of an optimistic alert: shows the real
        // send → cloud → device-ack chain, and admits honestly when a hop stalls.
        commandStatus = RemoteCommandStatusRequest(profile: profile, kind: .lock(includesGiftRevoke: false))
    }

    /// "נעל ואפס דקות מתנה": remote-lock the child's device(s) AND revoke every
    /// parent-given minute (💝 pocket, ❄️ frozen, an open parent window). Earned
    /// minutes are the child's own — untouched (an open earned window is
    /// stopped-and-banked). Confirmed first — this one IS a consequence.
    private func revokeGiftMessage(_ p: Profile) -> String {
        let earned = p.gender == .girl ? "הִיא הִרְוִיחָה" : "הוּא הִרְוִיחַ"
        return "הַמַּכְשִׁיר יִנָּעֵל עַכְשָׁיו, וְכָל הַדַּקּוֹת שֶׁנְּתַתֶּם (💝 מַתָּנָה, ❄️ שְׁמוּרוֹת, וְחַלּוֹן פָּתוּחַ שֶׁל מַתָּנָה) יִמָּחֲקוּ. הַדַּקּוֹת שֶׁ\(earned) מִלְּמִידָה לֹא נִפְגָּעוֹת."
    }

    private func lockAndRevokeGift(_ profile: Profile) {
        Haptic.warning()
        remote.revokeChildGift(childID: profile.id)
        household.lockRemoteScreenTime(toChildID: profile.id)
        // Live status sheet: lock ack per device + the gift-wipe ack, honestly.
        commandStatus = RemoteCommandStatusRequest(profile: profile, kind: .lock(includesGiftRevoke: true))
        refreshTrigger &+= 1
    }

    private func resetProgress(for profile: Profile) {
        Haptic.warning()
        // Local wipe (covers Kid Mode / a device that IS this child).
        ProgressVault.shared.resetProfile(profile.id)
        // Cloud: a reset COMMAND for the child's device + a direct cloud-state
        // wipe so the dashboard shows zeros now. (A plain pushNow() here was a
        // no-op: it uploads only the ACTIVE profile and ratchet-merges — it can
        // never lower cloud values, so the reset "did nothing".)
        remote.resetChildProgress(childID: profile.id)
        refreshTrigger &+= 1
    }

    /// Quick +/- minute adjustment. Only works on the active profile (the
    /// one with state in memory). For non-active profiles we'd need to
    /// edit the snapshot directly — kept out of v1 to avoid stale-data
    /// races; the parent can switch to that profile first.
    /// 💝 Gift pocket as the parent should see it: the synced value plus any
    /// gift still in flight to the child's device (so a "+10" shows at once).
    private func giftShownFor(_ profile: Profile, _ s: ProgressSnapshot) -> Int {
        // 💝 = the SYNCED gift pocket + any "+N" still in flight. Frozen leftover
        // now lives INSIDE the synced pocket (pauseManualUnlock), so device-row
        // frozenSeconds is NOT added — a stale row from a device that hasn't
        // updated/come online would otherwise double-count or haunt the tile
        // (Dan: 29 real + a phantom 121 from an old-build phone).
        max(0, (s.parentGiftMinutes ?? 0) + remote.pendingGifts[profile.id, default: 0])
    }

    /// 💝 Give minutes — into the child's separate GIFT pocket (never the earned
    /// wallet). Cloud delta-command; the child's device applies it.
    private func quickGift(profile: Profile, minutes: Int) {
        remoteOpen(profile, minutes)   // one path, one cap, one message
    }

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

/// Manual child order for the dashboard grid — a native reorderable list
/// (drag the handles), saved family-wide on "שמור". Sheet, not in-grid
/// drag: LazyVGrid drag-and-drop is flaky across iPhone/iPad + RTL, and a
/// list with handles is what parents already know from iOS.
struct ChildOrderView: View {
    let profiles: [Profile]
    var onSave: ([Profile]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var working: [Profile] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(working) { p in
                        HStack(spacing: 12) {
                            ProfileAvatarView(profile: p, size: 40)
                            Text(p.name)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { from, to in working.move(fromOffsets: from, toOffset: to) }
                } footer: {
                    Text("גררו את הידיות כדי לקבוע את הסדר בלוח. הסדר נשמר לכל ההורים במשפחה.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("סדר הילדים")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שמור") {
                        Haptic.success()
                        onSave(working)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear { if working.isEmpty { working = profiles } }
    }
}

/// A small green dot that breathes — the universal "live" cue.
struct LivePulseDot: View {
    @State private var on = false
    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.35))
                .frame(width: 14, height: 14)
                .scaleEffect(on ? 1.5 : 0.8)
                .opacity(on ? 0 : 0.8)
            Circle().fill(.white).frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { on = true }
        }
    }
}

#Preview {
    ParentDashboardView()
        .environmentObject(ProfileStore.shared)
        .environmentObject(ParentSettings.shared)
        .environmentObject(AuthManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
