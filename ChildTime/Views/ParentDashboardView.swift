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
    @ObservedObject private var transfers = TimeTransferManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var resettingProfile: Profile? = nil
    @State private var deletingProfile: Profile? = nil
    @State private var navPath: [UUID] = []   // pushed child-detail pages (pop on delete)
    @State private var gridDeleteProfile: Profile? = nil   // long-press delete from the grid
    @State private var refreshTrigger = 0
    @State private var lastRefreshed = Date()
    @State private var showingSettings = false
    @State private var showingCreateChild = false
    @State private var showingKidMode = false
    @State private var friendsProfile: Profile?
    @State private var difficultyProfile: Profile?
    @State private var screenTimeProfile: Profile?
    @State private var editProfile: Profile?
    @State private var remoteGrantMsg: String?
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
        // Fixed alphabetical order by name (Hebrew א,ב,ג…) so the list never
        // reshuffles when a child starts/stops playing. Locale-aware compare.
        return mapped.sorted {
            $0.profile.name.localizedCompare($1.profile.name) == .orderedAscending
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
                                linkCallout
                                if !profiles.profiles.isEmpty { kidModeButton }
                            }
                            syncStatusCard
                            insightNotificationsCard
                            if !transfers.pendingForParent.isEmpty { transferApprovalsCard }
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
                                    .contextMenu {
                                        Button {
                                            navPath.append(row.profile.id)
                                        } label: { Label("פתח כרטיס", systemImage: "rectangle.portrait.and.arrow.right") }
                                        Button(role: .destructive) {
                                            gridDeleteProfile = row.profile
                                        } label: { Label("מחק ילד/ה", systemImage: "trash") }
                                    }
                                }
                            }
                            .animation(.spring(response: 0.5, dampingFraction: 0.85),
                                       value: rows.map(\.profile.id))

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
                    Text("מבט-על על המשפחה")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
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
            .sheet(isPresented: $showingKidMode) {
                KidModeEntryView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(item: $friendsProfile) { p in
                ChildFriendsView(childID: p.id.uuidString, childName: p.name)
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
            .alert("פָּתַחְתָּ זְמַן מָסָךְ", isPresented: Binding(
                get: { remoteGrantMsg != nil },
                set: { if !$0 { remoteGrantMsg = nil } })) {
                Button("הֵבַנְתִּי", role: .cancel) {}
            } message: {
                Text(remoteGrantMsg ?? "")
            }
            .sheet(item: $editProfile) { p in
                ProfileEditorView(mode: .edit(p)) { updated in
                    profiles.update(updated)
                } onDelete: { profile in
                    profiles.remove(profile)
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
            .onAppear {
                refreshTrigger &+= 1
                lastRefreshed = .now
                remote.refreshNow()   // pull fresh child state on open
                rescheduleInsights()
                WidgetBridge.writeFamily(rows)   // keep the family home-screen widget fresh
                Task { await push.refreshAuthorizationStatus() }
            }
            .onChangeCompat(of: settings.parentInsightFrequency) { _, freq in
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
            // Safety net every 20s: re-attach any dropped Firestore listeners and
            // re-fetch, so live child updates can't "suddenly stop" until reopened.
            .onReceive(Timer.publish(every: 20, on: .main, in: .common).autoconnect()) { _ in
                remote.refreshNow()
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.xl)
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
                    } label: {
                        Label("פְּתַח זְמַן מָסָךְ עַכְשָׁיו (מֵרָחוֹק)", systemImage: "lock.open.fill")
                    }
                    Button {
                        editProfile = profile
                    } label: {
                        Label("ערוך פרופיל (שם, גיל)", systemImage: "pencil")
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
                statCell(emoji: "⏱",
                         value: cap.enabled ? "\(s.minutesEarnedToday)/\(cap.minutes)" : "\(s.minutesEarnedToday)",
                         label: "זמן מסך היום")
                statCell(emoji: "❓", value: "\(s.answeredToday)", label: "שאלות היום")
                statCell(emoji: "🎯", value: s.answeredToday > 0 ? "\(Int(Double(s.correctToday) / Double(s.answeredToday) * 100))%" : "—", label: "הצלחה היום")
            }
            HStack(spacing: 10) {
                statCell(emoji: "🔥", value: "\(s.dayStreak)", label: "רצף ימים")
                statCell(emoji: "⭐", value: s.stars.currencyShort, label: "כוכבים (דירוג)")
                statCell(emoji: "💎", value: s.diamonds.currencyShort, label: "יהלומים (חנות)")
                statCell(emoji: "🎮", value: s.pendingMinutes > 0 ? "\(s.pendingMinutes)" : (activeUnlockSecs > 0 ? formatTime(activeUnlockSecs) : "—"), label: "דק' זמינות")
            }

            // (Friends are managed from the "⋯" menu — "חברים".)

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
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                    Text("נצבר היום: \(s.minutesEarnedToday) / \(cap.minutes) דק'"
                         + ((s.carryOverMinutes ?? 0) > 0 ? "  ·  🎁 \(s.carryOverMinutes ?? 0) למחר" : ""))
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

    // MARK: - Child collection tile + per-child detail page

    /// One child as a 2-up collection tile: big avatar, name, mini glance.
    /// Tapping it pushes the full child page.
    /// Side-by-side family view: each child's top strength + interest + trend.
    /// Deliberately NO ranking or sibling competition — just helping the parent
    /// see each child individually.
    /// Pending sibling time-transfer requests awaiting this parent's approval.
    private var transferApprovalsCard: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("בַּקָּשׁוֹת הַעֲבָרַת זְמַן 🛒")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("יֶלֶד מְבַקֵּשׁ לְהַעֲבִיר דַּקּוֹת מִשְׂחָק לְאָח — בִּקְנִיָּה אוֹ בְּמַתָּנָה")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
            ForEach(transfers.pendingForParent) { t in
                VStack(alignment: .trailing, spacing: 8) {
                    Text(t.isGift
                         ? "\(t.fromName) רוֹצֶה לָתֵת בְּמַתָּנָה \(t.minutes) דַּקּוֹת לְ\(t.toName) 🎁"
                         : "\(t.toName) רוֹצֶה לִקְנוֹת \(t.minutes) דַּקּוֹת מֵ\(t.fromName)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    HStack(spacing: 10) {
                        Button { transfers.reject(t) } label: {
                            Text("דְּחֵה")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(.white.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Button { transfers.approve(t) } label: {
                            Text("אַשֵּׁר ✅")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(AppColor.textOnLight)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(AppColor.successMint, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Text(t.isGift ? "🎁 חִנָּם" : "💎 \(t.diamondPrice)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).fill(.white.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
    }

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
        let available = s.pendingMinutes > 0 ? "\(s.pendingMinutes)" : "—"
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
            VStack(spacing: 6) {
                HStack(spacing: 6) { miniStat("⏱", timeToday); miniStat("🎯", success) }
                HStack(spacing: 6) { miniStat("⭐", s.stars.currencyShort); miniStat("💎", s.diamonds.currencyShort) }
                HStack(spacing: 6) { miniStat("🎮", available); miniStat("🔥", "\(s.dayStreak)") }
            }
            .padding(.top, 4)
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

    /// One compact stat in a grid card: emoji + value (⏱ time · 🎯 success ·
    /// ⭐ stars · 💎 diamonds · 🎮 available min · 🔥 streak).
    private func miniStat(_ emoji: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: 13))
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
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

    /// Remotely open screen time on the child's device(s) right now.
    private func remoteOpen(_ profile: Profile, _ minutes: Int) {
        Haptic.success()
        household.grantRemoteScreenTime(toChildID: profile.id, minutes: minutes)
        let label = minutes % 60 == 0 ? "\(minutes / 60) שָׁעוֹת" : "\(minutes) דַּקּוֹת"
        let connected = (household.devicesByChild[profile.id.uuidString]?.isEmpty == false)
        remoteGrantMsg = connected
            ? "פָּתַחְתָּ לְ\(profile.name) \(label) שֶׁל זְמַן מָסָךְ. זֶה יִפָּתַח בַּמַּכְשִׁיר שֶׁלּוֹ מִיָּד (אוֹ בָּרֶגַע שֶׁיִּפְתַּח אֶת טוֹפִּי)."
            : "אֵין כָּרֶגַע מַכְשִׁיר מְחֻבָּר לְ\(profile.name) — הַפְּתִיחָה תֻּחַל בָּרֶגַע שֶׁיִּתְחַבֵּר."
    }

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
