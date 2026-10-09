import SwiftUI
import Combine
import UIKit
import StoreKit

/// Dashboard the parent opens from Parent Settings — shows every profile
/// (every kid in the family) with their current time / score / progress
/// at a glance, with reset actions.
///
/// v1 reads from local UserDefaults (works without any account). v2 will
/// layer Firestore sync on top so the dashboard reflects state even when
/// the kid is on a different device.
struct ParentDashboardView: View {
    /// 📐 Wide & short (the open foldable) lays the children out two across.
    @ObservedObject private var display = DisplayGeometry.shared
    /// Split out of `.alert(…)`: inline, the translated title made the modifier
    /// chain too slow for the type checker.
    private var revokeGiftTitle: String {
        guard let p = revokeGiftProfile else { return "" }
        return tr("לנעול ולאפס את דקות המתנה של \(p.name)?")
    }

    /// When true this is the device's HOME screen (parent device), not a sheet —
    /// so there's no "Done" button and we expose Settings via a gear instead.
    var isRoot: Bool = false
    /// Demo/screenshots only: push the first child's page on appear.
    var demoOpenFirstChild: Bool = false

    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var auth: AuthManager
    @StateObject private var remote = RemoteSyncManager.shared
    @ObservedObject private var push = PushManager.shared
    @ObservedObject private var household = HouseholdManager.shared
    /// 🔔 The bell beside the ⚙️ — everything that happened lately, and its
    /// unread badge. Started from a `.task` AFTER the first frame.
    @ObservedObject private var activity = ActivityFeedStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// 🔄 "there is a newer Tofy" — the ONLY screen allowed to open the App Store.
    @State private var showUpdateSheet = false
    /// Confirm 'lock + revoke all parent-given minutes' (a deliberate act).
    @State private var revokeGiftProfile: Profile? = nil
    @State private var navPath: [UUID] = []   // pushed child-detail pages (pop on delete)
    /// 🎚 The foldable held OPEN: which child the second half of the screen shows.
    /// Closed, the same choice lives in `navPath` — `syncSplit` hands it across
    /// so folding and unfolding never loses the parent's place.
    @State private var selectedChild: UUID? = nil
    /// Did the parent actually pick that child, or did the split just have to
    /// show someone? Only a real choice is pushed when the device folds back.
    @State private var chosenExplicitly = false
    @State private var gridDeleteProfile: Profile? = nil   // long-press delete from the grid
    /// ⚙️ The child's settings list (page 2), opened from the bottom of their page.
    @State private var settingsChild: Profile? = nil
    /// ✏️ The same child settings, opened straight from the HOME (the card's
    /// name, or ⚡ → עריכה). Its own state: the detail page binds `settingsChild`,
    /// and on the Duo both can be on screen at once.
    @State private var homeSettingsChild: Profile? = nil
    /// ⏱ The child's daily screen-time limit, straight from the actions menu —
    /// it was three taps deep in the child's settings (Rani: hard to find).
    @State private var screenTimeChild: Profile? = nil
    /// ⚡ The short actions window (replaced the 14-item menu, 2026-10-08).
    @State private var actionsChild: Profile? = nil
    /// ✏️ The pencil by the name edits the child — name, photo, grade.
    @State private var editChild: Profile? = nil
    @State private var showFamilyNameEditor = false
    @State private var familyNameDraft = ""
    @State private var showingReorder = false               // manual child order sheet
    @State private var statExplain: StatExplain? = nil      // tapped-stat explanation
    @State private var refreshTrigger = 0
    @State private var lastRefreshed = Date()
    @State private var showingSettings = false
    @State private var showingActivity = false      // 🔔 the activity centre
    @State private var showingCreateChild = false
    @State private var showingLocation = false
    @State private var showingKidMode = false
    /// Kid Mode straight for one child (from the card's ⚡ menu).
    @State private var kidModeChild: Profile? = nil
    /// 🧒 "לשחק כאן" on a child's card — Kid Mode starts for that child with no
    /// picker and no second button in between.
    @State private var kidModeStart: Profile? = nil
    @State private var choresProfile: Profile?    // 🧹 chores sheet
    @State private var showSchoolYearParty = false
    @State private var showWhatsNew = false
    /// 📖 The "מה חדש" STORY that opens by itself after an update. Captured
    /// when it is decided to show, because showing it also MARKS the build as
    /// seen — reading the list again afterwards would come back empty.
    @State private var whatsNewStory: [StoryItem] = []
    @State private var showWhatsNewStory = false
    /// 🧭 The first-run tour of this screen (band ג of the onboarding mockup).
    @State private var parentTourActive = false
    /// 🎁 "קיבלתם את טופי+ במתנה" — once, when the family's gift opens.
    @State private var showGiftWelcome = false
    /// 🚀 Band ב: "does this child have a device of their own?"
    @State private var deviceQuestionChild: Profile? = nil
    // 🧭 The new-parent flow (`ParentOnboarding`): ③ the QR that waits for the
    // lock, the "הכל מוכן" moment, and the "play now?" offer after the tour.
    @State private var onbConnectChild: Profile? = nil
    @State private var onbDone: OnboardingFinish? = nil
    @State private var playOfferChild: Profile? = nil
    /// The checklist reads its answers from local defaults; this nudges a re-read.
    @State private var setupTick = 0

    @State private var showingPaywall = false
    /// Apple's own "manage subscription" sheet — where an existing subscriber
    /// belongs, instead of being shown the purchase page again.
    @State private var showingManageSubscription = false
    @State private var paywallSource = "card"
    /// ⚽ A question pack page (parent-side purchase flow).
    @State private var packToShow: QuestionPack? = nil
    /// The child whose request opened the pack page (preselected there).
    @State private var packRequestChild: Profile? = nil
    @ObservedObject private var campaigns = CampaignTracker.shared
    @ObservedObject private var subs = SubscriptionManager.shared
    @ObservedObject private var parentHelp = ParentHelpManager.shared
    @ObservedObject private var location = LocationSharing.shared
    /// 📍 The map opens on this child (card line / ⚡ menu / arrival push).
    @State private var locationChild: String?
    @AppStorage("location.introDismissed") private var locationIntroDismissed = false
    @StateObject private var choreStore = ChoreStore.shared
    @State private var remoteGrantMsg: String?
    /// Live remote-lock status sheet — real send/ack progress, not a static alert.
    @State private var commandStatus: RemoteCommandStatusRequest?
    @State private var showingFeedback = false
    /// 💬 Live support chat (the old feedback form's successor).
    @ObservedObject private var support = SupportChatStore.shared
    @State private var qrChild: Profile? = nil
    @State private var qrCode: String? = nil
    /// 📱 "This iPad is the child's" — opened from the QR sheet on a parent iPad.
    @State private var convertChild: Profile? = nil
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
            // 📅 "Today" counters from ANOTHER day read as today's (Eli, 9.10: "5
            // שאלות היום" from the 6th, for a child who hadn't played). The child's
            // device rolls them over only when it next plays — so a child who
            // didn't play today shows zeros here. Display only; the stored
            // snapshot is untouched.
            snap = snap.todayCountersForDisplay()
            // Fold in any parent minute grant still in flight to the child's device,
            // so a +10/−5 shows immediately and doesn't appear to "revert".
            let adj = remote.pendingAdjustments[row.profile.id, default: 0]
            if adj != 0 { snap.pendingMinutes = max(0, snap.walletMinutesShown + adj) }
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

    // MARK: - 🎚 iPhone Duo: the rail, and the half the fold reveals

    /// The parent's home owns the bar strip (see `SideRailContainer`). Only at
    /// the root — a pushed page has its own back button up there.
    private var useRail: Bool { isRoot && display.hasRail && (splitOpen || navPath.isEmpty) }

    /// Held open: the home column keeps its width and the revealed half shows
    /// one child. Nothing moves between the two states — the screen just grows.
    private var splitOpen: Bool { isRoot && display.hasBarStrip && display.isWideShort }

    /// The home column keeps a phone's width, so folding back changes nothing
    /// about it. Measured on the Duo: its outer screen's safe width is 382pt.
    /// Clamped, so a future foldable with other proportions still splits sanely.
    private func homeColumnWidth(for width: CGFloat) -> CGFloat {
        min(382, max(300, width * 0.55))
    }

    var body: some View {
        // ONE tree for both poses, so the home column keeps its identity (its
        // scroll position, its navigation) across a fold, and the change can
        // animate instead of swapping one screen for another.
        //
        // Laid out PHYSICALLY: the home column belongs beside the rail, on the
        // bar's own side of the glass, in Hebrew as in English. Both widths are
        // handed out from the measured container — a `.frame(maxWidth:
        // .infinity)` pane claimed the whole proposal and then the column was
        // added on top, stretching the root to 1165pt on a 951pt screen.
        GeometryReader { geo in
            // Decided from THIS layout's size, not the published one: the
            // published size lands a frame later, and that frame drew the home
            // full width — which then animated back into its column, every card
            // reflowing on top of the next (recorded on the Duo).
            let open = isRoot && display.hasBarStrip
                && geo.size.width >= DisplayGeometry.wideWidth
                && geo.size.height < DisplayGeometry.shortHeight
            // The column keeps the closed glass's width: a phone column, plus
            // the strip it now runs into when there is no rail.
            let column = homeColumnWidth(for: geo.size.width) + (display.hasRail ? 0 : display.barInset)
            let home = open ? min(column, geo.size.width * 0.6) : geo.size.width
            // With a rail, the strip is handed back on the bar's own side;
            // without one (Rani's call) the home column runs to the edge and
            // only its top row keeps clear of the clock.
            let strip = display.hasRail ? display.barInset : 0
            let rest = open ? max(0, geo.size.width - strip - home) : 0
            HStack(spacing: 0) {
                if display.barOnLeft {
                    if open && strip > 0 { Color.clear.frame(width: strip) }
                    homePane(width: home).zIndex(1).environment(\.inSplitColumn, open)
                    if open { revealedPane(width: rest) }
                } else {
                    if open { revealedPane(width: rest) }
                    homePane(width: home).zIndex(1).environment(\.inSplitColumn, open)
                    if open && strip > 0 { Color.clear.frame(width: strip) }
                }
            }
            // 🎞 No animation of our own across a fold. The system already
            // animates it — on fold it keeps the home column (the half that
            // becomes the outer screen) and blurs the rest away; on unfold it
            // cross-fades into our first frame. A slide of our own ran UNDER
            // that cross-fade and left the child's half empty for ~0.7s
            // (recorded on the Duo). So the first frame at the new size is
            // already the finished layout, and the system's transition does
            // the rest — the same in both directions.
        }
        .environment(\.layoutDirection, .leftToRight)
        .overlay { parentRail }
        .onAppear { syncSplit(open: splitOpen) }
        // Watch the split itself, not the width: the strip and the width are
        // published separately, and the first frame has neither.
        .onChangeCompat(of: splitOpen) { _, open in syncSplit(open: open) }
        // The children arrive from the cloud after the first layout — the open
        // half must not sit empty waiting for a tap that already happened.
        .onChangeCompat(of: rows.map(\.profile.id)) { _, ids in
            guard splitOpen else { return }
            if selectedChild == nil || !ids.contains(where: { $0 == selectedChild }) {
                selectedChild = ids.first
                chosenExplicitly = false
            }
        }
    }

    private func homePane(width: CGFloat) -> some View {
        // 🧱 Type-erased, like the rest of the home — see `dashboardStack`.
        AnyView(dashboardStack)
            .frame(width: width)
            .environment(\.layoutDirection, .app)
    }

    /// What the fold reveals: the selected child's page, exactly the page a tap
    /// opens when the device is closed — same view, same actions, no second
    /// design to keep in step.
    private func revealedPane(width: CGFloat) -> some View {
        Group {
            if let id = selectedChild ?? rows.first?.profile.id {
                childDetailScreen(for: id)
            } else {
                Color.clear.background(GlassBackdrop().ignoresSafeArea())
            }
        }
        .frame(width: max(0, width))
        .frame(maxHeight: .infinity)
        .environment(\.layoutDirection, .app)
    }

    @ViewBuilder private var parentRail: some View {
        if useRail {
            SideRailContainer {
                SideRailButton(systemImage: "gearshape.fill", label: tr("הגדרות")) { showingSettings = true }
                SideRailButton(systemImage: activity.unread > 0 ? "bell.badge.fill" : "bell.fill",
                               label: tr("עדכונים")) { showingActivity = true }
                // ✨ This version's story — the same ring as on the phone's header.
                if !WhatsNewStories.parentStoryForThisVersion.isEmpty {
                    storyRing.frame(width: 46, height: 46)
                }
                SideRailButton(systemImage: "person.badge.plus", label: tr("＋ צרו ילד/ה")) { if !household.refuseIfDisconnected() { showingCreateChild = true } }
                SideRailButton(emoji: "🧹", label: tr("🧹 מטלות")) { openChores() }
                if familyHasChildDevice {
                    SideRailButton(emoji: "📍", label: tr("📍 מיקום")) { showingLocation = true }
                }
                if !rows.isEmpty {
                    SideRailDivider()
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(rows, id: \.profile.id) { row in
                                SideRailAvatar(profile: row.profile,
                                               isSelected: splitOpen && selectedChild == row.profile.id,
                                               isPlaying: (liveWindow(row.profile)?.secondsLeft ?? 0) > 0) {
                                    selectChild(row.profile.id)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    /// One tap on a child, wherever it came from (a card or the rail): open, it
    /// fills the revealed half; closed, it pushes the page as it always has.
    private func selectChild(_ id: UUID) {
        chosenExplicitly = true
        if splitOpen {
            selectedChild = id
        } else if navPath.last != id {
            navPath.append(id)
        }
    }

    /// The device folded or unfolded — carry the parent's place across.
    private func syncSplit(open: Bool) {
        if open {
            if let id = navPath.last { selectedChild = id; chosenExplicitly = true; navPath = [] }
            if selectedChild == nil || !rows.contains(where: { $0.profile.id == selectedChild }) {
                selectedChild = rows.first?.profile.id
                chosenExplicitly = false
            }
        } else {
            // Push only a child the parent actually chose — never the one the
            // open layout had to put somewhere.
            if chosenExplicitly, let id = selectedChild, navPath.isEmpty { navPath.append(id) }
            selectedChild = nil
        }
    }

    /// The chores sheet, opened from the rail as well as the actions row.
    private func openChores() {
        let items = choreStore.pendingApproval
        let target = items.first.flatMap { first in
            profiles.profiles.first(where: { $0.id.uuidString == first.childID })
        } ?? rows.first?.profile
        if let target { choresProfile = target }
    }

    /// 🎁 A tapped offer in the bell's page — the panes that used to live above
    /// the children keep leading exactly where they led before.
    private func openOffer(_ action: ActivityOfferAction) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            switch action {
            case .none:
                break
            case .paywall(let source):
                household.bumpFunnel("parentOpened")
                paywallSource = source
                showingPaywall = true
            case .manageSubscription:
                showingManageSubscription = true
            case .pack(let id, let childID):
                packRequestChild = childID.flatMap { raw in
                    profiles.profiles.first { $0.id.uuidString == raw }
                }
                packToShow = QuestionPacks.find(id) ?? WorldPasses.all.first { $0.id == id }
            case .notificationSettings:
                Task {
                    await PushManager.shared.requestAuthorization()
                    if !PushManager.shared.authorized,
                       let url = URL(string: UIApplication.openSettingsURLString) {
                        await MainActor.run { openURL(url) }
                    }
                }
            }
        }
    }

    /// 🔔 A tapped feed row. The sheet has already dismissed itself; give UIKit
    /// a beat before presenting the next one, or the second sheet is swallowed.
    private func openActivity(_ route: ActivityRoute, _ who: Profile?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            switch route {
            case .chores:
                if let who { choresProfile = who } else { openChores() }
            case .support:
                openSupportChat()
            case .whatsNew:
                // The bell's "גרסה חדשה" row plays THIS version's story — it used
                // to fall back to the newest story table entry, an older build's.
                let story = WhatsNewStories.parentStoryForThisVersion
                if story.isEmpty {
                    showWhatsNew = true
                } else {
                    whatsNewStory = story
                    WhatsNewStories.markParentStoryWatched()
                    showWhatsNewStory = true
                }
            case .child:
                if let who { selectChild(who.id) }
            }
        }
    }

    private var dashboardStack: some View {
        dashboardStackBody
            // 🔌 A blocked action (new child, family name, chat) while the family
            // isn't loaded — the honest answer instead of a dead tap.
            .alert(tr("מתחברים למשפחה…"), isPresented: $household.connectionNotice) {
                Button(tr("נסו שוב")) { household.retryFamilyLoadIfNeeded() }
                Button(tr("הבנתי"), role: .cancel) {}
            } message: {
                Text(tr("הטלפון עדיין לא מחובר למשפחה, אז אי אפשר לעשות את זה כרגע. בדקו שיש אינטרנט — אנחנו מנסים להתחבר שוב לבד."))
            }
    }

    private var dashboardStackBody: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                // A real, branded control center — vibrant, not a grey list.
                GlassBackdrop()

                if profiles.profiles.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            if isRoot {
                                // The approved glass design, one to one (Rani): a
                                // greeting, one card per child, the version line.
                                // No family totals, no big buttons — banners only
                                // when something actually needs the parent.
                                // 🧱 Type-erased: the dashboard's full generic type grew so deep
                                // that instantiating its metadata overflowed the 1 MB main-thread
                                // stack on a real iPhone (build 209 crashed at launch; the
                                // simulator's 8 MB stack hid it). AnyView cuts the nesting.
                                // Its top rows sit beside the foldable's clock —
                                // they stop short of it; the cards run full width.
                                AnyView(homeHeader).clearOfBar()
                                // ⚙️ / ＋ / 🧹 moved into the rail on the Duo.
                                if !useRail { homeActionsRow.clearOfBar() }
                                // 🚀 "עוד קצת וסיימנו" — only while a child's setup
                                // is unfinished (band ב).
                                AnyView(setupChecklist)
                                // Rani: "אני לא רוצה יותר להציג את זה שם" — nothing
                                // promotional or merely informational stacks above the
                                // children any more. Tofy+, the gift journey, a child's
                                // purchase request, the worlds/packs shelf and the
                                // "notifications are off" notice all moved into the 🔔
                                // page (see `ActivityOffers`), and the children's cards
                                // moved up into the space they left.
                                //
                                // What is still allowed here is only what the parent has
                                // to ACT on, and only while they have to:
                                // 🧠 a child stuck on a question RIGHT NOW — live, and
                                // gone again within the hour.
                                ForEach(parentHelp.pendingForParent) { req in helpRequestBanner(req) }
                                // 🧹 a kid finished a chore and cannot get their reward
                                // until someone approves it.
                                if !choreStore.pendingApproval.isEmpty { choresApprovalBanner }
                                // ⏱ Once: the daily screen-time ceiling, per child —
                                // right above the children it is about.
                                if showsDailyCapCard {
                                    DailyCapSetupCard(children: rows.map(\.profile))
                                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                                }
                            }
                            AnyView(childrenGrid)

                            // 📍 Once, for families from before location: what it
                            // is and one tap to it. BELOW the children (Rani: nothing
                            // promotional above them).
                            if showsLocationIntro { locationIntroCard }

                            // Feedback to the team — a plain button BELOW everything
                            // (replaces the floating bubble that overlapped a child
                            // card on smaller screens).
                            if isRoot {
                                // Now opens the live chat (Rani); the old email
                                // form (ParentFeedbackView) stays in the code.
                                Button { openSupportChat() } label: {
                                    Label(tr("פידבק והצעות"), systemImage: "text.bubble.fill")
                                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.75))
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, AppSpacing.sm)
                                .environment(\.layoutDirection, .leftToRight)
                                .accessibilityLabel(tr("שליחת פידבק לצוות"))

                                // Rani: the version, visible, and a tap away from
                                // "what changed in it". The What's New sheet pops
                                // once per version on its own; this is the way back.
                                Button {
                                    Haptic.light()
                                    showWhatsNew = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                                        // Parent-facing: no niqqud (the child's
                                        // side is the only side that gets it).
                                        Text(tr("טופי · \(AppInfo.versionLine)"))
                                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                        Text(tr("· מה חדש?")).font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                    }
                                    .foregroundStyle(.white.opacity(0.75))
                                    .padding(.vertical, 6)
                                    .environment(\.layoutDirection, .leftToRight)
                                }
                                .buttonStyle(.plain)
                                .disabled(WhatsNewContent.releases.isEmpty)
                                .accessibilityLabel(tr("גרסת האפליקציה — הצג מה חדש"))
                            }
                        }
                        .padding(AppSpacing.lg)
                        // The app hands every page the whole glass; the closed
                        // home gives the strip back to its rail. Padding on the
                        // cards, not a safe area — the NavigationStack's
                        // controllers would swallow one — so the backdrop still
                        // runs under the rail. (Open, the split reserves it.)
                        .modifier(RailPaddingUnlessSplit(useRail: useRail))
                        // Room to scroll the last card out from under the 💬 button.
                        .padding(.bottom, showsSupport ? 64 : 0)
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
                    .environment(\.layoutDirection, .appMirrored)
                }
                // 💬 Chat with צוות טופי (+ the team's inbox on Rani's / Amit's phones).
                if showsSupport { supportCorner }
                // 📣 The in-app campaign pop-up — a sheet over the dimmed home.
                if isRoot, let c = campaigns.popup { campaignPopupHost(c) }
            }
            // 🧭 One point per button, once — over the real controls, which
            // mark themselves with `.coachMark`.
            .coachTour(parentTourSteps, forKid: false, isActive: $parentTourActive) {
                CoachTours.markDone(Self.parentTourKey)
                // 🧒 A child who plays on THIS phone: the tour ends with the offer
                // to hand it over right now.
                if let id = ParentOnboarding.offerPlayChildID {
                    ParentOnboarding.offerPlayChildID = nil
                    if let p = profiles.profiles.first(where: { $0.id == id }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playOfferChild = p }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // Keep the title floating over the app gradient. Without this, iOS pops
            // a translucent system material strip behind the inline title the moment
            // the page scrolls — which clashes badly with the gradient on iPad.
            .toolbarBackground(.hidden, for: .navigationBar)
            // Root: no bar at all — the greeting + ⚙️ are in the page (mockup), and
            // an empty bar only pushed the content down. Pushed pages turn it back on.
            .toolbar(isRoot ? .hidden : .visible, for: .navigationBar)
            .navigationTitle(tr("כל הילדים"))   // hidden here; it becomes the pushed page's back label
            .toolbar {
                ToolbarItem(placement: .barSafeTopTrailing) {
                    if isRoot {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(.white)
                        }
                    } else {
                        Button(tr("סיום")) { dismiss() }
                    }
                }
            }
            // Push a full child page when a grid card is tapped (path-based so a
            // delete inside the page can pop back to the grid on its own).
            .onAppear(perform: openFirstChildForDemo)
            .navigationDestination(for: UUID.self) { id in
                childDetailScreen(for: id)
            }
            // Long-press → delete straight from the grid (its own state so it can't
            // clash with the detail page's delete dialog). An `alert` (not a
            // `confirmationDialog`) — the latter is a popover on iPad that, when
            // fired from a context menu, often has no anchor and never appears.
            .alert(
                gridDeleteProfile.map { tr("למחוק את \($0.name)?") } ?? "",
                isPresented: Binding(get: { gridDeleteProfile != nil },
                                     set: { if !$0 { gridDeleteProfile = nil } }),
                presenting: gridDeleteProfile
            ) { p in
                Button(tr("מחיקת ילד/ה"), role: .destructive) {
                    profiles.remove(p)
                    gridDeleteProfile = nil
                }
                Button(tr("בטל"), role: .cancel) { gridDeleteProfile = nil }
            } message: { _ in
                Text(tr("הילד/ה והנתונים שלו יימחקו מהמשפחה לצמיתות. תוכלו ליצור אותו מחדש בכל עת. מכשיר שמחובר לילד הזה יתנתק."))
            }
            .sheet(isPresented: $showingSettings) {
                ParentSettingsView()
                    .environment(\.layoutDirection, .app)
            }
            // 🔔 The activity centre. The sheet closes itself first and hands the
            // destination back here, so a tapped row lands on the real screen.
            .sheet(isPresented: $showingActivity) {
                ActivityCenterView(
                    onOpen: { route, who in openActivity(route, who) },
                    onOffer: { action in openOffer(action) },
                    onPack: { pack in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            packRequestChild = nil
                            packToShow = pack
                        }
                    })
            }
            // 👑 The App Store's own "manage subscription" sheet. It used to hang
            // off the Tofy+ pane on the home; that pane is a row in the bell's
            // page now, so its host lives here, where it is always mounted.
            .manageSubscriptionsSheet(isPresented: $showingManageSubscription)
            .sheet(isPresented: $showingReorder) {
                ChildOrderView(profiles: rows.map(\.profile)) { ordered in
                    household.setChildOrder(ordered.map(\.id))
                }
                .environment(\.layoutDirection, .app)
            }
            // Root-level alerts hosted on an invisible overlay — keeps the main
            // modifier chain small enough for the type-checker.
            .overlay(rootAlertsHost)
            .overlay(paywallHost)
            .overlay(supportSheetHost)
            .sheet(isPresented: $showingKidMode) {
                KidModeEntryView()
                    .environment(\.layoutDirection, .app)
            }
            .sheet(item: $kidModeStart) { p in
                KidModeEntryView(preselected: p.id, autoStart: true)
            }
            .sheet(item: $kidModeChild) { p in
                KidModeEntryView(preselected: p.id)
                    .environment(\.layoutDirection, .app)
            }
            // 🔄 A newer build exists. Shown to the PARENT, with what changed, and
            // the one button in the app that may leave for the App Store.
            .sheet(isPresented: $showUpdateSheet) {
                UpdateAvailableSheet(onUpdate: {
                    showUpdateSheet = false
                    UIApplication.shared.open(AppUpdateConfig.storeURL)
                }, onLater: {
                    AppUpdateConfig.shared.dismissCurrent()   // quiet until the NEXT build
                    showUpdateSheet = false
                })
                // Sized to the offer, not to the screen: `.large` left a third of
                // the sheet empty under three short lines. It can still be dragged
                // up when a release has a long list.
                .presentationDetents([.fraction(0.76), .large])
            }
            .onAppear {
                // Never stack it on "what's new" — that one is about the build they
                // already have, and two sheets on launch is one too many.
                if case .recommended = AppUpdateConfig.shared.state, !showWhatsNew, !showWhatsNewStory {
                    showUpdateSheet = true
                }
            }
            .sheet(isPresented: $showWhatsNew, onDismiss: { WhatsNewContent.markShown() }) {
                WhatsNewView {
                    WhatsNewContent.markShown()
                    showWhatsNew = false
                }
            }
            // 📖 …and the story version, which is what opens BY ITSELF on the
            // first launch after an update. No button leaves it: the last story
            // ends, the cover closes, and the parent is on the home screen.
            .fullScreenCover(isPresented: $showGiftWelcome) {
                GiftWelcomeView(until: household.household?.giftUntil ?? household.household?.premiumUntil ?? Date()) {
                    GiftWelcome.markShown(household.household)
                    showGiftWelcome = false
                }
            }
            // The gift can land while the parent is already here (the hourly
            // engine, or the sign-up trigger a moment after the family exists).
            .onChangeCompat(of: household.household?.giftStartedAt) { _, _ in
                guard isRoot, GiftWelcome.isDue(household.household), !showWhatsNewStory,
                      !showSchoolYearParty, !parentTourActive, !showGiftWelcome else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showGiftWelcome = true }
            }
            .onChangeCompat(of: showGiftWelcome) { _, shown in
                guard !shown, isRoot, !CoachTours.isDone(Self.parentTourKey) else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { startParentTour() }
            }
            .onChangeCompat(of: showWhatsNewStory) { _, shown in
                guard !shown, isRoot, !CoachTours.isDone(Self.parentTourKey) else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { startParentTour() }
            }
            .fullScreenCover(isPresented: $showWhatsNewStory) {
                WhatsNewStoryView(audience: .parent, items: whatsNewStory) {
                    WhatsNewStories.markParentShown()
                    showWhatsNewStory = false
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
                    .environment(\.layoutDirection, .app)
            }
            // 📍 Follow the children's fixes for the cards' location line (no
            // push to their phones — that only happens when the map opens).
            .onAppear { location.follow(childIDs: profiles.profiles.map { $0.id.uuidString }) }
            .onChangeCompat(of: profiles.profiles.map(\.id)) { _, ids in location.follow(childIDs: ids.map(\.uuidString)) }
            .onChangeCompat(of: location.openMapFor) { _, cid in
                guard let cid else { return }
                location.openMapFor = nil
                locationChild = cid; showingLocation = true
            }
            .sheet(isPresented: $showingLocation, onDismiss: { locationChild = nil }) {
                ParentLocationView(focusChildID: locationChild)
                    .environmentObject(profiles)
                    .environment(\.layoutDirection, .app)
            }
            .sheet(isPresented: $showingFeedback) {
                ParentFeedbackView()
                    .environment(\.layoutDirection, .app)
            }
            .sheet(isPresented: $showingCreateChild, onDismiss: {
                // Next step after creating: connect that child's device (skippable).
                // 🚀 …the ONE question first: own device, or the parent's phone?
                if let p = pendingQRChild {
                    pendingQRChild = nil
                    deviceQuestionChild = p
                }
            }) {
                ProfileEditorView(mode: .create) { newProfile in
                    profiles.add(newProfile)
                    HouseholdManager.shared.upsertChild(newProfile)
                    pendingQRChild = newProfile
                } onDelete: { _ in }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .app)
            }
            .sheet(item: $qrChild) { child in
                childQRSheet(for: child)
            }
            .sheet(item: $actionsChild) { p in actionsSheet(p) }
            .sheet(item: $editChild) { p in
                ProfileEditorView(mode: .edit(p)) { updated in
                    profiles.update(updated)
                } onDelete: { removed in
                    editChild = nil
                    profiles.remove(removed)
                }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .app)
            }
            .sheet(item: $screenTimeChild) { p in
                ChildScreenTimeView(profileID: p.id)
                    .environmentObject(profiles)
                    .environmentObject(settings)
                    .environment(\.layoutDirection, .app)
            }
            .sheet(item: $homeSettingsChild) { p in
                ChildSettingsView(profileID: p.id,
                                  snapshot: rows.first(where: { $0.profile.id == p.id })?.snapshot ?? ProgressSnapshot(),
                                  onResetProgress: { resetProgress(for: $0) },
                                  onDelete: { removed in
                                      homeSettingsChild = nil
                                      profiles.remove(removed)
                                  },
                                  onConnectDevice: {
                                      homeSettingsChild = nil
                                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { qrCode = nil; qrChild = p }
                                  },
                                  onLocation: {
                                      homeSettingsChild = nil
                                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                          locationChild = p.id.uuidString; showingLocation = true
                                      }
                                  })
                    .environmentObject(profiles)
                    .environmentObject(settings)
            }
            .sheet(item: $deviceQuestionChild) { p in
                DeviceQuestionView(child: p, onOwnDevice: {
                    SetupProgress.setPlan(.own, p.id)
                    setupTick &+= 1
                    deviceQuestionChild = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        if ParentOnboarding.isActive {
                            onbConnectChild = p
                        } else {
                            qrCode = nil
                            qrChild = p
                        }
                    }
                }, onPlaysHere: {
                    SetupProgress.setPlan(.here, p.id)
                    setupTick &+= 1
                    deviceQuestionChild = nil
                    if ParentOnboarding.isActive {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            onbDone = OnboardingFinish(child: p, playsHere: true)
                        }
                    }
                })
                .presentationDetents([.large])
            }
            .fullScreenCover(item: $onbConnectChild) { p in
                OnboardingConnectView(child: p, onLocked: {
                    onbConnectChild = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        onbDone = OnboardingFinish(child: p, playsHere: false)
                    }
                }, onLater: {
                    // "Later" ends the guided flow; the home's "עוד קצת וסיימנו"
                    // card keeps the unfinished device step, and the gift and
                    // the tour come in their usual order.
                    onbConnectChild = nil
                    ParentOnboarding.finish()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if GiftWelcome.isDue(household.household) { showGiftWelcome = true }
                        else { startParentTour() }
                    }
                })
            }
            .fullScreenCover(item: $onbDone) { done in
                OnboardingDoneView(child: done.child, playsHere: done.playsHere) {
                    ParentOnboarding.finish()
                    if done.playsHere { ParentOnboarding.offerPlayChildID = done.child.id }
                    onbDone = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { startParentTour() }
                }
            }
            .fullScreenCover(item: $playOfferChild) { p in
                PlayNowOfferView(child: p, onPlay: {
                    playOfferChild = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { kidModeStart = p }
                }, onLater: { playOfferChild = nil })
            }

            .sheet(item: $parentHelp.promptedRequest) { req in
                ParentHelpAnswerView(request: req)
            }
            .onAppear {
                refreshTrigger &+= 1
                lastRefreshed = .now
                remote.refreshNow()   // pull fresh child state on open
                choreStore.startIfNeeded()   // 🧹 live chores + approval banner
                parentHelp.startParentListener(householdID: household.household?.id)   // 🧠 open help requests
                // ☀️ September: a full-screen "great school year" party on the
                // parent side too (Rani) — once per school year.
                if AppInfo.isDemoRun {
                    // screenshots / review: nothing pops over the screen
                } else if isRoot, ParentOnboarding.isActive, let first = rows.first?.profile,
                          onbConnectChild == nil, onbDone == nil, deviceQuestionChild == nil, !showingCreateChild {
                    // 🧭 The app closed mid-flow — pick it up where it stopped.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        switch SetupProgress.plan(first.id) {
                        case .here?: onbDone = OnboardingFinish(child: first, playsHere: true)
                        case .own?:
                            let devs = (household.devicesByChild[first.id.uuidString] ?? []).filter { $0.role != "parent" }
                            if devs.contains(where: { $0.shieldAuthorized == true }) {
                                onbDone = OnboardingFinish(child: first, playsHere: false)
                            } else { onbConnectChild = first }
                        case nil: deviceQuestionChild = first
                        }
                    }
                } else if isRoot, SchoolYearCelebration.shouldGreetParent, !rows.isEmpty {
                    // Mark on SHOW, not on dismiss: force-quitting (or any exit
                    // that skipped the dismiss closure) left it unmarked and it
                    // greeted again on the next launch.
                    SchoolYearCelebration.markParentGreeted()
                    showSchoolYearParty = true
                } else if isRoot, GiftWelcome.isDue(household.household) {
                    // 🎁 The family's gift just opened (or was stretched to 30
                    // days) — the parent hears it as a moment, once.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showGiftWelcome = true }
                } else if isRoot, WhatsNewContent.shouldShow {
                    // 📋 Once per update: the short list of what is new. The story
                    // no longer opens by itself on the parent's side (Rani,
                    // 2026.10.7) — it waits behind the ✨ ring by the 🔔.
                    showWhatsNew = true
                } else if isRoot, !rows.isEmpty, household.household != nil,
                          household.familyNameShown == nil, shouldAskFamilyName {
                    // 👪 Families created before sign-up asked for a name. Ask
                    // again weekly while the family is still nameless — the old
                    // once-per-install flag was usually spent on a launch where
                    // What's New won the slot, so most parents never saw it.
                    // Saving a name, or "not now", stops it for good.
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "family.namePromptAt")
                    familyNameDraft = household.suggestedFamilyName ?? ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showFamilyNameEditor = true }
                } else if isRoot, !rows.isEmpty,
                          !CoachTours.isDone(Self.parentTourKey) || CoachTours.forcedInDemo {
                    // 🧭 Nothing else wanted this launch: the tour of the home.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { startParentTour() }
                }
                // 📸 Screenshot runs force the tour, whatever else this launch chose.
                if CoachTours.forcedInDemo, isRoot {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { parentTourActive = true }
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
                    if !rows.isEmpty, !ParentOnboarding.isActive {
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
            // 🔔 The feed, started only once the home screen is up: `start()`
            // attaches ONE household-scoped listener (60 docs) and derives the
            // rest from state already in memory. `Task.yield()` first so not a
            // line of it runs before the first frame.
            .task(id: isRoot) {
                guard isRoot else { return }
                await Task.yield()
                ActivityFeedStore.shared.start()
                await PushManager.shared.sweepDeliveredNotifications()
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
    private func rescheduleInsights() {
        InsightNotificationScheduler.reschedule(
            rows: rows,
            enabledTopics: settings.enabledTopics,
            frequency: settings.parentInsightFrequency
        )
    }
    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("👨‍👩‍👧‍👦")
                .font(.system(size: 64))
            Text(tr("בואו נצרף את הילדים"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("צרו פרופיל לכל ילד/ה כאן. אחר כך כל ילד יקבל קוד QR — סורקים אותו במכשיר של הילד, והוא נכנס ישירות לשחק."))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            linkButton
            if !push.authorized, !ParentOnboarding.isActive {
                notificationsBanner.frame(maxWidth: 460)
            }
        }
        .padding(AppSpacing.lg)
        .onAppear {
            // 🧭 Step ② straight after the parent code — no empty home between.
            guard isRoot, ParentOnboarding.isActive, profiles.profiles.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showingCreateChild = true }
        }
    }

    /// Shown on the parent control screen when notifications are off — taps
    /// re-prompt (if possible) or open iOS Settings.
    /// 🧹 Standing chores row under the two primary buttons — urgent orange
    /// when a kid is waiting for an approval, calm glass otherwise. Always
    /// visible (Rani) so the chores world is one tap away.

    /// 👑 "יואב רוצה טופי+" — the child tapped ask-a-parent on their device. The
    /// subscription is per family and bought here, once; this is the doorway.
    private func campaignPopupHost(_ c: Campaign) -> some View {
        CampaignPopupView(campaign: c, isChild: false, onAct: {
            campaigns.popup = nil
            campaigns.popupTapped(c)
        }, onLater: { campaigns.popup = nil })
    }

    /// 📣 A tapped campaign push lands the parent on the pack page / paywall.
    private func consumeCampaignLanding() {
        if let pid = campaigns.pendingPackID, let pack = QuestionPacks.find(pid) {
            campaigns.pendingPackID = nil
            packRequestChild = nil
            packToShow = pack
        } else if campaigns.pendingScreen == "tofyPlus" {
            campaigns.pendingScreen = nil
            showingPaywall = true
        }
    }

    /// 🧠 "נועה מבקשת עזרה בשאלה" — tap opens the answer sheet.
    private func helpRequestBanner(_ req: HelpRequest) -> some View {
        Button {
            Haptic.light()
            parentHelp.promptedRequest = req
        } label: {
            HStack(spacing: 10) {
                Image(systemName: AppSymbol.forwardChevron).font(.system(size: 14, weight: .bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(req.isGirl ? tr("\(req.childName) מבקשת עזרה בשאלה") : tr("\(req.childName) מבקש עזרה בשאלה"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text(req.question)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(2)
                }
                Text("🧠").font(.system(size: 26))
            }
            .foregroundStyle(GlassInk.primary)
            .padding(14)
            .glassPane(radius: 16, strength: 0.18, tint: Color(hex: "7A5CFF"))
        }
        .buttonStyle(.plain)
    }


    /// ⏱ The one-time "how much screen time a day?" card: a parent's own device
    /// (never a child device or Kid Mode), children to set, not saved before,
    /// and at least one child still without a ceiling of their own — a family
    /// that set every child (the create step, the screen-time editor, or a
    /// co-parent's phone) has nothing left to ask. Demo runs only on its own
    /// DEMO_SCREEN, so every other screenshot stays as it was.
    private var showsDailyCapCard: Bool {
        guard isRoot, !settings.dailyCapCardDone, !profiles.profiles.isEmpty else { return false }
        if AppInfo.isDemoRun { return ChildTimeApp.demoScreen == "dailycapcard" }
        guard settings.deviceRole == .parent, !KidModeManager.shared.active else { return false }
        return profiles.profiles.contains { $0.dailyCapMinutes == nil }
    }

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
                Image(systemName: AppSymbol.forwardChevron).font(.system(size: 14, weight: .bold))
                    .opacity(urgent ? 1 : 0.6)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(urgent
                         ? (items.count == 1 ? tr("מטלה מחכה לאישור שלכם!") : tr("\(items.count) מטלות מחכות לאישור שלכם!"))
                         : tr("מטלות הבית"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    if urgent, let first = items.first,
                       let p = profiles.profiles.first(where: { $0.id.uuidString == first.childID }) {
                        Text("\(p.name): \(first.emoji) \(first.title)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .opacity(0.85)
                    } else if !urgent {
                        Text(tr("אין בקשות ממתינות · ניהול מטלות ופרסים"))
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
                    Text(tr("ההתראות כבויות"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(tr("הפעילו כדי לקבל עדכונים על הילד"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Image(systemName: AppSymbol.forwardChevron).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.8))
            }
            // Bell on the left, chevron on the right in every language (the
            // mirrored container would flip it for English).
            .environment(\.layoutDirection, .leftToRight)
            .padding(AppSpacing.md)
            // Glass with a warm whisper — a notice, not a red slab.
            .glassPane(radius: 16, tint: AppColor.flameOrange)
        }
        .buttonStyle(.plain)
    }

    /// The parent's primary action — create a child profile. Each child then
    /// gets a QR to set up their own device.
    private var linkButton: some View {
        Button {
            Haptic.light()
            guard !household.refuseIfDisconnected() else { return }
            showingCreateChild = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                Text(tr("צרו ילד/ה"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .glow(AppColor.starGold, radius: 12)
        }
        .buttonStyle(.juicy)
        .frame(maxWidth: 460)
    }
    private func childQRSheet(for child: Profile) -> some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 16, size: 12)

            if childDeviceLinked {
                // Auto-shown the moment the child's device joins.
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(AppColor.successMint)
                        .glow(AppColor.successMint, radius: 16)
                    Text(tr("המכשיר של \(child.name) חובר! 🎉"))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.xl)
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: AppSpacing.lg) {
                    Text(tr("חברו את המכשיר של \(child.name)"))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                        .shadow(color: .black.opacity(0.18), radius: 7, y: 2)
                        .multilineTextAlignment(.center)

                    // The QR on a white card (a scanner needs contrast), the code
                    // in a glass chip under it.
                    VStack(spacing: 12) {
                        if let code = qrCode {
                            // Encode a Universal Link so the iPhone's native Camera
                            // can scan it and open Tofy straight into joining.
                            QRCodeView(text: JoinLink.url(forPayload: code), size: 210)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                            Text(String(code.split(separator: "|").first ?? ""))
                                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                                .kerning(4)
                                .foregroundStyle(GlassInk.primary)
                                .padding(.horizontal, 16).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        } else {
                            // Same footprint as the QR card, so the pane doesn't
                            // collapse into a narrow pill while the code loads.
                            ProgressView().tint(.white).scaleEffect(1.3).frame(width: 234, height: 234)
                        }
                    }
                    .padding(16)
                    .glassPane(radius: 16)

                    // Numbered steps — parents missed that Tofy must be
                    // DOWNLOADED on the kid's device first (Rani, live E2E).
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(tr("1️⃣  הורידו את טופי מה־App Store במכשיר של \(child.name) (אייפד או אייפון)"))
                        Text(tr("2️⃣  פתחו שם את טופי ובחרו \"המכשיר של הילד\""))
                        Text(tr("3️⃣  סרקו את הקוד — ו\(child.name) נכנס ישירות לשחק 🎉"))
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .multilineTextAlignment(.trailing)
                    // Step 1 is the longest line and was ending in "…" — the
                    // half that says WHICH device is the half that matters.
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .glassInset(radius: 16)

                    // 🎉 Live on the App Store 2026-10-02 — this pointed at the
                    // marketing site while the listing was still in review.
                    ShareLink(item: URL(string: "https://apps.apple.com/app/id6773805449")!) {
                        Label(tr("שלחו את טופי למכשיר של \(child.name)"), systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    }

                    // 📱 On a parent iPad the "child's device" is very often THIS
                    // iPad (the parent set it up first). Offer the one-tap fix.
                    if qrSheetOffersConvert {
                        Button {
                            Haptic.light()
                            convertChild = child
                        } label: {
                            Label(child.gender == .girl
                                  ? tr("האייפד הזה של \(child.name)? להפוך אותו למכשיר שלה")
                                  : tr("האייפד הזה של \(child.name)? להפוך אותו למכשיר שלו"),
                                  systemImage: "ipad")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.juicy)
                    }

                    Button(tr("סגור")) { closeQRSheet() }
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3FBF"))
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.92)))

                    Text(tr("אפשר לדלג ולחבר את המכשיר אחר כך — מהמסך הראשי."))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: 460)
            }
        }
        .sheet(item: $convertChild) { kid in
            NavigationStack {
                ConvertToChildDeviceView(preselectedChildID: kid.id) {
                    convertChild = nil
                    closeQRSheet()
                }
                .toolbar {
                    ToolbarItem(placement: .barSafeTopTrailing) {
                        Button(tr("סגור")) { convertChild = nil }
                    }
                }
            }
            .environmentObject(profiles)
            .environment(\.colorScheme, .dark)
            .environment(\.layoutDirection, .app)
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

    /// The device (not the size class) is an iPad acting as a parent device.
    private var qrSheetOffersConvert: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && settings.deviceRole == .parent
            && !KidModeManager.shared.active
    }

    private func closeQRSheet() {
        HouseholdManager.shared.stopWatchingInviteRedemption()
        qrChild = nil
        qrCode = nil
        childDeviceLinked = false
    }

    // MARK: - Child collection tile + per-child detail page
    private func childCard(profile: Profile, snapshot s: ProgressSnapshot) -> some View {
        // Rani: the overview answers ONE question per child — "is my kid using it
        // and learning?" — in a few seconds. Minutes of the daily max, questions,
        // correct, and the live state. No stars/diamonds/flames here; those are
        // the child's, on the child's screen.
        let cap = profile.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled, globalMax: settings.maxMinutesPerDay)
        let girl = profile.gender == .girl
        let live = liveWindow(profile)
        let liveSecs = live?.secondsLeft ?? 0
        let playing = liveSecs > 0
        let pct = s.answeredToday > 0 ? Int((Double(s.correctToday) / Double(s.answeredToday) * 100).rounded()) : nil
        let hasDevice = childHasDevice(profile)
        let showStats = hasDevice || s.totalAnswered > 0 || s.answeredToday > 0
        let state: String = {
            if playing { return tr("\(girl ? tr("משחקת") : tr("משחק")) עכשיו · נשארו \(formatTime(liveSecs))") }
            if isChildPlayingNow(profile) { return tr("בטופי עכשיו · \(girl ? tr("לומדת") : tr("לומד"))") }
            // 🏫🌙 The hours the parent set aside, while they are on.
            if hasDevice, let q = profile.quietHours?.active(at: Date()) {
                let at = QuietHoursManager.clock(q.end)
                return q.kind == .school ? tr("🏫 זמן בית ספר עד \(at)") : tr("🌙 שעת שינה עד \(at)")
            }
            // A child with no device of their own still plays in kid mode on this phone.
            if !hasDevice && s.answeredToday == 0 && s.stars == 0 { return tr("עוד לא \(girl ? tr("התחילה") : tr("התחיל"))") }
            return s.answeredToday > 0 ? tr("\(girl ? tr("למדה") : tr("למד")) היום") : (girl ? tr("לא הייתה בטופי היום") : tr("לא היה בטופי היום"))
        }()
        return VStack(spacing: Self.homeRowGap) {
            HStack(spacing: 12) {
                ProfileAvatarView(profile: profile, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(profile.name)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.7)
                        // ✏️ The name and avatar open this child's settings —
                        // the same pencil the family name already wears.
                        if isRoot { Text("✏️").font(.system(size: 13)).opacity(0.75) }
                    }
                    HStack(spacing: 6) {
                        Circle().fill(playing || isChildPlayingNow(profile) ? Color(hex: "5CFF9D") : Color.white.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text(state)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.secondary).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 4)
                Text("\(pct ?? 0)%")   // Rani: a zero is a zero, never a dash
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    // Green from 80 % at ANY count (Rani: 100 % must read green),
                    // amber 60–79, warm below — but those two only once there are
                    // 6 answers to judge by (2/3 is not "red"); until then plain white.
                    .foregroundStyle((pct ?? 0) >= 80 && s.answeredToday > 0 ? GlassInk.good
                                     : s.answeredToday < 6 ? GlassInk.primary
                                     : (pct ?? 0) >= 60 ? GlassInk.warn : GlassInk.weak)
            }
            // 📍 Where the child is, one tap from the map.
            if let f = location.shownFix(profile.id.uuidString) {
                let fresh = Date().timeIntervalSince1970 - f.at < 600
                Button {
                    Haptic.light(); locationChild = profile.id.uuidString; showingLocation = true
                } label: {
                    let place = location.whereParts(f)
                    HStack(spacing: 8) {
                        Text(place.icon).font(.system(size: 15))
                        Text(place.text)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(ParentLocationView.relative(f.at, now: Date()))
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(fresh ? Color(hex: "9FF5DD") : GlassInk.secondary)
                        Image(systemName: AppSymbol.forwardChevron).font(.system(size: 12, weight: .bold)).foregroundStyle(GlassInk.tertiary)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(minHeight: 40)
                    .background((fresh ? Color(hex: "06D6A0").opacity(0.22) : Color.white.opacity(0.12)),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(fresh ? Color(hex: "5CFF9D").opacity(0.7) : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            // 📊 The tiles for every child who plays — on a device of their own
            // OR in kid mode on this phone (Rani: Uri played here and his card
            // showed nothing).
            if showStats {
                HStack(spacing: 8) {
                    // "דקות היום" meant two different numbers on the two screens —
                    // here minutes EARNED by learning today, on the kid's own home
                    // the wallet. A parent watching a 30-minute gift window run saw
                    // "0 דקות היום" and reasonably thought something was broken.
                    overviewStat(value: "\(s.minutesEarnedToday)",
                                 suffix: cap.enabled ? "/\(cap.minutes)" : nil,
                                 // "Earned", said out loud: a parent read "60/60 דקות היום"
                                 // as "played 60 of 60" (Ben David, 2026-10-08).
                                 label: girl ? tr("דקות שהרוויחה היום") : tr("דקות שהרוויח היום"),
                                 progress: nil)   // no filling bar (Rani)
                    overviewStat(value: "\(s.answeredToday)", suffix: nil, label: tr("שאלות היום"), progress: nil)
                    overviewStat(value: "\(s.correctToday)", suffix: nil, label: tr("נכונות"), progress: nil)
                }
                .fixedSize(horizontal: false, vertical: true)   // all three tiles as tall as the one with the bar (Rani)
            }
            if hasDevice {
                // The buttons sit on the tiles' grid (Rani): "מידע נוסף" spans
                // the first two tiles and the gap between them, ⚡ (overlaid
                // by the grid — a Menu inside a link would swallow the tap) is
                // exactly the third tile.
                GeometryReader { g in
                    let t = Self.tileWidth(innerWidth: g.size.width)
                    HStack(spacing: Self.tileGap) {
                        homePrimaryLabel(tr("מידע נוסף ←")).frame(width: t * 2 + Self.tileGap)
                        Color.clear.frame(width: t, height: 1)
                    }
                }
                .frame(height: Self.homeControlHeight)
                // 🧒 Its own full-width row, in a whole sentence: this is the
                // thing parents wrote in about and it earns the space (Rani).
                Color.clear.frame(maxWidth: .infinity).frame(height: Self.homeControlHeight)
            } else {
                // No device yet. This card used to end here — one dead line — so
                // a child without a device had NO actions menu and no way into
                // their page (Rani). That hid exactly the things a parent needs
                // then: connect a device, or hand them the parent's own phone.
                if !showStats {
                HStack(spacing: 6) {
                    Text(tr("\(Profile.gradeNameForParent(profile.effectiveGrade)) · אין עדיין מכשיר מחובר."))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                }
                // מידע נוסף · חברו מכשיר · פעולות, side by side (Rani): connecting
                // used to REPLACE "מידע נוסף", and a row of its own grew the card.
                // "חברו מכשיר" and ⚡ are overlaid into their slots by the grid
                // (a Button inside the NavigationLink would swallow the tap).
                // Three columns on the same grid as the tiles of a card with a
                // device, so ⚡ sits in the same place on every card.
                GeometryReader { g in
                    let t = Self.tileWidth(innerWidth: g.size.width)
                    HStack(spacing: Self.tileGap) {
                        homePrimaryLabel(tr("מידע נוסף ←")).frame(width: t)
                        Color.clear.frame(width: t, height: 1)
                        Color.clear.frame(width: t, height: 1)
                    }
                }
                .frame(height: Self.homeControlHeight)
                Color.clear.frame(maxWidth: .infinity).frame(height: Self.homeControlHeight)
            }
        }
        .padding(14)
        .foregroundStyle(GlassInk.primary)
        .glassPane(radius: 16, strength: hasDevice ? 0.14 : 0.09)
        .environment(\.layoutDirection, .app)
    }

    /// The three stat tiles' grid, which the buttons under them follow.
    static let tileGap: CGFloat = 8
    static let cardPadding: CGFloat = 14
    static func tileWidth(innerWidth w: CGFloat) -> CGFloat { max(0, (w - tileGap * 2) / 3) }
    /// The same column, measured from the whole card (the overlays see the card).
    static func tileWidth(cardWidth w: CGFloat) -> CGFloat { tileWidth(innerWidth: w - cardPadding * 2) }


    private func childHasDevice(_ profile: Profile) -> Bool {
        !(household.devicesByChild[profile.id.uuidString] ?? []).isEmpty
    }

    /// `.btn.primary` from the mockup: white pill, indigo ink.
    private func homePrimaryLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: "4B3FBF"))
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: Self.homeControlHeight)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// `.btn.ghost` from the mockup: stronger glass, white ink.
    /// Every control in a child card's action rows is this tall, so "מידע נוסף"
    /// and "פעולות" can never end up different heights (Rani).
    static let homeControlHeight: CGFloat = 42
    /// The gap between a card's rows. The ⚡ menu and "+ חברו מכשיר" are laid
    /// OVER the card (a Menu inside the NavigationLink swallows taps), so they
    /// are placed by arithmetic — with 8 here while the card stacked its rows
    /// 12 apart, "פעולות" sat 4pt below "מידע נוסף" and read as a different
    /// size (Rani: "חשבתי שסידרנו את הגדלים של הכפתורים"). One number now.
    static let homeRowGap: CGFloat = 12

    private func homeGhostLabel(_ text: String, width: CGFloat? = nil) -> some View {
        Text(text)
            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
            .foregroundStyle(GlassInk.primary)
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(height: Self.homeControlHeight)
            .padding(.horizontal, width == nil ? 8 : 0)
            .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.30), lineWidth: 1))
    }

    /// Right under the greeting (Rani: "תן לילד לשחק / צור ילד / מטלות — איפה?"):
    /// the three things a parent does that aren't about one child's card.
    /// A family with a child's own device, nobody sharing yet, card not closed.
    /// Any child in the family with a device of their own — the only case
    /// where location means anything.
    private var familyHasChildDevice: Bool {
        profiles.profiles.contains { childHasDevice($0) }
    }

    private var showsLocationIntro: Bool {
        !locationIntroDismissed && rows.contains { childHasDevice($0.profile) }
            && !rows.contains { location.sharing[$0.profile.id.uuidString] == true }
    }

    private var locationIntroCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("📍").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("חדש: לדעת איפה הילדים"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                Text(tr("מפה, התראה כשמגיעים לבית הספר או הביתה, וצפצוף לטלפון שהלך לאיבוד."))
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { Haptic.light(); showingLocation = true } label: {
                    Text(tr("להפעלה ←"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3BC4"))
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Button { withAnimation { locationIntroDismissed = true } } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32).background(Color.white.opacity(0.16), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("סגירה"))
        }
        .multilineTextAlignment(.leading)
        .foregroundStyle(.white)
        .padding(14)
        .glassPane(radius: 16, shadow: false)
        // The column it sits in is laid out LTR; in Hebrew the pin, the text and
        // the button belong on the RIGHT and ✕ on the left (Rani).
        .environment(\.layoutDirection, .app)
    }

    private var homeActionsRow: some View {
        HStack(spacing: 8) {
            Button { Haptic.light(); if !household.refuseIfDisconnected() { showingCreateChild = true } } label: { homeGhostLabel(tr("＋ צרו ילד/ה")).frame(maxWidth: .infinity) }
                .buttonStyle(.plain)
                .coachMark("p.newChild")
            // "תנו לילד לשחק" moved into each child's ⚡ menu (Rani, 2026-09-07):
            // it opens Kid Mode for THAT child, no picker.
            Button {
                Haptic.light()
                let items = choreStore.pendingApproval
                let target = items.first.flatMap { first in
                    profiles.profiles.first(where: { $0.id.uuidString == first.childID })
                } ?? rows.first?.profile
                if let target { choresProfile = target }
            } label: { homeGhostLabel(tr("🧹 מטלות")).frame(maxWidth: .infinity) }
                .buttonStyle(.plain)
                .coachMark("p.chores")
            // 📍 Where the children are — map, places, beep. Only once a child
            // has a phone of their own: with none, there is nothing to locate
            // (Rani, 9.10 — Eli's daughter plays on his phone).
            if familyHasChildDevice {
                Button { Haptic.light(); showingLocation = true } label: { homeGhostLabel(tr("📍 מיקום")).frame(maxWidth: .infinity) }
                    .buttonStyle(.plain)
            }
            // 📱 "🧒 מצב ילד" lived here until every child's card got its own
            // "תנו ל… לשחק כאן" — the same thing, already aimed at the right
            // child. Rani: "הכפתור מצב ילד למעלה אפשר להסיר, לא צריך אותו יותר".
        }
        .environment(\.layoutDirection, .app)
    }

    // MARK: - 🎁 Conversion journey, a child's purchase request, the packs shelf
    //
    // These used to be cards stacked ABOVE the children on this screen. Rani:
    // "במכשירים שלא רשומים אנחנו מקפיצים חלוניות של טופי+ וכל מיני חלוניות
    // אחרות למעלה מעל הילדים, אני לא רוצה יותר להציג את זה שם, שיהיה בתוך
    // העמוד של הפעמון". They are rows in the 🔔 activity centre now — built by
    // `ActivityOffers.current` and routed back here by `openOffer`, so every one
    // of them still leads exactly where its pane led.

    /// ✨ This version's story, one tap away — a gold ring while it is unwatched,
    /// a plain glass circle after. It opens only when the parent taps it.
    private var storyRing: some View {
        let fresh = WhatsNewStories.parentStoryUnwatched
        return Button {
            Haptic.light()
            whatsNewStory = WhatsNewStories.parentStoryForThisVersion
            WhatsNewStories.markParentStoryWatched()
            showWhatsNewStory = true
        } label: {
            Text("✨")
                .font(.system(size: 17))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.22)))
                .overlay(Circle().stroke(fresh ? Color(hex: "FFD84A") : .white.opacity(0.32), lineWidth: fresh ? 2.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("מה חדש בטופי"))
    }

    /// "שלום עמית 👋" and one true line about the family — in the page, like the mockup.
    private var homeHeader: some View {
        // 🔌 The "not connected to the family" banner rides under the header.
        VStack(spacing: 14) { homeHeaderRow; FamilyLinkBanner() }
    }

    private var homeHeaderRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // ⚙️ on the far left (the container is LTR), a glass circle like the
            // kid's nav buttons. On the Duo it lives in the rail instead.
            if !useRail {
                Button { Haptic.light(); showingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.22)))
                        .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("הגדרות"))
                .coachMark("p.gear")
                ActivityBellButton(unread: activity.unread) { showingActivity = true }
                    .coachMark("p.bell")
                if !WhatsNewStories.parentStoryForThisVersion.isEmpty {
                    storyRing
                }
            }
            VStack(alignment: .trailing, spacing: 4) {
                // The family's name IS the title (Rani); tap to name / rename.
                Button {
                    Haptic.light()
                    familyNameDraft = household.familyNameShown ?? ""
                    showFamilyNameEditor = true
                } label: {
                    HStack(spacing: 8) {
                        Text("✏️").font(.system(size: 14)).opacity(0.7)
                        Text(household.familyNameShown ?? greetingLine)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
                .alert(tr("שם המשפחה"), isPresented: $showFamilyNameEditor) {
                    TextField(tr("משפחת גולן"), text: $familyNameDraft)
                    Button(tr("שמרו")) { if !household.refuseIfDisconnected() { household.setFamilyName(familyNameDraft) } }
                    Button(tr("לא עכשיו"), role: .cancel) {
                        UserDefaults.standard.set(true, forKey: "family.namePromptOff")
                    }
                } message: {
                    Text(tr("מופיע כאן ובהודעות — לכל ההורים במשפחה."))
                }
                Text(homeSubtitle)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    // It used to be one line with an ellipsis, so the end — the
                    // part that says what is happening right now — was the half
                    // that got cut (Rani). Two lines, and it wraps.
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }

    /// Ask about the family name at most once a week, and never again once the
    /// parent has said "not now" (or named the family — the caller checks that).
    private var shouldAskFamilyName: Bool {
        let d = UserDefaults.standard
        if d.bool(forKey: "family.namePromptOff") { return false }
        let last = d.double(forKey: "family.namePromptAt")
        if last == 0 && d.bool(forKey: "family.namePromptShown") {
            // migrate the old one-shot flag: treat it as "asked just now"
            d.set(Date().timeIntervalSince1970, forKey: "family.namePromptAt")
            return false
        }
        return Date().timeIntervalSince1970 - last > 7 * 86_400
    }

    /// "שלום רני · שלושה ילדים · יואב משחק עכשיו"
    ///
    /// The weekday used to sit in here and was dropped (Rani): a parent knows
    /// what day it is, and bare "ראשון" read like a label on the children.
    private var homeSubtitle: String {
        // With a family name in the title, the greeting moves down here; without
        // one, a nudge to name the family takes its place.
        let lead: String? = household.familyNameShown != nil
            ? greetingLine.replacingOccurrences(of: " 👋", with: "")
            : tr("תנו שם למשפחה ✏️")
        return [lead, childrenCountLabel, familyMomentLine].compactMap { $0 }.joined(separator: " · ")
    }

    private var childrenCountLabel: String? {
        let ps = profiles.profiles
        guard !ps.isEmpty else { return nil }
        let fem = ps.allSatisfy { $0.gender == .girl }
        switch ps.count {
        case 1: return fem ? tr("ילדה אחת") : tr("ילד אחד")
        case 2: return fem ? tr("שתי ילדות") : tr("שני ילדים")
        case 3: return fem ? tr("שלוש ילדות") : tr("שלושה ילדים")
        case 4: return fem ? tr("ארבע ילדות") : tr("ארבעה ילדים")
        default: return fem ? tr("\(ps.count) ילדות") : tr("\(ps.count) ילדים")
        }
    }

    private func overviewStat(value: String, suffix: String?, label: String, progress: Double?) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value).font(.system(size: 17, weight: .heavy, design: .rounded))
                if let suffix { Text(suffix).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(GlassInk.tertiary) }
            }
            .monospacedDigit()
            .environment(\.layoutDirection, .leftToRight)   // "60/90" is a number — it rendered as "/900" in RTL
            // Always one line (Rani: "דקות שהרוויחה היום" wrapped on a narrower
            // iPhone and made the three tiles uneven) — it shrinks a little instead.
            Text(label).font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundStyle(GlassInk.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let progress {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.white).frame(width: g.size.width * progress)
                    }
                }
                .frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 6)
        .glassInset(radius: 16)
    }

    /// ⚡ on a card: opens the child's short actions window.
    private func gridCardMenu(_ profile: Profile, width: CGFloat) -> some View {
        Button {
            Haptic.light()
            actionsChild = profile
        } label: {
            // ⚡ as a symbol, not the emoji: the emoji's empty side bearing
            // pushed "פעולות" visibly off centre (Rani).
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(hex: "FFD54A"))
                Text(tr("פעולות"))
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            .frame(width: width, height: Self.homeControlHeight)
            .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func actionsSheet(_ p: Profile) -> some View {
        let girl = p.gender == .girl
        let hasDevice = childHasDevice(p)
        let earned = rows.first(where: { $0.profile.id == p.id })?.snapshot.minutesEarnedToday ?? 0
        let status: String = liveWindow(p) != nil
            ? (girl ? tr("משחקת עכשיו") : tr("משחק עכשיו"))
            : (hasDevice ? (girl ? tr("\(earned) דקות שהרוויחה היום") : tr("\(earned) דקות שהרוויח היום")) : tr("אין עדיין מכשיר מחובר"))
        let cap = p.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled, globalMax: settings.maxMinutesPerDay)
        let pending = choreStore.chores(forChild: p.id).filter { $0.isPendingApproval }.count
        return ChildActionsSheet(
            profile: p,
            hasDevice: hasDevice,
            statusLine: status,
            screenTimeSummary: cap.enabled ? tr("עד \(cap.minutes) דקות ביום") : tr("בלי הגבלה יומית"),
            pendingChores: pending
        ) { action in
            actionsChild = nil
            // Run it once the window has gone, so whatever opens next opens
            // over the home and not over a sheet on its way out.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                switch action {
                case .gift(let m): remoteOpen(p, m)
                case .lock: remoteLock(p)
                case .lockAndRevokeGift: revokeGiftProfile = p
                case .location: locationChild = p.id.uuidString; showingLocation = true
                case .connectDevice: qrCode = nil; qrChild = p
                case .screenTime: screenTimeChild = p
                case .chores: choresProfile = p
                case .settings: homeSettingsChild = p
                }
            }
        }
        .environmentObject(profiles)
        .environmentObject(settings)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// ⌚️ Send the per-child glance to the paired Apple Watch (no-op without
    /// one). Playing-now == an open screen-time window right now.
    private func pushWatchGlance() {
        let glances = rows.map { row -> WatchBridge.ChildGlance in
            let s = row.snapshot
            let playing = liveWindow(row.profile) != nil
            let pending = choreStore.chores(forChild: row.profile.id)
                .filter { $0.isPendingApproval }.count
            let cid = row.profile.id.uuidString
            let place = location.shownFix(cid).map { f -> String in
                let p = location.whereParts(f)
                return "\(p.icon) \(p.text) · \(ParentLocationView.relative(f.at, now: Date()))"
            }
            return WatchBridge.ChildGlance(
                id: cid,
                name: Question.stripNiqqud(row.profile.name),
                emoji: row.profile.gender == .girl ? "👧" : "👦",
                earnedToday: s.minutesEarnedToday,
                playingNow: playing,
                pendingChores: pending,
                moneyBalance: 0,
                girl: row.profile.gender == .girl,
                hasDevice: childHasDevice(row.profile),
                whereText: place)
        }
        WatchBridge.shared.pushFamilyGlance(glances)
    }

    // MARK: - Personal greeting (title area)

    /// "בוקר טוב, רני ☀️" — time-of-day + the parent's first name (or a plain
    /// hello for a guest / no name).
    private var greetingLine: String {
        let first = (auth.displayName ?? "")
            .split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? tr("שלום") : tr("שלום \(first)")
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
                ? tr("\(p.name) \(g(p, tr("פתח"), tr("פתחה"))) דקות מתנה עכשיו 💝")
                : tr("\(p.name) \(g(p, tr("פתח"), tr("פתחה"))) זמן מסך עכשיו 🎮")
        }
        // 1b. Someone is inside Tofy right now (learning).
        if let live = theRows.first(where: { isChildPlayingNow($0.profile) }) {
            return tr("\(live.profile.name) בטופי עכשיו — \(g(live.profile, tr("לומד"), tr("לומדת"))) 📚")
        }
        // 2. Best streak in the family (≥3 is worth celebrating).
        if let hot = theRows.max(by: { $0.snapshot.dayStreak < $1.snapshot.dayStreak }),
           hot.snapshot.dayStreak >= 3 {
            return tr("\(hot.profile.name) ברצף של \(hot.snapshot.dayStreak) ימים 🔥")
        }
        // 3. Family activity today.
        let questions = theRows.reduce(0) { $0 + $1.snapshot.answeredToday }
        let idle = theRows.filter { $0.snapshot.answeredToday == 0 }
        if questions > 0, idle.count == 1, theRows.count > 1 {
            let kid = idle[0].profile
            return tr("\(kid.name) עוד לא \(g(kid, tr("שיחק"), tr("שיחקה"))) היום — אולי לעודד? 💛")
        }
        if questions > 0 {
            return tr("המשפחה ענתה על \(questions) שאלות היום 👏")
        }
        // 4. Quiet day.
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? tr("יום חדש, הרפתקאות חדשות ✨") : tr("שקט היום — הכול בסדר 🌤️")
    }

    // MARK: - Live play window (what's happening RIGHT NOW)

    /// The child's currently OPEN play window, if any: seconds left, which
    /// device it's on, and whether it's a parent grant/gift or earned time.
    /// Derived from the live device rows (windowEndsAt reflects pauses), so it
    /// ticks down each dashboard refresh and vanishes the moment it closes.
    private func liveWindow(_ profile: Profile) -> (secondsLeft: Int, device: ChildDevice, isManual: Bool)? {
        _ = refreshTrigger   // recompute on the 5s tick
        let now = Date().timeIntervalSince1970
        let rows = household.devicesByChild[profile.id.uuidString] ?? []

        // THE LEASE FIRST. It is written atomically with the claim and carries a
        // server-stamped start, so it cannot lag. The device-row report is a
        // separate best-effort write with its own timing, which is why the live
        // countdown used to appear "sometimes" — it depended on that write having
        // landed rather than on the fact that a window is open.
        if let lease = remote.openWindows[profile.id], lease.isHeld, !lease.isExpired() {
            let left = lease.remainingSeconds()
            if left > 0 {
                let owner = rows.first { $0.deviceID == lease.ownerDeviceID } ?? rows.first
                if let owner {
                    return (left, owner, lease.kind == .gift || lease.kind == .grant)
                }
            }
        }
        let open = rows.compactMap { d -> (Int, ChildDevice, Bool)? in
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
            if let live { return live.isManual ? tr("💝 זמן מתנה פתוח") : tr("🎮 זמן מסך פתוח") }
            if isChildPlayingNow(profile) { return tr("בטופי עכשיו · \(girl ? tr("לומדת") : tr("לומד")) 📚") }
            return tr("לא בטופי כרגע")
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
    private func liveWindowBanner(_ profile: Profile, compact: Bool, onLock: (() -> Void)? = nil) -> some View {
        if let live = liveWindow(profile) {
            let deviceLabel = live.device.kind == "ipad" ? tr("באייפד") : (live.device.kind == "iphone" ? tr("באייפון") : tr("במכשיר"))
            let source = live.isManual ? tr("זמן שנתתם") : (profile.gender == .girl ? tr("זמן שהרוויחה") : tr("זמן שהרוויח"))
            // Authored RTL explicitly (the detail card is forced LTR): the pulse
            // dot leads on the RIGHT, Hebrew text is right-aligned, device icon
            // trails on the LEFT.
            HStack(spacing: 8) {
                LivePulseDot()
                if compact {
                    Text(live.isManual
                         ? tr("💝 זמן מתנה פתוח · \(formatTime(live.secondsLeft))")
                         : tr("🎮 זמן מסך פתוח · \(formatTime(live.secondsLeft))"))
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(live.isManual
                             ? tr("\(profile.name) \(profile.gender == .girl ? tr("פתחה") : tr("פתח")) דקות מתנה \(deviceLabel) 💝")
                             : tr("\(profile.name) \(profile.gender == .girl ? tr("פתחה") : tr("פתח")) זמן מסך \(deviceLabel) 🎮"))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                        Text(tr("נשארו \(formatTime(live.secondsLeft)) דקות · \(source)"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .opacity(0.9)
                            .monospacedDigit()
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if let onLock {
                        Button {
                            Haptic.light()
                            onLock()
                        } label: {
                            Label(tr("נעילה"), systemImage: "lock.fill")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(hex: "15803D"))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.95)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: live.device.sfSymbol)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .environment(\.layoutDirection, .app)
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
    /// 👑 Family subscription host — its own zero-size view so the paywall cover
    /// and the premium watcher never land on `body` or `rootAlertsHost`, both of
    /// which already sit at the type-checker's limit.
    // MARK: - 💬 Support chat

    // MARK: - 🚀 Setup checklist (band ב)

    /// The first child whose setup is not finished and not hidden.
    private var setupChild: Profile? {
        _ = setupTick
        return rows.map(\.profile).first { p in
            !SetupProgress.isHidden(p.id) && !setupSteps(for: p).allSatisfy(\.done)
        }
    }

    /// Parent copy — no niqqud. The device half of the list depends on the one
    /// question: a phone of their own (connect it, then the lock is on), or the
    /// parent's (try "תנו ל… לשחק כאן" once). A device connected later wins.
    private func setupSteps(for p: Profile) -> [SetupStep] {
        let name = Question.stripNiqqud(p.name)
        let grade = Profile.gradeNameForParent(p.effectiveGrade)
        var steps = [
            SetupStep(id: "account", title: tr("נוצר חשבון הורה"), done: true),
            SetupStep(id: "child", title: p.gender == .girl ? tr("נוספה \(name), \(grade)") : tr("נוסף \(name), \(grade)"), done: true),
            SetupStep(id: "cap", title: tr("נקבע זמן מסך יומי"), done: true),
        ]
        let devices = household.devicesByChild[p.id.uuidString] ?? []
        // "Plays on my phone" IS a finished setup — nothing left to configure,
        // and the card's own "תנו ל… לשחק כאן" is right there (Rani: "למה צריך
        // להכריח את השלב").
        if SetupProgress.plan(p.id) != .here || !devices.isEmpty {
            // No separate "the lock is on" step (Rani: "לא חושב שצריך את השלב
            // הזה"): connecting asks for Screen Time, and from that moment the
            // device is fully locked with no setup — see `newAppLockArmed`.
            steps.append(SetupStep(id: "connect", title: tr("לחבר מכשיר ל\(name)"), done: !devices.isEmpty))
        }
        return steps
    }

    @ViewBuilder private var setupChecklist: some View {
        if let p = setupChild {
            let steps = setupSteps(for: p)
            let next = steps.first { !$0.done }?.id
            SetupChecklistCard(
                steps: steps,
                continueTitle: tr("ממשיכים — לחבר מכשיר"),
                onContinue: {
                    switch next {
                    case "connect":
                        // No answer yet → the question; "own device" → the code.
                        if SetupProgress.plan(p.id) == nil { deviceQuestionChild = p }
                        else { qrCode = nil; qrChild = p }
                    default: break
                    }
                },
                onHide: {
                    SetupProgress.hide(p.id)
                    withAnimation { setupTick &+= 1 }
                })
        }
    }

    // MARK: - 🧭 The tour

    static let parentTourKey = "parentHome.v1"

    private func startParentTour() {
        guard isRoot, !rows.isEmpty, !showWhatsNewStory, !showWhatsNew, !showSchoolYearParty,
              !parentTourActive, !showGiftWelcome, !GiftWelcome.isDue(household.household),
              !ParentOnboarding.isActive, onbConnectChild == nil, onbDone == nil else { return }
        parentTourActive = true
    }

    /// Every control on the home, in the order the eye meets it. A stop whose
    /// control is not on screen (no device yet, no chat on this account) is
    /// skipped by the tour itself. Parent copy — no niqqud.
    private var parentTourSteps: [CoachStep] {
        let name = Question.stripNiqqud(rows.first?.profile.name ?? tr("הילד"))
        return [
            // "מידע נוסף" lives inside the card's link, which keeps its anchor
            // from the tour — so the card's own stop says where it leads.
            CoachStep(id: "p.card", title: tr("הכרטיס של \(name)"),
                      text: tr("כמה דקות הרוויח היום, כמה שאלות ענה ובכמה צדק. לחיצה על הכרטיס או על \"מידע נוסף\" פותחת את הדוח המלא וההגדרות של הילד.")),
            CoachStep(id: "p.actions", title: tr("פעולות"),
                      text: tr("מרחוק, בלי לגעת בטלפון שלו: מתנת דקות, נעילה ומטלות.")),
            CoachStep(id: "p.playHere", title: tr("תנו ל\(name) לשחק כאן"),
                      text: tr("הילד משחק בטלפון שלכם: הכל ננעל חוץ מטופי, והיציאה מוגנת בקוד.")),
            CoachStep(id: "p.connect", title: tr("חיבור מכשיר"),
                      text: tr("מחברים את הטלפון או האייפד של הילד בסריקת קוד אחת.")),
            CoachStep(id: "p.newChild", title: tr("ילד נוסף"),
                      text: tr("מוסיפים עוד ילד למשפחה — לכל אחד כיתה וזמן מסך משלו.")),
            CoachStep(id: "p.chores", title: tr("מטלות"),
                      text: tr("הילד בוחר מטלה בבית, אתם מאשרים, והוא מקבל דקות או כסף.")),
            CoachStep(id: "p.bell", title: tr("עדכונים"),
                      text: tr("כל מה שקורה אצל הילדים: מה עשו, בקשות שמחכות לכם והודעות שנשלחו.")),
            CoachStep(id: "p.gear", title: tr("הגדרות"),
                      text: tr("זמן מסך ליום, תגמולים, שפה, ושוב את ההדרכה הזאת.")),
            CoachStep(id: "p.chat", title: tr("צוות טופי"),
                      text: tr("שאלה? כתבו לנו כאן, והתשובה תגיע לטלפון שלכם.")),
        ]
    }

    /// Parents only — a real (non-anonymous) account on a parent device. Never
    /// on a child's device or inside Kid Mode (a sheet over this screen).
    private var showsSupport: Bool {
        isRoot && auth.isRealAccount && settings.deviceRole != .child && !HouseholdManager.skipsCloudSync
    }

    private func openSupportChat() {
        // 🔌 No family loaded = no thread to open. Say so instead of a dead tap.
        guard let hid = household.household?.id else {
            household.connectionNotice = true
            household.retryFamilyLoadIfNeeded()
            return
        }
        support.route = .parent(householdID: hid)
    }

    private var supportCorner: some View {
        SupportFloatingButtons(
            showsInbox: SupportTeam.isCurrentUser,
            onChat: { openSupportChat() },
            onInbox: { support.route = .inbox }
        )
        .coachMark("p.chat")
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .environment(\.layoutDirection, .app)
        .task(id: household.household?.id) {
            support.startParent(householdID: household.household?.id)
            support.startTeamIfNeeded()
        }
    }

    /// Hosts the chat sheet off the main modifier chain (type-checker budget).
    private var supportSheetHost: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .sheet(item: $support.route) { route in
                SupportChatRouteView(route: route)
            }
    }

    private var paywallHost: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .fullScreenCover(isPresented: $showingPaywall) { gatedPaywall }
            .onAppear {
                consumeCampaignLanding()
                campaigns.checkPopup(role: "parent", profiles: profiles.profiles, premium: subs.isPremium)
            }

            .onChangeCompat(of: campaigns.pendingPackID) { _, _ in consumeCampaignLanding() }
            .onChangeCompat(of: campaigns.pendingScreen) { _, _ in consumeCampaignLanding() }
            .fullScreenCover(item: $packToShow) { pack in
                PackDetailView(pack: pack, preselected: packRequestChild?.id) { packToShow = nil; packRequestChild = nil }
                    .environmentObject(profiles)
            }
            .onChange(of: subs.isPremium) { premium in
                if premium { remote.clearPremiumRequests() }
            }
    }

    /// Bought here, behind the parent gate — Kids Category: commerce is always gated.
    private var gatedPaywall: some View {
        ParentGateView(allowClose: true, gateTitle: tr("אזור הורים"),
                       gateReason: tr("כדי לפתוח את המנוי למשפחה — הזינו את הקוד"),
                       useFaceID: true, respectSession: false) {
            PaywallView(source: paywallSource)
                .environmentObject(subs)
                .environment(\.layoutDirection, .app)
        }
        .environmentObject(settings)
        .environment(\.layoutDirection, .app)
    }

    private var rootAlertsHost: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)

        // "Lock + revoke gift" confirmation — a real consequence, so it asks.
        // Presented from either menu (root grid ⋯ / detail ⋯).
        .alert(
            revokeGiftProfile.map { tr("לנעול ולאפס את דקות המתנה של \($0.name)?") } ?? "",
            isPresented: Binding(get: { revokeGiftProfile != nil && navPath.isEmpty },
                                 set: { if !$0 { revokeGiftProfile = nil } }),
            presenting: revokeGiftProfile
        ) { p in
            Button(tr("נעל ואפס"), role: .destructive) {
                lockAndRevokeGift(p)
                revokeGiftProfile = nil
            }
            Button(tr("בטל"), role: .cancel) { revokeGiftProfile = nil }
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
        .alert(tr("שליטה מרחוק"), isPresented: Binding(
            get: { remoteGrantMsg != nil && navPath.isEmpty },
            set: { if !$0 { remoteGrantMsg = nil } })) {
            Button(tr("הבנתי"), role: .cancel) {}
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
            Button(tr("הבנתי"), role: .cancel) { statExplain = nil }
        } message: { s in
            Text(s.text)
        }
        // A parent→child command (±דקות / איפוס) was permanently rejected — tell
        // the parent honestly instead of leaving an optimistic change that never
        // reached the child.
        .alert(tr("הפעולה לא נשלחה"), isPresented: Binding(
            get: { !remote.commandFailed.isEmpty },
            set: { if !$0 { remote.commandFailed.removeAll() } })) {
            Button(tr("הבנתי"), role: .cancel) { remote.commandFailed.removeAll() }
        } message: {
            Text(tr("לא הצלחנו לשלוח את העדכון למכשיר של הילד/ה. בדקו את החיבור לאינטרנט ונסו שוב."))
        }
    }

    /// The children grid (pulled out of `body` — the type-checker choked on the
    /// full inline expression).
    /// The card as a tap target: a push when the device is closed, a selection
    /// when it is open — the same card either way.
    @ViewBuilder private func childCardTap(_ row: (profile: Profile, snapshot: ProgressSnapshot)) -> some View {
        Group {
            if splitOpen {
                Button { selectChild(row.profile.id) } label: {
                    childCard(profile: row.profile, snapshot: row.snapshot)
                }
                .buttonStyle(.plain)
                .overlay {
                    if selectedChild == row.profile.id {
                        RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                            .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                            .allowsHitTesting(false)
                    }
                }
            } else {
                NavigationLink(value: row.profile.id) {
                    childCard(profile: row.profile, snapshot: row.snapshot)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var childrenGrid: some View {
            LazyVGrid(
                // 📐 Two across on a wide, short screen that has no rail beside
                // it. On the Duo the home keeps a phone's width and the second
                // half of the screen holds the child's page, so one column.
                columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                               count: display.isWideShort && !splitOpen && rows.count > 1 ? 2 : 1),
                spacing: 12
            ) {
                ForEach(rows, id: \.profile.id) { row in
                    AnyView(childCardTap(row))
                        .coachMark("p.card", if: row.profile.id == rows.first?.profile.id)
                        // ✏️ Avatar + name → this child's settings, in one tap
                        // (Rani: "מאוד מסובך להגיע למצב של עריכת ילד"). The grid
                        // is RTL, so `.topLeading` is the top-RIGHT, where they sit.
                        .overlay(alignment: .topLeading) {
                            if isRoot {
                                Button {
                                    Haptic.light()
                                    editChild = row.profile
                                } label: {
                                    Color.clear
                                        .frame(width: 230, height: 84)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(tr("עריכת \(Question.stripNiqqud(row.profile.name))"))
                            }
                        }
                    // ⋯ quick actions right on the card — the two
                    // remote controls (open / lock now) without
                    // opening the child's page. Overlaid on the link
                    // (not inside it) so the tap isn't swallowed.
                    // The grid is forced RTL, so "leading" = right; the ⋯ belongs
                    // on the LEFT corner (away from the avatar's status dot).
                    // ⚡ quick actions overlaid INTO the slot the card reserves
                    // (a Menu inside the NavigationLink would swallow the tap).
                    // The grid is RTL, so `.bottomTrailing` is the bottom-LEFT.
                    .overlay {
                        GeometryReader { g in
                            gridCardMenu(row.profile, width: Self.tileWidth(cardWidth: g.size.width))
                                .coachMark("p.actions", if: row.profile.id == rows.first?.profile.id)
                                .padding(Self.cardPadding)
                                .padding(.bottom, Self.homeControlHeight + Self.homeRowGap)
                                .frame(width: g.size.width, height: g.size.height, alignment: .bottomTrailing)
                        }
                    }
                    // 🧒 One tap hands THIS device to THIS child. Parents wrote in
                    // that they could not find Kid Mode at all when it lived only
                    // inside the ⚡ menu.
                    .overlay(alignment: .bottomTrailing) {
                        // 🧒 Also for a child with no device of their own — that
                        // is exactly the family that hands over the parent's
                        // phone, so the button matters most there (Rani).
                        if isRoot {
                            Button {
                                Haptic.light()
                                kidModeStart = row.profile
                            } label: {
                                homePrimaryLabel(tr("תנו ל\(row.profile.name) לשחק כאן 🧒"))
                            }
                            .buttonStyle(.plain)
                            .coachMark("p.playHere", if: row.profile.id == rows.first?.profile.id)
                            .padding(14)
                            .environment(\.layoutDirection, .app)
                        }
                    }
                    // 📱 No device yet → "+ חברו מכשיר", between מידע נוסף and ⚡.
                    .overlay {
                        if isRoot, !childHasDevice(row.profile) {
                          GeometryReader { g in
                            let t = Self.tileWidth(cardWidth: g.size.width)
                            Button {
                                Haptic.light()
                                qrCode = nil
                                qrChild = row.profile
                            } label: {
                                homeGhostLabel(tr("+ חברו מכשיר"), width: t)
                            }
                            .buttonStyle(.borderless)
                            .coachMark("p.connect", if: row.profile.id == rows.first(where: { !childHasDevice($0.profile) })?.profile.id)
                            .padding(.bottom, Self.cardPadding + Self.homeControlHeight + Self.homeRowGap)
                            // Its slot sits between מידע נוסף and the ⚡ menu (the grid is RTL:
                            // `.bottomTrailing` is the bottom-LEFT, where ⚡ lives).
                            .padding(.trailing, Self.cardPadding + t + Self.tileGap)
                            .frame(width: g.size.width, height: g.size.height, alignment: .bottomTrailing)
                          }
                          .environment(\.layoutDirection, .app)
                        }
                    }
                    .contextMenu {
                        Button {
                            navPath.append(row.profile.id)
                        } label: { Label(tr("פתחו כרטיס"), systemImage: "rectangle.portrait.and.arrow.right") }
                        Button {
                            choresProfile = row.profile
                        } label: { Label(tr("מטלות הבית 🧹"), systemImage: "checklist") }
                        if rows.count >= 2 {
                            Button {
                                showingReorder = true
                            } label: { Label(tr("סדר את הילדים"), systemImage: "arrow.up.arrow.down") }
                        }
                        Button(role: .destructive) {
                            gridDeleteProfile = row.profile
                        } label: { Label(tr("מחיקת ילד/ה"), systemImage: "trash") }
                    }
                }
            }
            // RTL so the cards fill right-to-left — with an odd count
            // the lone card sits on the RIGHT, not the left.
            .environment(\.layoutDirection, .app)
            .animation(.spring(response: 0.5, dampingFraction: 0.85),
                       value: rows.map(\.profile.id))
    }
    /// Live banner + the three quick actions, right under the child's name
    /// (Rani's approved mockup). Split out of the page: with translated labels
    /// one expression was too slow for the type checker.
    private func detailTopActions(_ profile: Profile) -> some View {
        VStack(spacing: 10) {
            // LIVE: an open play window right now — with the lock one tap away.
            liveWindowBanner(profile, compact: false) { remoteLock(profile) }
            // The gift / lock / chores tiles were here — they live in "⚡ פעולות"
            // now (Rani: the page was "עמוס מדי" and said it twice).
        }
        .environment(\.layoutDirection, .app)
    }

    /// One of the three equal quick-action tiles: emoji over a short label.
    private func quickActionLabel(_ emoji: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 20))
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(GlassInk.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 6)
        .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.30), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// DEMO: open the first child. A method, not an inline closure — inline it
    /// tipped the dashboard's long modifier chain past the type-checker's time
    /// limit on a busy machine.
    private func openFirstChildForDemo() {
        if demoOpenFirstChild, navPath.isEmpty, let first = rows.first?.profile.id {
            // selectChild: open, the child fills the revealed half — a push
            // there drew the same page in BOTH halves.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { selectChild(first) }
        }
    }

    /// "⚙️ הגדרות של X ›" — the one door to everything that is SET about the
    /// child (page 2). It used to unfold the whole legacy card under the report.
    @ViewBuilder
    private func childDetailScreen(for id: UUID) -> some View {
        if let row = rows.first(where: { $0.profile.id == id }) {
            detailDialogsB(detailDialogsA(childDetailPage(row)))
        } else {
            Color.clear.background(AppGradient.dreamy.ignoresSafeArea())
        }
    }

    private func childDetailPage(_ row: (profile: Profile, snapshot: ProgressSnapshot)) -> some View {
            ScrollView {
              ScrollViewReader { proxy in
                VStack(spacing: 14) {
                    // 📐 The foldable: the system draws a bar's buttons in a column
                    // under the clock, over the page (Rani: English had ‹ and ⚙️ on
                    // the green banner). Our own row instead, on the side AWAY from
                    // the camera.
                    if display.hasBarStrip {
                        HStack(spacing: 10) {
                            Button { Haptic.light(); if !navPath.isEmpty { navPath.removeLast() } } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.18)))
                            }
                            .accessibilityLabel(tr("חזרה"))
                            Button { Haptic.light(); settingsChild = row.profile } label: {
                                Label(tr("הגדרות"), systemImage: "gearshape.fill")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14).frame(height: 44)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.18)))
                            }
                            Spacer(minLength: 0)
                        }
                        .buttonStyle(.plain)
                        .environment(\.layoutDirection, display.barOnLeft ? .rightToLeft : .leftToRight)
                        .clearOfBar()
                    }
                    ChildReportView(
                        profile: row.profile,
                        snapshot: row.snapshot,
                        liveSecondsLeft: liveWindow(row.profile)?.secondsLeft ?? 0,
                        liveIsGift: liveWindow(row.profile)?.isManual ?? false,
                        devices: household.devicesByChild[row.profile.id.uuidString] ?? [],
                        topActions: AnyView(detailTopActions(row.profile)),
                        onAddDevice: { qrCode = nil; qrChild = row.profile },
                        onRemoveDevice: { deviceToRemove = $0 }
                    )
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 720)
                .containerWidthLock()
                #if DEBUG
                // DEMO_REPORT_SCROLL=topics|worlds — website screenshots.
                .onAppear {
                    if let to = ProcessInfo.processInfo.environment["DEMO_REPORT_SCROLL"] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { proxy.scrollTo(to, anchor: .top) }
                    }
                }
                #endif
              }
            }
            .sheet(item: $settingsChild) { p in
                ChildSettingsView(profileID: p.id,
                                  snapshot: rows.first(where: { $0.profile.id == p.id })?.snapshot ?? row.snapshot,
                                  onResetProgress: { resetProgress(for: $0) },
                                  onDelete: { removed in
                                      settingsChild = nil
                                      profiles.remove(removed)   // removes locally + from the cloud
                                      navPath.removeAll()        // pop back to the family grid
                                  },
                                  onConnectDevice: {
                                      settingsChild = nil
                                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { qrCode = nil; qrChild = p }
                                  },
                                  onLocation: {
                                      settingsChild = nil
                                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                          locationChild = p.id.uuidString; showingLocation = true
                                      }
                                  })
                    .environmentObject(profiles)
                    .environmentObject(settings)
            }
            .noHorizontalBounce()
            .environment(\.layoutDirection, .appMirrored)
            .background(GlassBackdrop())
            .navigationTitle("")
            // ⚙️ Everything that is SET rather than read (name, grade,
            // difficulty, worlds, cap, PIN, friends, reset, delete…) — in the
            // page's header now, not a row at the very bottom of a long report.
            .toolbar {
                ToolbarItem(placement: .barSafeTopTrailing) {
                    Button {
                        Haptic.light()
                        settingsChild = row.profile
                    } label: {
                        Label(tr("הגדרות"), systemImage: "gearshape.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbar(display.hasBarStrip ? .hidden : .visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }

    // Split out of the page: with translated labels one modifier chain of seven
    // dialogs was too slow for the type checker.
    private func detailDialogsA<V: View>(_ page: V) -> some View {
        page
        // These dialogs live on the DETAIL page (not the root) so they present
        // IN-CONTEXT — at the root they only popped up after navigating back.
        // (Reset / PIN / delete confirmations moved to ChildSettingsView with
        // their rows — a sheet, which these could not show over.)
        // "What does this number mean?" — tapped stat cell explanation.
        .alert(
            statExplain.map { "\($0.emoji) \($0.label) — \($0.value)" } ?? "",
            isPresented: Binding(get: { statExplain != nil && !navPath.isEmpty },
                                 set: { if !$0 { statExplain = nil } }),
            presenting: statExplain
        ) { _ in
            Button(tr("הבנתי"), role: .cancel) { statExplain = nil }
        } message: { s in
            Text(s.text)
        }
    }

    private func detailDialogsB<V: View>(_ page: V) -> some View {
        page
        // "Lock + revoke gift" confirmation on the DETAIL page (dialogs must sit
        // on the visible page — on the root it only appeared after popping back).
        .alert(
            revokeGiftTitle,
            isPresented: Binding(get: { revokeGiftProfile != nil && !navPath.isEmpty },
                                 set: { if !$0 { revokeGiftProfile = nil } }),
            presenting: revokeGiftProfile
        ) { p in
            Button(tr("נעל ואפס"), role: .destructive) {
                lockAndRevokeGift(p)
                revokeGiftProfile = nil
            }
            Button(tr("בטל"), role: .cancel) { revokeGiftProfile = nil }
        } message: { p in
            Text(revokeGiftMessage(p))
        }
        // Remote screen-time confirmation — also on the detail page so it shows
        // immediately where the parent tapped, not only after popping back.
        .alert(tr("שליטה מרחוק"), isPresented: Binding(
            get: { remoteGrantMsg != nil && !navPath.isEmpty },
            set: { if !$0 { remoteGrantMsg = nil } })) {
            Button(tr("הבנתי"), role: .cancel) {}
        } message: {
            Text(remoteGrantMsg ?? "")
        }
        // Remove-linked-device confirmation — on the detail page too, since the
        // "remove device" button lives here; on the root it only popped up after
        // navigating back.
        .confirmationDialog(
            deviceToRemove.map { tr("להסיר את \"\($0.name)\"?") } ?? "",
            isPresented: Binding(
                get: { deviceToRemove != nil },
                set: { if !$0 { deviceToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(tr("הסר מכשיר"), role: .destructive) {
                if let d = deviceToRemove { household.removeChildDevice(id: d.id) }
                deviceToRemove = nil
            }
            Button(tr("ביטול"), role: .cancel) { deviceToRemove = nil }
        } message: {
            Text(tr("המכשיר יתנתק אוטומטית מהילד ויחזור למצב התחלתי (כאילו הותקן מחדש). ההתקדמות בענן נשמרת — כדי לחבר אותו שוב (או לילד אחר), סרקו בו מחדש את ה-QR של הילד הנכון."))
        }

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
            case tr("דק׳ מסך היום"):   // labels are shown translated, so match the translation
                return tr("סך כל דקות זמן המסך שכל הילדים הרוויחו היום ביחד (מכל המכשירים). מתאפס בחצות. לפירוט לכל ילד — פתחו את הכרטיס שלו.")
            case tr("שאלות היום"):   // labels are shown translated, so match the translation
                return tr("כמה שאלות ענו כל הילדים ביחד היום — בכל העולמות, במשחקים ובהרפתקה החכמה. מספר טוב לתחושה כללית של \"היה יום למידה או לא\".")
            case tr("ילדים פעילים"):   // labels are shown translated, so match the translation
                return tr("כמה מהילדים כבר ענו לפחות על שאלה אחת היום, מתוך כלל הילדים במשפחה. 1/2 = ילד אחד מתוך שניים שיחק היום.")
            default: break
            }
            }
            switch emoji {
            case "⏱":
                return tr("כמה דקות זמן מסך הילד/ה הרוויח/ה היום, מתוך התקרה היומית שקבעתם (המספר אחרי הקו). כל כמה תשובות נכונות מזכות בדקות מסך (היחס נקבע בהגדרות). כשהתקרה מתמלאת (למשל 240/240) — הילד/ה ממשיך/ה ללמוד, אבל דקות חדשות נשמרות למחר (🎁), ו-🎮 יציג \"—\" אם הארנק כבר נוצל. דקות מתנה 💝 אינן כפופות לתקרה.")
            case "❓":
                return tr("כמה שאלות הילד/ה ענה/תה היום — בכל העולמות, במשחקים ובהרפתקה החכמה. מתאפס בחצות.")
            case "🎯":
                return tr("אחוז התשובות הנכונות מתוך כל השאלות של היום. \"—\" = עוד לא ענה/תה היום. מתחת ל-50% לאורך זמן? כדאי להוריד רמת קושי מהתפריט ⋯.")
            case "🔥":
                return tr("כמה ימים ברצף הילד/ה שיחק/ה בטופי (לפחות שאלה אחת ביום). יום שמדלגים עליו מאפס את הרצף — זה מה שמניע לחזור מחר.")
            case "⭐":
                return tr("כוכבים = הדירוג. הם רק עולים ולעולם לא נגמרים — הם מה שקובע את הרמה של הילד/ה ואת המקום בלוח החברים. אי אפשר לבזבז אותם.")
            case "💎":
                return tr("יהלומים = הארנק של החנות. מרוויחים לאט יותר מכוכבים (בערך 1 לתשובה), ומוציאים אותם על דמויות ופריטים בחנות. יורדים כשקונים — זה תקין.")
            case "🎮":
                return tr("דקות משחק שהילד/ה הרוויח/ה מלמידה ועוד לא פתח/ה (הארנק המורווח). דקות שאתם נותנים (💝 מתנה) נשמרות בנפרד ולא נספרות כאן. כשיש חלון פתוח של זמן מורווח — רואים כאן ספירה לאחור (חלון של מתנה סופר תחת 💝). \"—\" = אין דקות ממתינות.")
            case "💝":
                return tr("דקות שאתם נתתם במתנה ועוד לא נפתחו — נשמרות בנפרד לגמרי מהדקות שהילד/ה הרוויח/ה, אותו מספר בכל מכשיר. הילד/ה פותח/ת אותן מתי שרוצה, וכשהמתנה פתוחה — הספירה לאחור מופיעה כאן (ולא ב-🎮). בכל נתינה אפשר לתת עד מה שנשאר עד חצות; מה שלא נוצל נשאר למחר.")
            default:
                return tr("נתון מסכם על הפעילות של הילד/ה בטופי.")
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
            remoteGrantMsg = tr("עוד רגע חצות — אין מה לתת להיום. מיד אחרי חצות אפשר לתת שוב.")
            return
        }
        Haptic.success()
        remote.giftChildMinutes(childID: profile.id, minutes: allowed)
        refreshTrigger &+= 1
        // Live status sheet: cloud-commit + device-ack for the gift, honestly —
        // replaces the optimistic alert that claimed success before anything
        // actually happened.
        let note = allowed < minutes
            ? tr("ביקשתם \(minutes) — זה המקסימום שנשאר להיום, עד חצות.")
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
        let earned = p.gender == .girl ? tr("היא הרוויחה") : tr("הוא הרוויח")
        return tr("המכשיר יינעל עכשיו, וכל הדקות שנתתם (💝 מתנה, ❄️ שמורות, וחלון פתוח של מתנה) יימחקו. הדקות ש\(earned) מלמידה לא נפגעות.")
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
                    Text(tr("גררו את הידיות כדי לקבוע את הסדר בלוח. הסדר נשמר לכל ההורים במשפחה."))
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(tr("סדר הילדים"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .barSafeCancellation) {
                    Button(tr("ביטול")) { dismiss() }
                }
                ToolbarItem(placement: .barSafeConfirmation) {
                    Button(tr("שמור")) {
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
        .environment(\.layoutDirection, .app)
}

/// 🧭 "הכל מוכן" at the end of the new-parent flow — which child, and whether
/// they play on this phone (then the home tour follows, and the offer to play).
struct OnboardingFinish: Identifiable {
    let id = UUID()
    let child: Profile
    let playsHere: Bool
}
