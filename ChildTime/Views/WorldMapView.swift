import SwiftUI

struct WorldMapView: View {
    @AppStorage(ChildLockSetup.pendingKey) private var lockSetupPending = false
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var subs: SubscriptionManager
    @ObservedObject private var household = HouseholdManager.shared
    @ObservedObject private var leaseMgr = PlayWindowLeaseManager.shared
    @Environment(\.horizontalSizeClass) private var hsc

    @ObservedObject private var friends = FriendsManager.shared
    @ObservedObject private var liveGame = LiveGameManager.shared
    @ObservedObject private var kidMode = KidModeManager.shared
    @ObservedObject private var quiet = QuietHoursManager.shared
    @State private var inviteBannerVisible = false
    /// 🔄 "there is a newer Tofy" — once per launch, and never over another sheet.
    @State private var showUpdateNotice = false
    @State private var showKidExit = false
    @StateObject private var companion = CompanionController()
    @State private var selectedWorld: World?
    /// ⚽ 🎁 A pack the parent just bought — shown once, then the world opens.
    @State private var packReveal: QuestionPack? = nil
    /// A pack the family doesn't have: the child can ask a parent (never buy).
    @State private var packOffer: QuestionPack? = nil
    @ObservedObject private var packStore = PackStore.shared
    @ObservedObject private var conv = ConversionConfig.shared
    @ObservedObject private var campaignTracker = CampaignTracker.shared
    @State private var showDailyChest = false
    @State private var challengeCelebration: String? = nil
    @State private var infoSheet: InfoSheet? = nil

    /// Which home-card explainer is open (daily challenge / topic-of-the-day).
    private enum InfoSheet: Int, Identifiable { case dailyChallenge, event; var id: Int { rawValue } }
    @State private var showingParentGate = false
    @State private var showingDemo = false
    /// 🎒 September 1st "you moved up a grade!" party (once per school year).
    @State private var showSchoolYearParty = false
    /// 🎓 Kid-facing grade picker, when the profile has no grade yet.
    @State private var showChildGradePicker = false
    /// 📖 The "מה חדש" STORY, once per update per child. Rani: it has to open
    /// by itself — "מבלי שהוא צריך לעשות פעולה" — so there is nothing to tap.
    @State private var showWhatsNewStory = false
    /// 🧭 The child's one-time tour of this screen (band ג).
    @State private var kidTourActive = false
    /// 🍏 Once, right after this device joined: Apple's own Screen Time tips.
    @State private var showAppleTips = false
    /// Captured before the build is marked seen; reading it afterwards is empty.
    @State private var whatsNewStory: [StoryItem] = []
    /// Limited-time event SPLASH (💎×2 etc.) — a full pop-up like the lucky
    /// wheel, once a day; the kid closes it or jumps straight in.
    @State private var showEventSplash = false
    /// Drives the daily-challenge card's living flame/gift pulse.
    @State private var challengePulse = false
    @State private var showingShop = false
    @State private var showingWheel = false
    @State private var showingGames = false
    @State private var showingChores = false
    @StateObject private var choreStore = ChoreStore.shared
    @State private var showingLeaderboard = false
    @State private var showingSmartFeed = false
    @State private var showingChildSettings = false
    @State private var showingPaywall = false
    /// The locked world the child tapped → "רוצה ללמוד X? בקש מאבא או אמא".
    @State private var askWorld: World? = nil
    @State private var showingAppLockSetup = false
    /// The child's "protect my time" code flow. `pendingUnlockAction` remembers
    /// which unlock the kid tapped, to run right after a successful verify.
    @State private var playPINSheet: PlayPINSheet? = nil
    @State private var pendingUnlockAction: (() -> Void)? = nil
    @State private var lastSeenStars = 0
    @State private var heroAppeared = false
    /// 🏆 The ONE never-visited world Tofy recommends (decided on appear, so it
    /// doesn't hop around while the child scrolls).
    @State private var suggestedWorldID: String?
    // 🔒→🔓 Window transfer ("נעל באייפד ופתח כאן"): when THIS child's window is
    // open on another device, the kid can ask to lock it there and continue
    // here. We open here only AFTER the other device confirms (row cleared).
    @State private var transferRequestedAt: Date? = nil
    @State private var transferTimedOut = false
    /// A transfer is in flight — the button says so instead of looking dead.
    @State private var isTransferring = false
    /// True while a claim transaction is in flight. Opening has to ask the cloud
    /// whether any other device holds the child's one window — that round trip is
    /// a second or two, and with no feedback the button looks broken and gets
    /// tapped again. Rani: "אני מכניס קוד, הוא חוזר למסך הראשי, ורק אחרי 2 שניות
    /// פותח". The wait is real and cannot be skipped; being silent about it is
    /// what made it feel wrong.
    /// Mirrors the store: a claim is in flight (the play screen shows it).
    private var isOpening: Bool { progress.isOpeningWindow }
    /// Which device kind the window was taken FROM — so the parent's push can
    /// say "מהאייפד לאייפון".
    @State private var transferFromKind = ""
    @State private var showLevelInfo = false

    private var isCompact: Bool { hsc == .compact }
    /// 📐 A short screen (the foldable held open, an iPhone SE): the bottom
    /// panel tightens and the grid/companion clear its MEASURED height instead
    /// of the tuned constants below, which assume a tall iPhone.
    @ObservedObject private var display = DisplayGeometry.shared
    @State private var bottomPanelHeight: CGFloat = 0
    /// Where the header pane really ends. The buddy's zone starts under it on a
    /// short screen — the open foldable (867×635) parked it on the daily
    /// challenge, because the tuned 230/300 assume a taller screen.
    @State private var headerBottom: CGFloat = 0
    private var isShort: Bool { display.isShort }
    private var companionSize: CGFloat { isCompact ? 90 : (isShort ? 96 : 120) }
    // Glass look: a modest brand line heading the grid, not a poster.
    private var heroTitleSize: CGFloat { isCompact ? 34 : 40 }

    @State private var infoStat: StatInfo? = nil

    enum StatInfo: String, Identifiable {
        case minutes, stars, diamonds
        /// 💝 the gift pocket, ⏱ "הרווחת היום", ✅ "נכונות היום" — each its own
        /// explanation (Rani: the gift and today's tile opened the play-minutes one,
        /// and "נכונות היום" did nothing).
        case gift, today, correct
        var id: String { rawValue }
    }

    private var worldGridColumns: [GridItem] {
        let count = isCompact ? 2 : 3
        return Array(
            repeating: GridItem(.flexible(), spacing: AppSpacing.md),
            count: count
        )
    }

    /// Worlds the parent enabled for the active child (all topics if unset). A
    /// disabled topic is hidden entirely — the child never sees that world card,
    /// and the Smart Feed won't serve its questions either.

    /// Everything on the kid's home except טופי טיים is Tofy+. One gate, so a
    /// new tile can never be added without it (Rani found games, the arena and
    /// chores reachable for free). Never a lock icon or failure language for the
    /// child — the paywall itself is the parent-facing, parent-gated screen.
    private func requirePremium(_ action: () -> Void) {
        if subs.isPremium { action() }
        else { Haptic.light(); showingPaywall = true }
    }

    /// A world the parent bought for this child (a pack, or a 30-day pass on a
    /// base world) — open with or without Tofy+.
    private func isOwned(_ world: World) -> Bool {
        guard let item = world.topic.pack ?? WorldPasses.pass(for: world.topic), let p = profiles.active else { return false }
        return PackAccess.has(p, item)
    }

    /// What a family WITHOUT Tofy+ sees (Rani): טופי טיים is the only open
    /// world. Worlds the parent bought stay. Of everything else the child sees
    /// exactly `lockedShown` locked worlds — chosen for their grade, rotating
    /// every few days so the home never goes stale — and the rest are not shown
    /// at all. A world the child already played (a gift that ended) comes
    /// first, so what they loved is one tap from asking. Guests (open for free)
    /// exist only if the founder turns them on.
    private struct FreeTier { var owned: [World] = []; var guests: [World] = []; var locked: [World] = []
        var guestIDs: Set<String> { Set(guests.map(\.id)) } }

    private var freeTier: FreeTier {
        var tier = FreeTier()
        guard !subs.isPremium else { return tier }
        let allowed = profiles.active?.playableTopics ?? Set(Topic.core)
        let grade = profiles.active?.effectiveGrade ?? 1
        let offered = Set(packOffers.map(\.id))
        // Once, not once per world: `visiblePacks` asks whether every pack has
        // questions in this language, and that answer is only cheap because
        // ContentCache keeps it. Asking it inside the filter is still twenty
        // rebuilds of the same set for nothing.
        let visible = Set(packStore.visiblePacks.map(\.id))
        let candidates = Worlds.all.filter { w in
            guard !w.isBonusWorld, !isOwned(w), WorldSuitability.suits(w.topic, grade: grade) else { return false }
            if let pack = w.topic.pack { return !offered.contains(pack.id) && visible.contains(pack.id) }
            return allowed.contains(w.topic)
        }
        tier.owned = Worlds.all.filter { !$0.isBonusWorld && isOwned($0) }
        if conv.guestWorlds > 0 {
            let base = candidates.filter { $0.topic.pack == nil }
            let fixed = conv.guestTopics.compactMap(Topic.init(rawValue:))
            let pick = fixed.isEmpty
                ? Self.rotated(base, childID: profiles.activeID, everyDays: conv.guestRotateDays, salt: 2)
                : base.filter { fixed.contains($0.topic) }
            tier.guests = Array(pick.prefix(conv.guestWorlds))
        }
        let pool = candidates.filter { c in !tier.guests.contains { $0.id == c.id } }
        let played = pool.filter { progress.progress(in: $0.id) > 0 }
            .sorted { progress.progress(in: $0.id) > progress.progress(in: $1.id) }
        let rest = Self.rotated(pool.filter { p in !played.contains { $0.id == p.id } },
                                childID: profiles.activeID, everyDays: conv.lockedRotateDays, salt: 1)
        // Six tiles in all, טופי טיים included (Rani): a pack pinned as "new this
        // week" takes one of the locked slots rather than adding a seventh.
        let slots = max(0, conv.lockedShown - packOffers.count)
        tier.locked = Array((played + rest).prefix(slots))
        return tier
    }

    /// A stable shuffle that changes only every `everyDays` days — the same on
    /// the child's iPhone and iPad, unchanged by a relaunch.
    static func rotated(_ worlds: [World], childID: UUID?, everyDays: Int, salt: UInt64, on date: Date = Date()) -> [World] {
        guard worlds.count > 1 else { return worlds }
        let window = Int(date.timeIntervalSinceReferenceDate / 86_400) / max(1, everyDays)
        var h: UInt64 = 0xCBF29CE484222325
        for b in (childID?.uuidString ?? "-").utf8 { h = (h ^ UInt64(b)) &* 0x100000001B3 }
        var rng = SeededRandom(seed: h ^ UInt64(bitPattern: Int64(window &* 0x9E3779B1)) ^ (salt &* 0x9E3779B97F4A7C15))
        var out = worlds
        for i in stride(from: out.count - 1, to: 0, by: -1) { out.swapAt(i, Int(rng.next() % UInt64(i + 1))) }
        return out
    }

    private var enabledWorlds: [World] {
        let allowed = profiles.active?.playableTopics ?? Set(Topic.core)
        let grade = profiles.active?.effectiveGrade ?? 1
        var shown = Worlds.all.filter { world in
            // 💫 The arena isn't a topic — always on, except for pre-readers
            // (the extra-hard pool is text-based).
            if world.isBonusWorld { return grade >= 1 }
            return allowed.contains(world.topic)
        }
        if !subs.isPremium {
            let tier = freeTier
            let arena = shown.filter(\.isBonusWorld)
            shown = tier.owned + tier.guests + tier.locked + arena
        }
        let ordered = Self.orderForToday(shown, childID: profiles.activeID)
        // ⚽ A pack the child hasn't opened yet sits FIRST, with its "חדש!" badge,
        // until the first open — then it joins the daily shuffle like any world.
        guard let cid = profiles.activeID else { return ordered }
        let fresh = ordered.filter { w in
            (w.topic.pack ?? WorldPasses.pass(for: w.topic)).map { item in profiles.active.map { p in PackAccess.has(p, item) } == true && isNewForChild(item, childID: cid) } ?? false
        }
        return fresh + ordered.filter { w in !fresh.contains(w) }
    }

    /// Live packs this family hasn't bought for this child — one quiet tile
    /// each, at the END of the grid; the tap explains and lets the child ask.
    private var packOffers: [QuestionPack] {
        guard let p = profiles.active else { return [] }
        // Only a pack launched THIS WEEK is news pinned next to טופי טיים; an
        // older one takes its turn among the rotating locked worlds instead.
        let offers = packStore.visiblePacks.filter { pack in
            guard !PackAccess.has(p, pack) else { return false }
            if packStore.isFirstDay(pack) { return true }
            return packStore.launchedAt[pack.id].map { Date().timeIntervalSince($0) < 7 * 86_400 } ?? false
        }
        // Screenshot/demo runs treat every pack as launched today — show ONE
        // so the free-tier home reads like a real family's.
        return AppInfo.isDemoRun ? Array(offers.prefix(1)) : offers
    }

    /// Rani: the category cards shouldn't sit in the same spot forever — a child
    /// learns the grid by POSITION and taps the same corner every day, which is
    /// the opposite of the variety the topic balancing is trying to encourage.
    ///
    /// Reordered once a DAY, and deliberately not per render or per visit: a card
    /// that moves while a child is reaching for it is far worse than one that never
    /// moves — they would land on a topic they didn't choose. Being derived from
    /// (day, child) rather than random makes the order stable for the whole day,
    /// identical on the iPhone and the iPad, and unchanged by a relaunch — while
    /// still being different tomorrow.
    ///
    /// The 💫 arena keeps its slot: it is not a category, and a special card that
    /// wanders is just noise.
    static func orderForToday(_ worlds: [World], childID: UUID?, on date: Date = Date()) -> [World] {
        var topics = worlds.filter { !$0.isBonusWorld }
        guard topics.count > 1 else { return worlds }
        var rng = SeededRandom(seed: daySeed(childID: childID, on: date))
        for i in stride(from: topics.count - 1, to: 0, by: -1) {
            topics.swapAt(i, Int(rng.next() % UInt64(i + 1)))
        }
        var next = topics.makeIterator()
        return worlds.map { $0.isBonusWorld ? $0 : (next.next() ?? $0) }
    }

    /// A tile on the kid's home grid — the free path, a world, or a new pack
    /// the family doesn't have yet (the child can only ask a parent).
    enum HomeTile: Identifiable {
        case tofyTime
        case world(World)
        case packOffer(QuestionPack)
        var id: String {
            switch self {
            case .tofyTime: return "tofy_time"
            case .world(let w): return w.id
            case .packOffer(let p): return "offer_\(p.id)"
            }
        }
    }

    /// ⚽ "New" for the child: the pack's launch week (Rani: it stays first with
    /// its badge for a while, not only until the first tap), or never opened yet.
    private func isNewForChild(_ pack: QuestionPack, childID: UUID) -> Bool {
        if !PackKidState.isOpened(pack.id, childID: childID) { return true }
        if let at = packStore.launchedAt[pack.id] { return Date().timeIntervalSince(at) < 7 * 86_400 }
        return false
    }

    private var homeTiles: [HomeTile] {
        var tiles = Self.homeOrder(worlds: enabledWorlds, childID: profiles.activeID, premium: subs.isPremium)
        // ⚽ A new pack sits RIGHT NEXT to טופי טיים (Rani) — wherever Tofy Time
        // landed today — for its launch week, and until the child opens it.
        guard let cid = profiles.activeID else { return tiles }
        let fresh = tiles.filter { t in
            if case .world(let w) = t, let p = w.topic.pack ?? WorldPasses.pass(for: w.topic),
               profiles.active.map({ PackAccess.has($0, p) }) == true { return isNewForChild(p, childID: cid) }
            return false
        }
        // Rani: a NEW pack the family doesn't have yet is also news for the child —
        // it sits up top next to טופי טיים too, sparkling on its launch day.
        let offers: [HomeTile] = packOffers.map { .packOffer($0) }
        guard !fresh.isEmpty || !offers.isEmpty else { return tiles }
        tiles.removeAll { t in fresh.contains { $0.id == t.id } }
        let after = (tiles.firstIndex { if case .tofyTime = $0 { return true } else { return false } } ?? -1) + 1
        tiles.insert(contentsOf: fresh + offers, at: min(after, tiles.count))
        return tiles
    }

    /// ⚽ A new pack the family doesn't have — "ask a parent" (no price, no
    /// store on a child's device), sparkling on its launch day.
    private func offerTile(_ pack: QuestionPack) -> some View {
        FeatureCard(
            emoji: pack.emoji,
            title: pack.name,
            subtitle: pack.tagline,
            gradient: pack.heroGradient,
            glowColor: Color(hex: "2ECC71"),
            badge: tr("✨ חָדָשׁ בְּטוֹפִי"),
            foot: tr("בַּקְּשׁוּ מֵאַבָּא אוֹ אִמָּא 💌")
        ) {
            Haptic.light()
            // One tap is enough: the sparkle has done its job (Rani).
            if let cid = profiles.activeID { PackKidState.markOpened(pack.id, childID: cid) }
            packOffer = pack
        }
        .frame(maxWidth: .infinity)
        .firstDayGlow(packStore.isFirstDay(pack) && !(profiles.activeID.map { PackKidState.isOpened(pack.id, childID: $0) } ?? false))
    }

    /// Where טופי טיים sits among the worlds: FIRST, always. Rani (6.10.26):
    /// "טופי טיים תמיד ראשון" — it picks the questions each child most needs
    /// across every world, so it must never sink into the middle of the grid,
    /// with or without Tofy+. The worlds behind it still move once a day
    /// (`orderForToday`). `premium`/`date` stay for the callers' signature.
    static func homeOrder(worlds: [World], childID: UUID?, premium: Bool, on date: Date = Date()) -> [HomeTile] {
        var tiles: [HomeTile] = worlds.map { .world($0) }
        tiles.insert(.tofyTime, at: 0)
        return tiles
    }

    /// 📣 A tapped discovery push on a CHILD device → the "ask a parent" page
    /// (or nothing, when the child already has the pack).
    private func consumeCampaignLanding() {
        guard let pid = CampaignTracker.shared.pendingPackID else { return }
        CampaignTracker.shared.pendingPackID = nil
        guard let pack = QuestionPacks.find(pid), let p = profiles.active, !PackAccess.has(p, pack) else { return }
        packOffer = pack
    }

    /// 🎁 The first open after a parent bought a pack: one reveal, on the
    /// child's own device, before anything else pops (wheel, chest, events).
    private func maybeRevealPack() {
        guard packReveal == nil, selectedWorld == nil, !showingSmartFeed, !storyPending,
              let p = profiles.active, let pack = PackKidState.pendingReveal(for: p) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Re-read the profile: a demo/cloud change in the meantime must win.
            guard packReveal == nil, let fresh = profiles.active,
                  let still = PackKidState.pendingReveal(for: fresh), still.id == pack.id else { return }
            packReveal = still
        }
    }

    /// Stable across processes and devices. Deliberately NOT `hashValue` — Swift
    /// seeds that randomly per launch, so the order would change on every app
    /// start and differ between a child's two devices.
    private static func daySeed(childID: UUID?, on date: Date) -> UInt64 {
        let day = Int(Calendar.current.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400)
        var h: UInt64 = 0xCBF29CE484222325                      // FNV-1a
        for b in (childID?.uuidString ?? "-").utf8 {
            h = (h ^ UInt64(b)) &* 0x100000001B3
        }
        return h ^ UInt64(bitPattern: Int64(day &* 0x9E3779B1))
    }

    /// Total width cap for the world grid (so the 3 cards stay centered on iPad
    /// instead of pushing to one edge).
    private var worldGridMaxWidth: CGFloat {
        isCompact ? .infinity : 860
    }

    /// Shared side margin for the header card AND the world grid, so both have the
    /// exact same gap from the screen edges (and the same width on iPad).
    private var homeHPad: CGFloat { isCompact ? AppSpacing.sm : AppSpacing.lg }

    var body: some View {
        ZStack {
            // Layered background
            GlassBackdrop()
            SparkleField(count: 14, size: 11)

            ScrollView {
                VStack(spacing: 0) {
                    // The approved header (Rani, 2026-09-07): the gold "טופי" wordmark
                    // with the lion on the right and the round buttons on the left,
                    // ABOVE the glass pane — then the pane, then the worlds.
                    brandRow
                        .frame(maxWidth: worldGridMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, homeHPad)
                    topBar
                        .frame(maxWidth: worldGridMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, homeHPad)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("home")).maxY } action: { headerBottom = $0 }
                    // (The limited-time event banner is now a transient TOAST —
                    // see eventToastOverlay — instead of a permanent row here
                    // that ate a full line of the map all day.)
                    if kidMode.active { kidExitBar }
                    VStack(spacing: AppSpacing.lg) {
                        // The brand + "בחר עולם" line live UNDER the daily
                        // challenge, heading the world grid (Rani tried it as a
                        // top masthead and preferred it back here). No extra top
                        // padding — the gap above טופי should match the gap
                        // between the subtitle and the cards below.
                        heroTitle
                            // 🧭 The worlds' stop: on a phone the first world sits
                            // under the floating minutes panel, so the tour points
                            // at the line that heads them, which is always in view.
                            .coachMark("k.world")
                        // 🌟 The guest worlds, worked out ONCE for the whole grid.
                        // Each tile used to ask `freeTier` for itself, and every
                        // one of those rebuilt the free tier from the full world
                        // list — the same answer, ten times over, every render.
                        let guestIDs = subs.isPremium ? Set<String>() : freeTier.guestIDs
                        LazyVGrid(
                            columns: worldGridColumns,
                            spacing: AppSpacing.md
                        ) {
                            ForEach(homeTiles) { tile in
                                switch tile {
                                case .tofyTime:
                                    FeatureCard(
                                        emoji: "🎲",
                                        title: tr("טוֹפִי טַיים"),
                                        subtitle: Gendered.g(tr("שְׁאֵלוֹת בִּמְיוּחָד בִּשְׁבִילְךָ"), tr("שְׁאֵלוֹת בִּמְיוּחָד בִּשְׁבִילֵךְ")),
                                        gradient: AppGradient.portal,
                                        glowColor: AppColor.companionGlow,
                                        // Free, always (Rani): the one thing on this screen that
                                        // is never behind Tofy+ says so, in mint.
                                        badge: tr("✨ חינם"),   // always — טופי טיים is free for everyone (Rani)
                                        badgeTint: Color(hex: "8CFFC4")
                                    ) {
                                        // No companion line here — we leave this screen
                                        // immediately, so a bubble would only flash & clip.
                                        Haptic.light()
                                        showingSmartFeed = true
                                    }
                                    .frame(maxWidth: .infinity)
                                    .coachMark("k.tofyTime")
                                case .packOffer(let pack):
                                    offerTile(pack)
                                case .world(let world):
                                    // ⚽ A bought pack opens with or without Tofy+ — the
                                    // parent paid for it on its own (Rani).
                                    // A real pack, or a 30-day pass on a base world — either is
                                    // "the parent bought this world for this child".
                                    let item = world.topic.pack ?? WorldPasses.pass(for: world.topic)
                                    let owned = item.map { it in profiles.active.map { p in PackAccess.has(p, it) } ?? false } ?? false
                                    let pack: QuestionPack? = owned ? item : nil
                                    let packNew = pack.map { p in profiles.activeID.map { isNewForChild(p, childID: $0) } ?? false } ?? false
                                    let neverOpened = pack.map { p in profiles.activeID.map { !PackKidState.isOpened(p.id, childID: $0) } ?? false } ?? false
                                    // 🌟 A free "guest" world (founder's knob) plays like Tofy+.
                                    let isGuest = !subs.isPremium && pack == nil && guestIDs.contains(world.id)
                                    let locked = !subs.isPremium && pack == nil && !isGuest
                                    let room = progress.progress(in: world.id)
                                    // A locked world the child ALREADY played (their gift ended):
                                    // progress kept, and the foot says so — no failure language.
                                    let girl = profiles.active?.gender == .girl
                                    let continueFoot: String? = locked && room > 0
                                        ? tr("חֶדֶר \(max(1, min(room + 1, world.rooms)))/\(world.rooms) · \(girl ? tr("רוֹצָה") : tr("רוֹצֶה")) לְהַמְשִׁיךְ?") : nil
                                    WorldCard(
                                        // Premium unlocks every world (that's what the
                                        // subscription buys). Stars are now a spendable
                                        // currency, so they no longer gate worlds —
                                        // otherwise buying cosmetics could re-lock them.
                                        world: world,
                                        isUnlocked: subs.isPremium || pack != nil || isGuest,
                                        currentRoom: room,
                                        starsHeld: progress.stars,
                                        subscriptionLocked: locked,
                                        badgeOverride: packNew ? tr("✨ חָדָשׁ!") : (isGuest ? tr("🌟 אוֹרֵחַ הַשָּׁבוּעַ") : nil),
                                        footOverride: continueFoot,
                                        // Glows on its launch day only until the child taps it (Rani).
                                        pulse: neverOpened && (pack.map { p in profiles.activeID.map { PackKidState.isFirstDay(p.id, childID: $0) } ?? false } ?? false),
                                        tier: progress.worldTier(in: world.id),
                                        visited: progress.hasVisited(world.id),
                                        suggested: world.id == suggestedWorldID,
                                        girl: girl
                                    ) {
                                        if let pack, let cid = profiles.activeID {
                                            PackKidState.markOpened(pack.id, childID: cid)
                                            selectedWorld = world
                                        } else if subs.isPremium || isGuest {
                                            selectedWorld = world
                                        } else if true {
                                            // Rani: the kid screen never sells — a
                                            // locked world asks a parent for THAT world.
                                            Haptic.light()
                                            HouseholdManager.shared.bumpFunnel("lockedTapped")
                                            askWorld = world
                                        } else {
                                            // Until they subscribe, only "טופי טיים"
                                            // is playable — the worlds open the paywall.
                                            Haptic.light()
                                            showingPaywall = true
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }

                            // 🎮 Games LAST in the grid (Rani): learning worlds
                            // come first in the child's choice order; the arcade
                            // is the dessert at the end.
                            FeatureCard(
                                emoji: "🎮",
                                title: tr("מִשְׂחָקִים"),
                                // Daily warm-up gate: games open after a few CORRECT
                                // answers of real learning (Rani). Framed as a goal,
                                // never a lock — no grey-out, no failure language.
                                subtitle: gamesUnlockedToday
                                    ? tr("מֵרוֹץ נָכוֹן/לֹא · הַתְאָמַת זוּגוֹת")
                                    : tr("עוֹנִים \(gamesGateTarget) נְכוֹנוֹת — וְנִפְתָּח! 💪"),
                                gradient: LinearGradient(colors: [Color(hex: "EF476F"), Color(hex: "9B5DE5")],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                                glowColor: Color(hex: "EF476F"),
                                badge: !subs.isPremium ? tr("👑 טוֹפִי+")
                                    : gamesUnlockedToday ? nil
                                    : "\(min(progress.correctToday, gamesGateTarget))/\(gamesGateTarget) ✅",
                                foot: gamesUnlockedToday ? tr("🎮 פָּתוּחַ הַיּוֹם") : tr("חִמּוּם יוֹמִי"),
                                footFrac: gamesUnlockedToday ? nil
                                    : Double(min(progress.correctToday, gamesGateTarget)) / Double(max(1, gamesGateTarget))
                            ) {
                                Haptic.light()
                                requirePremium {
                                    if gamesUnlockedToday {
                                        showingGames = true
                                    } else {
                                        companion.cheer(tr("עוֹד \(gamesGateRemaining) תְּשׁוּבוֹת נְכוֹנוֹת וְהַמִּשְׂחָקִים נִפְתָּחִים! 🎮"))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .coachMark("k.games")
                        }
                    }
                    .frame(maxWidth: worldGridMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, homeHPad)
                    // Breathing room between the header card and the world grid
                    // (compact: none — the grid VStack's own spacing already
                    // matches the subtitle→cards gap, so טופי sits evenly).
                    .padding(.top, AppSpacing.md)
                    // Bottom inset just tall enough for the floating CTA panel
                    // (two pills + the protect-code line ≈ 180pt) with a small
                    // margin — 360 left a huge dead gap after the last row
                    // (Rani, on-device). The companion floats and never needs
                    // scroll room of its own.
                    .padding(.bottom, isShort && bottomPanelHeight > 0
                             ? bottomPanelHeight + 8
                             : (isCompact ? 220 : 190))
                }
            }

            // Bottom CTAs floating panel — over a soft scrim, so the tiles
            // scrolling underneath fade out instead of showing through the glass.
            VStack {
                Spacer()
                bottomCTAs
                    .coachMark("k.minutes")
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, isShort ? 26 : 48)
                    .padding(.bottom, isShort ? AppSpacing.sm : AppSpacing.md)
                    .background(
                        LinearGradient(stops: [.init(color: .clear, location: 0),
                                               .init(color: Color(hex: "2A1E5C").opacity(0.72), location: 0.35),
                                               .init(color: Color(hex: "2A1E5C").opacity(0.9), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                            // The sides too: on the foldable the system's vertical
                            // bar takes a safe-area inset on one side, and a scrim
                            // stopping there left a hard seam against the gradient.
                            .ignoresSafeArea(edges: [.bottom, .horizontal])
                    )
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomPanelHeight = $0 }
            }


            // Companion wanders the screen and is also draggable.
            // On iPhone we keep the wander zone tighter so it doesn't park
            // on top of world cards in the middle of the grid. On the foldable
            // there is no free screen to wander in at all — it stood on
            // "עולם הכדורגל" and cut its name — so the buddy moves into the
            // rail (see `.sideRail`) and only its speech comes out.
            if !display.hasBarStrip {
            FloatingCompanion(
                controller: companion,
                profile: profiles.active,
                onTap: {
                    Haptic.light()
                    showingShop = true
                },
                showGift: progress.dailyChestAvailable,
                onGiftTap: { showDailyChest = true },
                size: companionSize,
                // Keep the buddy (and the gift above its head) BELOW the taller
                // header card so it never parks on top of the stats.
                topInset: isShort && headerBottom > 0
                    ? max(headerBottom + companionSize * 0.35, 120)   // + the gift riding on its head
                    : (isCompact ? 300 : 230),
                bottomInset: isShort && bottomPanelHeight > 0 ? bottomPanelHeight : (isCompact ? 220 : 200),
                horizontalInset: AppSpacing.lg
            )
            }
        }
        // 🧭 Once per child: one point per thing on this screen.
        .coachTour(kidTourSteps, forKid: true, isActive: $kidTourActive) {
            if let id = profiles.activeID { CoachTours.markDone(Self.kidTourKey(id)) }
        }
        // 💬 What the rail's buddy says — over the bottom scrim, where it can
        // cover nothing that matters, instead of over a world card.
        .overlay(alignment: .bottom) {
            if display.hasBarStrip {
                // Beside the buddy, which lives at the BOTTOM of the rail — so
                // the bubble opens over the bottom scrim, not over a world card
                // (it was landing a whole panel-height too high).
                InlineBuddyBubble(controller: companion, clearance: 0)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, 8)
            }
        }
        // 📐 The header and the floating buddy measure in the same space.
        .coordinateSpace(name: "home")
        // 🎚 The kid's own rail in the foldable's bar strip: the three round
        // buttons that used to head the screen. ⭐ and 💎 stay on the screen
        // itself, beside the child's name (Rani) — they are part of the card,
        // not chrome.
        .sideRail {
            SideRailButton(emoji: "🛍️", label: tr("חֲנוּת")) { showingShop = true }
            SideRailButton(emoji: "🏆", label: tr("חֲבֵרִים")) { showingLeaderboard = true }
            SideRailButton(emoji: "⚙️", label: tr("הגדרות")) { showingParentGate = true }
            SideRailDivider()
            // 🎁 The daily chest rides beside the buddy, exactly as it rides on
            // its head everywhere else.
            if progress.dailyChestAvailable {
                SideRailButton(emoji: "🎁", label: tr("מַתָּנָה")) { showDailyChest = true }
            }
            Button {
                Haptic.light()
                showingShop = true
            } label: {
                InlineBuddy(controller: companion, profile: profiles.active, width: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("טופי"))
        }
        // Returning from the smart adventure with the warm-up freshly completed →
        // celebrate the games opening (the map's onAppear doesn't re-fire under
        // a dismissed fullScreenCover, so listen to the cover's flag directly).
        .onChangeCompat(of: showingSmartFeed) { _, showing in
            if !showing { celebrateGamesUnlockIfNeeded() }
        }
        // Window transfer completion: the other device's row updates live; the
        // moment its window is confirmed gone we finish the handoff.
        .onChangeCompat(of: household.devicesByChild) { _, _ in
            completeWindowTransferIfReady()
        }
        // 🎮 The open didn't happen — the child came back here, so say why in a
        // way that never sounds like a failure.
        .onChangeCompat(of: progress.openWindowMessage) { _, _ in
            speakOpenWindowMessageIfNeeded()
        }
        .onAppear {
            lastSeenStars = progress.stars
            speakOpenWindowMessageIfNeeded()
            celebrateGamesUnlockIfNeeded()
            ChoreStore.shared.startIfNeeded()   // 🧹 live chores for the tile
            // 🔐 live view of the child's single authoritative play window.
            if let cid = profiles.activeID { PlayWindowLeaseManager.shared.startIfNeeded(childID: cid) }
            // 🎓 No grade yet (families from before grades existed): the kid
            // picks their own — synced to the parent flagged for verification.
            if let p = profiles.active, p.grade == nil {
                showChildGradePicker = true
            }
            // 🎒 September 1st: the child advanced a grade — celebrate once.
            else if let p = profiles.active, SchoolYearCelebration.shouldCelebrate(p), !AppInfo.isDemoRun {
                showSchoolYearParty = true
            }
            // 📖 First time in Tofy after an update: the story of everything
            // new, opening by itself. Marked on SHOW, so leaving the app in the
            // middle cannot make it greet the child again tomorrow.
            else if let p = profiles.active, !AppInfo.isDemoRun, WhatsNewStories.kidShouldShow(for: p) {
                whatsNewStory = WhatsNewStories.kidItems(for: p)
                WhatsNewStories.markKidShown(for: p)
                showWhatsNewStory = !whatsNewStory.isEmpty
            }
            // Keep my friends-board score live during play (even with the board
            // closed), so friends always see my current stars.
            FriendsManager.shared.beginScoreSync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                greetIfNeeded()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                heroAppeared = true
            }
            suggestedWorldID = WorldTiers.suggestedNewWorld(excluding: "")?.id
            announceWaitingBoss()
            checkWorldUnlocks()
            // 🍏 Just joined: the parent is holding the phone — say what Apple's
            // own Screen Time may be doing, before anything else.
            if settings.deviceRole == .child, !storyPending,
               UserDefaults.standard.bool(forKey: AppleScreenTimeTips.pendingKey) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showAppleTips = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { maybeStartKidTour() }
            // Event splash: once a day — see `maybeShowEventSplash`.
            maybeShowEventSplash()
            // Returning after being away earns a "welcome back" spin.
            progress.grantComebackWheelIfReturning()
            // Wheel pops when we return to the map after earning a free spin.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                maybeAutoPresentWheel()
            }
            maybePromptAppLockSetup()
            // Refresh this child device's "last seen" so the parent sees it live,
            // and re-publish this child's local progress to the cloud — this is
            // the source of truth and restores the parent's view if the cloud doc
            // was ever stale/zeroed.
            if settings.deviceRole == .child, let cid = profiles.activeID {
                Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
                RemoteSyncManager.shared.pushNow()
                // 📈 The child saw locked worlds today (funnel step 1, once a day).
                if !subs.isPremium, !freeTier.locked.isEmpty { HouseholdManager.shared.noteLockedSeen() }
                // A registered child device needs notification permission too (for
                // live-game invites + parent live events). We never asked on the
                // child side before — prompt now, but ONLY if undecided, so it also
                // catches devices that registered before this existed and never
                // gets re-shown to anyone who already chose.
                if ChildTimeApp.demoScreen == nil {
                    Task { await PushManager.shared.requestAuthorizationIfNotDetermined() }
                }
            }
        }
        // A fullScreenCover doesn't re-fire the map's .onAppear when it closes,
        // so check the wheel when a play session actually ends.
        .onChangeCompat(of: showingSmartFeed) { _, shown in
            if !shown { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { maybeAutoPresentWheel() } }
        }
        .onChangeCompat(of: selectedWorld?.id) { _, world in
            if world == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { maybeAutoPresentWheel() } }
        }
        .onChangeCompat(of: progress.stars) { _, new in
            if new > lastSeenStars {
                companion.cheer()
            }
            lastSeenStars = new
            checkWorldUnlocks()
        }
        // A world opens to "how do you want to play?" (Rani, 2026-10-03) — or
        // straight into its questions when the parent switched games off for
        // this child, or when there is nothing else to choose. The tile above
        // already did the pack / ask-a-parent gating before setting this.
        .fullScreenCover(item: $selectedWorld) { world in
            WorldEntryView(world: world)
        }
        // 🏆 "עולם חדש" after a boss: close the world on screen, open the next.
        .onReceive(WorldRouter.shared.$pending) { next in
            guard let next else { return }
            WorldRouter.shared.pending = nil
            selectedWorld = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { selectedWorld = next }
        }
        .fullScreenCover(item: $packReveal) { pack in
            PackRevealView(pack: pack, isGift: profiles.active.map { PackAccess.isGift($0, pack) } ?? true, onStart: {
                if let cid = profiles.activeID {
                    PackKidState.markRevealed(pack.id, childID: cid)
                    PackKidState.markOpened(pack.id, childID: cid)
                }
                packReveal = nil
                if let world = Worlds.all.first(where: { $0.topic == pack.topic }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { selectedWorld = world }
                }
            }, onSkip: {
                if let cid = profiles.activeID { PackKidState.markRevealed(pack.id, childID: cid) }
                packReveal = nil
            })
        }
        .fullScreenCover(item: $packOffer) { pack in
            PackAskParentView(pack: pack) { packOffer = nil }
        }
        .onAppear {
            maybeRevealPack(); consumeCampaignLanding()
            CampaignTracker.shared.checkPopup(role: "child", profiles: profiles.active.map { [$0] } ?? [], premium: subs.isPremium)
        }
        .overlay {
            if let c = campaignTracker.popup, packReveal == nil {
                CampaignPopupView(campaign: c, isChild: true, onAct: {
                    campaignTracker.popup = nil
                    campaignTracker.popupTapped(c)   // → the ask-a-parent page via consumeCampaignLanding
                }, onLater: { campaignTracker.popup = nil })
            }
        }
        // 🔄 A newer Tofy exists. The child is TOLD, and pointed at a grown-up —
        // never at the App Store, which they could not finish and must not reach.
        .sheet(isPresented: $showUpdateNotice) {
            UpdateKidNotice { showUpdateNotice = false }
                .presentationDetents([.medium])
        }
        .onAppear {
            // One sheet at a time: a campaign pop-up outranks this.
            if case .recommended = AppUpdateConfig.shared.state,
               campaignTracker.popup == nil, !storyPending { showUpdateNotice = true }
        }
        .onChangeCompat(of: CampaignTracker.shared.pendingPackID) { _, _ in consumeCampaignLanding() }
        .onChangeCompat(of: profiles.active?.ownedPacks.count ?? 0) { _, _ in maybeRevealPack() }
        .fullScreenCover(isPresented: $showDailyChest) {
            DailyChestView()
        }
        .overlay(alignment: .top) {
            if let msg = challengeCelebration {
                Text(msg)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(AppColor.successMint.opacity(0.95), in: Capsule())
                    .glow(AppColor.successMint, radius: 12)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .environment(\.layoutDirection, .app)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: challengeCelebration)
        .sheet(isPresented: $showingParentGate) {
            // On the child device the gate opens ONLY the device-local parent
            // controls (app-lock + manual unlock) — everything else is on the
            // parent's own device. respectSession:false — THE DEVICE IS IN THE
            // KID'S HANDS: after the parent used the controls once and left,
            // the next gear tap must ask for the code again (reported: it
            // walked straight back in off the session unlock).
            ParentGateView(respectSession: false) {
                ChildDeviceControlsView()
                    .environment(\.layoutDirection, .app)
            }
        }
        .fullScreenCover(isPresented: $showingAppLockSetup) {
            ChildAppLockSetupView()
                .environment(\.layoutDirection, .app)
        }
        // The child's "protect my time" code — verify before spending minutes,
        // plus the set/change/remove flows.
        .fullScreenCover(item: $playPINSheet) { sheet in
            playPINCover(sheet)
                .environment(\.layoutDirection, .app)
        }
        .fullScreenCover(isPresented: $showingShop) {
            ShopView()
        }
        .fullScreenCover(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
        // The live friends quiz — ONE flow cover for setup → lobby → game, so
        // there's never a second presentation racing the first.
        .fullScreenCover(isPresented: Binding(
            get: { liveGame.isSettingUp || liveGame.game != nil },
            set: { if !$0 { Task { await liveGame.leaveGame() } } })) {
            LiveGameFlowView()
        }
        // A friend invite link opened the app → jump to the leaderboard, which
        // consumes the pending code and adds the friend.
        .onChangeCompat(of: friends.pendingFriendCode) { _, code in
            if code != nil { showingLeaderboard = true }
        }
        // A game deep link / push tap → join the game (the cover shows it).
        .onChangeCompat(of: liveGame.pendingGameID) { _, id in
            guard let id else { return }
            liveGame.pendingGameID = nil
            Task { await liveGame.joinGame(id) }
        }
        // The leaderboard's "create game" button asked to open setup. Delay a beat
        // so the leaderboard cover finishes dismissing before this one presents.
        .onChangeCompat(of: liveGame.wantsNewGame) { _, want in
            guard want else { return }
            liveGame.wantsNewGame = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { liveGame.openSetup() }
        }
        // …and its "join" on a waiting invite — same beat, then join.
        .onChangeCompat(of: liveGame.wantsJoinGameID) { _, id in
            guard let id else { return }
            liveGame.wantsJoinGameID = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { Task { await liveGame.joinGame(id) } }
        }
        .onAppear {
            if friends.pendingFriendCode != nil { showingLeaderboard = true }
            if let id = liveGame.pendingGameID { liveGame.pendingGameID = nil; Task { await liveGame.joinGame(id) } }
            liveGame.startInvitesListener()
        }
        .onDisappear { liveGame.stopInvitesListener() }
        // Leaving Kid Mode — a SINGLE authentication (Face ID, with code fallback).
        // On success we mark the session unlocked and exit immediately, so the
        // dashboard doesn't re-prompt: one Face ID, no separate "are you sure?".
        // respectSession:false so this gate itself always authenticates.
        .sheet(isPresented: $showKidExit) {
            ParentGateView(allowClose: true,
                           gateTitle: tr("יְצִיאָה מִמַּצַּב יֶלֶד וְשִׁחְרוּר נְעִילַת הַמַּכְשִׁיר"),
                           gateReason: tr("אַמְּתוּ זֶהוּת כְּדֵי לָצֵאת מִמַּצַּב יֶלֶד"),
                           useFaceID: true,
                           respectSession: false,
                           onAuthorized: {
                               KidModeManager.shared.exit()
                               showKidExit = false
                           }) {
                Color.clear
            }
            .environmentObject(settings)
            .environment(\.layoutDirection, .app)
        }
        // A friend started a game I'm invited to → pop a toast at the top (far more
        // visible than the small red dot). It auto-hides after a few seconds; the
        // red dot on the controller button stays as the persistent reminder.
        .overlay(alignment: .top) {
            if inviteBannerVisible, let invite = liveGame.invites.first,
               liveGame.game == nil, !liveGame.isSettingUp {
                gameInviteBanner(invite)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: inviteBannerVisible)
        .onChangeCompat(of: liveGame.invites.count) { old, new in
            guard new > old else { if new == 0 { inviteBannerVisible = false }; return }
            Haptic.success(); SoundPlayer.shared.play(.portalAppear)
            inviteBannerVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { inviteBannerVisible = false }
        }
        .fullScreenCover(isPresented: $showingGames) {
            GamesMenuView { showingGames = false }
        }
        .fullScreenCover(isPresented: $showingChores) {
            ChoresKidView { showingChores = false }
                .environmentObject(profiles)
                .environmentObject(progress)
                .environment(\.layoutDirection, .app)
        }
        .fullScreenCover(isPresented: $showingWheel) {
            LuckyWheelView { showingWheel = false }
        }
        .fullScreenCover(isPresented: $showingSmartFeed) {
            // Smart Feed play — grants minutes (capped by the daily maximum).
            QuestionRunnerView(mode: .smartFeed, purpose: .earnTime)
        }
        .fullScreenCover(item: $infoSheet) { sheet in
            challengeInfoScreen(for: sheet)
        }
        // Kids Category (App Review guideline 1.3): commerce must sit behind a
        // parental gate that can't be bypassed. respectSession:false so this ALWAYS
        // re-authenticates — an earlier unlock this session must not open the store.
        .fullScreenCover(isPresented: $showingPaywall) {
            // Rani (2026-09-06): everything is bought from the PARENT's home —
            // the kid screen never shows a gate or a price, on any device. So
            // a locked tile just asks a parent; the request lands on their
            // phone (banner + push) and opens Tofy+ there.
            AskParentView(onClose: { showingPaywall = false })
                .environmentObject(settings)
        }
        .fullScreenCover(item: $askWorld) { world in
            AskParentView(world: world, onClose: { askWorld = nil })
                .environmentObject(settings)
        }
        .sheet(isPresented: $showingChildSettings) {
            if let active = profiles.active {
                ProfileEditorView(mode: .edit(active)) { updated in
                    profiles.update(updated)
                } onDelete: { profile in
                    profiles.remove(profile)
                }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .app)
            }
        }
        .fullScreenCover(isPresented: $showEventSplash) {
            // The daily event as a real MOMENT (Rani): full pop-up like the
            // lucky wheel — big emoji, one "let's go", easy close.
            if let event = GameEvent.current() {
                let copy = eventCopy(event)
                ChallengeInfoView(
                    emoji: event.emoji,
                    title: copy.title,
                    message: copy.message,
                    ctaTitle: tr("יַאלְלָה, בּוֹאוּ נֶאֱסֹף! 🚀"),
                    onCTA: {
                        showEventSplash = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showingSmartFeed = true }
                    },
                    onClose: { showEventSplash = false }
                )
                .environment(\.layoutDirection, .app)
            } else {
                Color.clear.onAppear { showEventSplash = false }
            }
        }
        .fullScreenCover(isPresented: $showChildGradePicker) {
            if let p = profiles.active {
                ChildGradePickerView(profile: p) { g in
                    var updated = p
                    updated.grade = g
                    updated.gradeSchoolYear = Profile.schoolYear()
                    updated.gradeSetByChild = true
                    profiles.update(updated)
                    showChildGradePicker = false
                }
            }
        }
        // 📖 "מה חדש" as a story. It closes itself to this screen when the last
        // one ends, and ✕ does exactly the same thing — never a button that
        // moves the child somewhere else (Rani).
        // 🧭 The lock step (ChildLockSetupView) just closed — the tour can run.
        .onChangeCompat(of: lockSetupPending) { _, pending in
            if !pending { DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { maybeStartKidTour() } }
        }
        .sheet(isPresented: $showAppleTips, onDismiss: {
            UserDefaults.standard.set(false, forKey: AppleScreenTimeTips.pendingKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { maybeStartKidTour() }
        }) {
            AppleScreenTimeTipsSheet { showAppleTips = false }
        }
        // 📖 The story went first; now the pop-ups that waited for it.
        .onChangeCompat(of: showWhatsNewStory) { _, shown in
            guard !shown else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { presentDeferredPopups() }
        }
        .fullScreenCover(isPresented: $showWhatsNewStory) {
            WhatsNewStoryView(audience: .child, items: whatsNewStory) {
                // ⭐/💎 for having watched — the chips the last story shows.
                progress.addStars(WhatsNewStories.watchStars)
                progress.addDiamonds(WhatsNewStories.watchDiamonds)
                showWhatsNewStory = false
            }
        }
        .fullScreenCover(isPresented: $showSchoolYearParty) {
            if let p = profiles.active {
                SchoolYearCelebrationView(
                    gradeName: Profile.gradeDisplayName(p.effectiveGrade),
                    childName: p.name,
                    gender: p.gender
                ) { showSchoolYearParty = false }
            }
        }
        .fullScreenCover(isPresented: $showingDemo) {
            ZStack(alignment: .topTrailing) {
                DemoView()
                Button { showingDemo = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
        }
    }

    /// A friendly "you're invited!" banner that drops in at the top of the home
    /// screen, with the host's name and a one-tap Join.
    private func gameInviteBanner(_ invite: LiveGameInvite) -> some View {
        HStack(spacing: 12) {
            Text("🎮").font(.system(size: 30))
            VStack(alignment: .trailing, spacing: 2) {
                Text(tr("הַזְמָנָה מִ\(invite.hostName)!"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(tr("מִשְׂחָק חִידוֹן נֶגֶד חֲבֵרִים"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button {
                Haptic.medium()
                Task { await liveGame.joinGame(invite.id) }
            } label: {
                Text(tr("הִצְטָרְפוּ"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.textOnLight)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(AppColor.starGold))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).fill(AppColor.gemPurple))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
        .glow(AppColor.gemPurple, radius: 14)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .frame(maxWidth: 520)
        .environment(\.layoutDirection, .app)
        .eraseToAnyView()
    }

    /// Slim "exit Kid Mode" bar shown UNDER the top-bar buttons while the parent's
    /// phone is acting as a kid device — so it never overlaps the action buttons.
    private var kidExitBar: some View {
        Button {
            Haptic.light()
            showKidExit = true
        } label: {
            // 🔓 Bigger, and it says what it actually does — a parent taking the
            // phone back also wants the device unlocked, and "יציאה ממצב ילד"
            // alone did not say that (Rani).
            HStack(spacing: 9) {
                Image(systemName: "lock.open.fill").font(.system(size: 16, weight: .bold))
                Text(tr("יְצִיאָה מִמַּצַּב יֶלֶד וְשִׁחְרוּר נְעִילַת הַמַּכְשִׁיר"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .lineLimit(2).minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 15)
            .background(Capsule().fill(Color(hex: "EF4655")))
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: Color(hex: "EF4655").opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.juicy)
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .eraseToAnyView()
    }

    // MARK: - Top bar

    private var topBar: some View {
        let avatarSize: CGFloat = isCompact ? 52 : 60
        let btnSize: CGFloat = isCompact ? 44 : 50
        // ONE glass pane holds the whole header (the approved "זכוכית" design):
        // identity + round glass nav buttons, the 4-stat strip, then the two
        // twin insets (daily challenge · chores). Forced LTR so the avatar sits
        // on the left and the buttons on the right, matching the mockup.
        _ = btnSize
        return VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                identityBlock(avatar: avatarSize)
                Spacer(minLength: 6)
                walletStats.coachMark("k.wallet")
            }
            statsPanel
            HStack(spacing: 10) {
                dailyChallengeCard.coachMark("k.challenge")
                choresTopCard.coachMark("k.chores")
            }
            .fixedSize(horizontal: false, vertical: true)   // twins: same height, from content
        }
        // RTL like the mockup (Rani): avatar + name on the RIGHT, the round
        // buttons on the left with ⚙️ the leftmost; אתגר יומי right, מטלות left.
        .environment(\.layoutDirection, .app)
        .padding(16)
        .glassPane(radius: 24)
        .padding(.top, AppSpacing.sm)
        .eraseToAnyView()
    }

    /// The gold wordmark ("טופי", or "טופי+" for a Tofy+ family) with the
    /// lion beside it, and the three round glass buttons on the other side.
    private var brandRow: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
                Text(subs.isPremium ? tr("טופי+") : tr("טופי"))
                    .font(.system(size: heroTitleSize, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "FFF6C4"), Color(hex: "FFD23F"), Color(hex: "FFB347")],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: "A05F0A").opacity(0.85), radius: 0, y: 2)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 6)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .scaleEffect(heroAppeared ? 1 : 0.5)
                    .opacity(heroAppeared ? 1 : 0)
                // Our own lion — the one from the app icon, waving — not an emoji (Rani).
                if let lion = Character2DImages.image("lion") {
                    // Head and waving paw only, the way Rani cut it: the top of the
                    // full-body PNG, transparent, the body fading out under the scarf.
                    // As tall as the wordmark's letters, no taller (Rani).
                    let d: CGFloat = isCompact ? 32 : 38
                    Image(uiImage: lion)
                        .resizable().scaledToFill()
                        .frame(width: d, height: d * 1.22, alignment: .top)   // head + the whole paw
                        .clipped()
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                                     .init(color: .black, location: 0.84),
                                                     .init(color: .clear, location: 1)],
                                             startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                } else {
                    Text("🦁").font(.system(size: isCompact ? 32 : 38))
                }
            }
            Spacer(minLength: 6)
            // 🎚 On the foldable these three live in the bar's strip instead —
            // see `.sideRail` on the body.
            if !display.hasBarStrip { navButtonsRow(size: isCompact ? 44 : 50) }
        }
        .environment(\.layoutDirection, .app)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, 2)
        .eraseToAnyView()
    }

    /// ⭐ stars · 💎 diamonds beside the name (Rani): the number on the name's
    /// line, the label on the grade's line. On iPad two more: 💝 gift minutes
    /// and ⏱ minutes earned.
    private var walletStats: some View {
        HStack(spacing: isCompact ? 12 : 18) {
            walletStat("⭐ " + progress.stars.currencyShort, tr("כּוֹכָבִים")) { infoStat = .stars }
            walletStat("💎 " + progress.diamonds.currencyShort, tr("יַהֲלוֹמִים")) { infoStat = .diamonds }
            if !isCompact {
                walletStat("💝 \(progress.parentGiftMinutes)", tr("דַּקּ׳ מַתָּנָה")) { infoStat = .gift }
                walletStat("⏱ \(progress.pendingMinutes)", tr("דַּקּ׳ לְשַׂחֵק")) { infoStat = .minutes }
            }
        }
        .environment(\.layoutDirection, .app)
        .eraseToAnyView()
    }

    /// Two fixed-height lines so every stat sits exactly on the name / grade lines.
    private func walletStat(_ value: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { Haptic.light(); action() } label: {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: isCompact ? 14.5 : 16, weight: .black, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    .frame(height: isCompact ? 22 : 26)
                Text(label)
                    .font(.system(size: isCompact ? 11 : 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(height: 16)
            }
        }
        .buttonStyle(.plain)
    }

    /// One horizontal twin card: the ring on the right, the title, one status
    /// line and the track — both header cards use it so they read as twins.
    private func twinCard<Ring: View, Status: View>(ring: Ring, title: String, status: Status, frac: CGFloat) -> some View {
        HStack(spacing: 10) {
            ring.frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: isCompact ? 13.5 : 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                status
                headerTrack(frac: frac,
                            fill: LinearGradient(colors: [.white, .white], startPoint: .leading, endPoint: .trailing),
                            glowColor: .clear, tip: nil)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassInset(radius: 16)
    }

    /// Daily challenge — a compact vertical card, the exact TWIN of
    /// `choresTopCard` (Rani: same size, side by side). Icon ring → title →
    /// one status line → progress track. Tap → the explainer sheet.
    private var dailyChallengeCard: some View {
        let target = ProgressStore.dailyChallengeTarget
        let done = progress.dailyChallengeProgress
        let ready = progress.dailyChallengeRewardReady
        let claimed = progress.dailyChallengeClaimed
        let frac = (ready || claimed) ? 1 : CGFloat(min(done, target)) / CGFloat(max(1, target))
        let ring = ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "FFB347"), Color(hex: "FF5E3A")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1.5))
                .glow(AppColor.flameOrange, radius: challengePulse ? 12 : 5)
            Text("🔥").font(.system(size: 21)).scaleEffect(challengePulse ? 1.12 : 0.95)
        }
        let status = Group {
            if claimed {
                Text(tr("כָּל הַכָּבוֹד! נִפְגָּשִׁים מָחָר 🌙"))
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88)).lineLimit(1).minimumScaleFactor(0.6)
            } else if ready {
                HStack(spacing: 4) {
                    Text("🎁").font(.system(size: 13)).scaleEffect(challengePulse ? 1.18 : 1)
                    Text(tr("פִּתְחוּ!")).font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight).lineLimit(1).fixedSize()
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(AppGradient.gold, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1.2))
                .glow(AppColor.starGold, radius: challengePulse ? 10 : 5)
            } else {
                Text(tr("\(done) מִתּוֹךְ \(target)"))
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88)).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        return Button {
            Haptic.light()
            requirePremium { infoSheet = .dailyChallenge }
        } label: {
            twinCard(ring: ring, title: tr("אֶתְגָּר יוֹמִי"), status: status, frac: frac)
        }
        .buttonStyle(.juicy)
        .environment(\.layoutDirection, .app)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                challengePulse = true
            }
        }
        .eraseToAnyView()
    }

    /// Both header cards are exactly this tall — they must read as twins.
    private static let headerCardHeight: CGFloat = 136

    /// The shared progress track at the foot of both header cards.
    private func headerTrack(frac: CGFloat, fill: LinearGradient, glowColor: Color, tip: String?) -> some View {
        GeometryReader { geo in
            let w = frac <= 0 ? 0 : max(16, geo.size.width * min(frac, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                if w > 0 {
                    Capsule()
                        .fill(fill)
                        .frame(width: w)
                        .glow(glowColor, radius: 4)
                        .overlay(alignment: .trailing) {
                            if let tip {
                                Text(tip)
                                    .font(.system(size: 13))
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                                    .offset(y: -1)
                            }
                        }
                }
            }
        }
        .frame(height: 10)
    }

    /// Claim the daily-challenge prize (called from the explainer's CTA).
    private func claimChallenge() {
        let grant = progress.claimDailyChallenge()
        Haptic.success()
        SoundPlayer.shared.play(.streakUp)
        let total = grant.addedToday + grant.bankedForTomorrow
        challengeCelebration = tr("🎉 כָּל הַכָּבוֹד! +\(15 + min(progress.dayStreak, 7) * 2) 💎") + (total > 0 ? tr(" וְ-\(total) דַּקּוֹת") : "")
        companion.hype(Gendered.g(tr("שָׁמַרְתָּ עַל הָרֶצֶף! 🔥"), tr("שָׁמַרְתְּ עַל הָרֶצֶף! 🔥")))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { challengeCelebration = nil }
    }

    /// Close any open explainer, then jump into the Smart Feed to play/earn.
    private func enterSmartFeedFromInfo() {
        infoSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showingSmartFeed = true }
    }

    @ViewBuilder
    private func challengeInfoScreen(for sheet: InfoSheet) -> some View {
        switch sheet {
        case .dailyChallenge:
            let target = ProgressStore.dailyChallengeTarget
            let done = progress.dailyChallengeProgress
            let ready = progress.dailyChallengeRewardReady
            let claimed = progress.dailyChallengeClaimed
            let prize = 15 + min(progress.dayStreak, 7) * 2
            ChallengeInfoView(
                emoji: "🔥",
                title: tr("אֶתְגָּר יוֹמִי"),
                message: claimed
                    ? Gendered.g(tr("הִשְׁלַמְתָּ אֶת הָאֶתְגָּר הַיּוֹם — כָּל הַכָּבוֹד! 🎉\nאֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק וְלִצְבֹּר עוֹד."), tr("הִשְׁלַמְתְּ אֶת הָאֶתְגָּר הַיּוֹם — כָּל הַכָּבוֹד! 🎉\nאֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק וְלִצְבֹּר עוֹד."))
                    : Gendered.g(tr("עֲנֵה נָכוֹן עַל \(target) שְׁאֵלוֹת הַיּוֹם וְזָכֵה בִּ-\(prize) 💎!\nכָּל יוֹם רָצוּף שֶׁמְּשַׂחֲקִים — הַפְּרָס גָּדֵל. 🔥"), tr("עֲנִי נָכוֹן עַל \(target) שְׁאֵלוֹת הַיּוֹם וּזְכִי בִּ-\(prize) 💎!\nכָּל יוֹם רָצוּף שֶׁמְּשַׂחֲקִים — הַפְּרָס גָּדֵל. 🔥")),
                progressText: "\(done)/\(target)",
                ctaTitle: ready ? tr("אִסְפוּ אֶת הַפְּרָס 🎁") : tr("קָדִימָה, נְעַנֶּה! 🚀"),
                onCTA: {
                    if ready { claimChallenge(); infoSheet = nil }
                    else { enterSmartFeedFromInfo() }
                },
                onClose: { infoSheet = nil }
            )
        case .event:
            eventInfoScreen
        }
    }

    private func eventCopy(_ event: GameEvent) -> (title: String, message: String) {
        switch event {
        case .doubleDiamonds:
            return (tr("סוֹף שָׁבוּעַ כָּפוּל!"),
                    tr("כָּל הַיַּהֲלוֹמִים שֶׁתִּצְבְּרוּ הַיּוֹם — כְּפוּלִים! 💎×2\nזֶה הַזְּמַן הֲכִי טוֹב לֶאֱסֹף הַרְבֵּה."))
        case .featuredTopic(let t):
            return (tr("נוֹשֵׂא הַיּוֹם: \(t.displayName)"),
                    tr("הַיּוֹם כָּל תְּשׁוּבָה נְכוֹנָה בְּ\(t.displayName) שָׁוָה יַהֲלוֹמִים כְּפוּלִים! 💎×2"))
        }
    }

    @ViewBuilder
    private var eventInfoScreen: some View {
        if let event = GameEvent.current() {
            let copy = eventCopy(event)
            ChallengeInfoView(
                emoji: event.emoji,
                title: copy.title,
                message: copy.message,
                ctaTitle: tr("קָדִימָה! 🚀"),
                onCTA: { enterSmartFeedFromInfo() },
                onClose: { infoSheet = nil }
            )
        } else {
            // Event lapsed while open — nothing to show; just dismiss.
            Color.clear.onAppear { infoSheet = nil }
        }
    }

    /// Avatar in a glass ring + name (tap → the child's profile) with a small
    /// line under it: the Tofy level (tap → level info) and the day streak.
    private func identityBlock(avatar: CGFloat) -> some View {
        HStack(spacing: 10) {
            Button {
                Haptic.light(); showingChildSettings = true
            } label: {
                // The ring says the level tier: bronze from 5, silver from 10, gold
                // from 20 (Rani: the level must mean something the child can see).
                let tier = RewardEngine.levelTier(progress.companionLevel)
                let ring: Color = [Color.white.opacity(0.5), Color(hex: "CD7F32"), Color(hex: "D9D9E3"), Color(hex: "FFD23F")][tier]
                CharacterView(character: profiles.active?.character
                              ?? Character3DCatalog.find(Character3DCatalog.defaultID),
                              portrait: true)
                    .frame(width: avatar, height: avatar)
                    .background(Circle().fill(Color.white.opacity(0.22)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ring, lineWidth: tier == 0 ? 1 : 2.5))
                    .shadow(color: tier == 0 ? .clear : ring.opacity(0.7), radius: tier == 0 ? 0 : 6)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    Haptic.light(); showingChildSettings = true
                } label: {
                    Text((profiles.active?.name ?? tr("טוֹפִי")).split(separator: " ").first.map(String.init) ?? tr("טוֹפִי"))
                        .font(.system(size: isCompact ? 17 : 20, weight: .black, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .frame(height: isCompact ? 22 : 26)
                }
                .buttonStyle(.plain)

                Button {
                    Haptic.light(); showLevelInfo = true
                } label: {
                    // Mockup: the grade, then the day streak — the level lives in
                    // the sheet this line opens.
                    Text(Profile.gradeDisplayName(profiles.active?.effectiveGrade ?? 1)
                         + (progress.dayStreak > 0 ? tr(" · 🔥 \(progress.dayStreak) יָמִים") : ""))
                        .font(.system(size: isCompact ? 12 : 13, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(height: 16)
                }
                .buttonStyle(.plain)
            }
            .environment(\.layoutDirection, .app)
        }
        .eraseToAnyView()
    }

    /// Round glass buttons, no captions (the approved mockup) — emoji say it all.
    /// Three, not four (Rani, 2026-09-06): 🛍️ shop · 🏆 friends (leaderboard +
    /// the live tournament live inside it; a waiting invite lights the badge) ·
    /// ⚙️ the parent's corner. Order (LTR): 🛍️ · 🏆 · ⚙️.
    private func navButtonsRow(size: CGFloat) -> some View {
        HStack(spacing: isCompact ? 6 : 9) {
            // Rani (2026-09-06): the shop and the friends screen are NOT behind
            // Tofy+ — a child can always spend diamonds and see their friends.
            navButton("🛍️", badge: false, size: size) {
                Haptic.light(); showingShop = true
            }
            .coachMark("k.shop")
            navButton("🏆", badge: !liveGame.invites.isEmpty, size: size) {
                Haptic.light(); showingLeaderboard = true
            }
            .coachMark("k.friends")
            navButton("⚙️", badge: false, size: size, longPress: { showingDemo = true }) {
                showingParentGate = true
            }
            .coachMark("k.settings")
        }
        .eraseToAnyView()
    }

    private func navButton(_ emoji: String, badge: Bool, size: CGFloat,
                           longPress: (() -> Void)? = nil,
                           action: @escaping () -> Void) -> some View {
        let circle = Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(emoji)
                    .font(.system(size: size * 0.44))
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.white.opacity(0.24)))
                    .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                if badge {
                    Circle().fill(AppColor.flameOrange).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2)).offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)

        return Group {
            if let longPress {
                circle.onLongPressGesture(minimumDuration: 1.5, perform: longPress)
            } else {
                circle
            }
        }
        .eraseToAnyView()
    }

    /// The 4-stat strip (RTL): 💎 diamonds · ⭐ stars · ⏱ minutes today · ✅
    /// correct today. Each is tappable for its explainer sheet.
    private var statsPanel: some View {
        let cap = progress.dailyCap
        let minutes = cap.enabled ? "\(progress.minutesEarnedToday)" : "\(progress.pendingMinutes)"
        let minutesMax: String? = cap.enabled ? "/\(cap.max)" : nil
        // The approved header: ⏱ minutes today · ✅ correct today · ⭐ level
        // (stars and diamonds moved up beside the name).
        return HStack(spacing: 0) {
            statColumn(value: minutes, suffix: minutesMax, label: Gendered.g(tr("⏱ הִרְוַחְתָּ הַיּוֹם"), tr("⏱ הִרְוַחַתְּ הַיּוֹם"))) { infoStat = .today }
            statDivider
            statColumn(value: "\(progress.correctToday)", label: tr("✅ נְכוֹנוֹת הַיּוֹם")) { infoStat = .correct }
            statDivider
            statColumn(value: "\(progress.companionLevel)", label: tr("⭐ רָמָה")) { showLevelInfo = true }
        }
        .environment(\.layoutDirection, .app)
        .padding(.vertical, 13)
        .padding(.horizontal, 4)
        .glassInset(radius: 18)
        // One clean bottom sheet for the stat explanations (a popover floated
        // awkwardly over the header on iPhone).
        .sheet(item: $infoStat) { stat in
            statInfoCard(stat)
                .environment(\.layoutDirection, .app)
                .presentationDetents([.height(stat == .minutes || stat == .today ? 460 : 400)])
                .presentationDragIndicator(.visible)
        }
        .eraseToAnyView()
    }

    private var statDivider: some View {
        Rectangle().fill(.white.opacity(0.16)).frame(width: 1, height: 36)
    }

    private func statColumn(value: String, suffix: String? = nil, label: String,
                            action: (() -> Void)?) -> some View {
        let content = VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.system(size: isCompact ? 20 : 24, weight: .black, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: isCompact ? 14 : 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassInk.tertiary)
                }
            }
            .monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.6)
            .environment(\.layoutDirection, .leftToRight)   // "60/90" is a number: reads LTR
            Text(label)
                .font(.system(size: isCompact ? 12 : 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        return Group {
            if let action {
                Button { Haptic.light(); action() } label: { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
        .eraseToAnyView()
    }

    // MARK: - Stat info popovers

    @ViewBuilder
    private func statInfoCard(_ stat: StatInfo) -> some View {
        let info = statInfoContent(stat)
        // Card forces RTL, so `.leading` = the visual RIGHT. Everything is
        // right-aligned (natural Hebrew); the emoji sits on the left.
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(info.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(info.emoji)
                    .font(.system(size: 46))
            }

            Text(info.body)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let tip = info.tip {
                HStack(alignment: .top, spacing: 8) {
                    Text(tip)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppColor.starGold)
                        .font(.system(size: 16))
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 8)

            // Quick jump straight from the explanation: diamonds → shop,
            // stars → the friends leaderboard (דֵּירוּג).
            if stat == .diamonds {
                infoCTA(title: tr("לַחֲנוּת"), icon: "storefront.fill",
                        gradient: AnyShapeStyle(AppGradient.gold), glow: AppColor.starGold) {
                    showingShop = true
                }
            } else if stat == .stars {
                infoCTA(title: tr("לַדֵּרוּג"), icon: "trophy.fill",
                        gradient: AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "0E9E72")],
                            startPoint: .leading, endPoint: .trailing)),
                        glow: Color(hex: "10B981")) {
                    showingLeaderboard = true
                }
            }
        }
        .environment(\.layoutDirection, .app)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A full-width CTA at the bottom of a stat sheet (closes it, then navigates).
    private func infoCTA(title: String, icon: String, gradient: AnyShapeStyle,
                         glow: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            infoStat = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: action)
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .glow(glow, radius: 8)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private struct InfoContent {
        let emoji: String
        let title: String
        let subtitle: String
        let body: String
        let tip: String?
    }

    private func statInfoContent(_ stat: StatInfo) -> InfoContent {
        switch stat {
        case .minutes:
            let cap = progress.dailyCap
            var lines: [String] = []
            if progress.canRedeemNow {
                // Enough to open now.
                lines.append(tr("אֶפְשָׁר לִפְתּוֹחַ עַכְשָׁיו \(progress.redeemableMinutesNow) דַּקּוֹת מִשְׂחָק! 🎮"))
                if progress.pendingMinutes > progress.redeemableMinutesNow {
                    lines.append(tr("בָּאַרְנָק יֵשׁ \(progress.pendingMinutes) — הַשְּׁאָר נִשְׁמָר לְיָמִים הַבָּאִים."))
                }
            } else if progress.dailyScreenTimeMaxedOut {
                // Today's screen-time cap is used up — the wallet waits for tomorrow.
                // The cap that's full is PLAYED time, so say that number — "הרווחת
                // היום 49 מתוך 90" under "הגעת למקסימום" read as a contradiction
                // (Yoav, 2026-10-03).
                lines.append(Gendered.g(tr("הִגַּעְתָּ לַמַּקְסִימוּם 🌙 — שִׂחַקְתָּ הַיּוֹם \(progress.minutesPlayedToday) מִתּוֹךְ \(cap.max) דַּקּוֹת. \(progress.pendingMinutes) דַּקּוֹת שְׁמוּרוֹת לְךָ לְמָחָר!"), tr("הִגַּעַתְּ לַמַּקְסִימוּם 🌙 — שִׂחַקְתְּ הַיּוֹם \(progress.minutesPlayedToday) מִתּוֹךְ \(cap.max) דַּקּוֹת. \(progress.pendingMinutes) דַּקּוֹת שְׁמוּרוֹת לָךְ לְמָחָר!")))
            } else if progress.pendingMinutes > 0 {
                // Has some, but below the 15-min minimum we can open.
                lines.append(Gendered.g(tr("יֵשׁ לְךָ \(progress.pendingMinutes) דַּקּוֹת. פּוֹתְחִים זְמַן מִשְׂחָק מִ-\(progress.minimumUnlockMinutes) דַּקּוֹת — עֲנוּ עַל עוֹד שְׁאֵלוֹת! 😊"), tr("יֵשׁ לָךְ \(progress.pendingMinutes) דַּקּוֹת. פּוֹתְחִים זְמַן מִשְׂחָק מִ-\(progress.minimumUnlockMinutes) דַּקּוֹת — עֲנוּ עַל עוֹד שְׁאֵלוֹת! 😊")))
            } else if cap.enabled, progress.minutesEarnedToday >= cap.max {
                // Earned the WHOLE day's allowance and spent it — a win, not a
                // lack ("עדיין אין דקות" here read as failure and invited more
                // answering "to earn", when today's earning is over). Point at
                // what IS possible now: tomorrow's bank + the gift pocket.
                lines.append(Gendered.g(tr("וָואוּ — נִצַּלְתָּ אֶת כָּל \(cap.max) הַדַּקּוֹת שֶׁל הַיּוֹם! 🏆"), tr("וָואוּ — נִצַּלְתְּ אֶת כָּל \(cap.max) הַדַּקּוֹת שֶׁל הַיּוֹם! 🏆")))
                lines.append(Gendered.g(tr("כָּל מַה שֶּׁתַּרְוִיחַ עַכְשָׁיו נִשְׁמָר לְמָחָר."), tr("כָּל מַה שֶּׁתַּרְוִיחִי עַכְשָׁיו נִשְׁמָר לְמָחָר.")))
                if progress.parentGiftMinutes > 0 {
                    lines.append(Gendered.g(tr("וְיֵשׁ לְךָ \(progress.parentGiftMinutes) דַּקּוֹת מַתָּנָה 💝 שֶׁאֶפְשָׁר לִפְתּוֹחַ גַּם עַכְשָׁיו!"), tr("וְיֵשׁ לָךְ \(progress.parentGiftMinutes) דַּקּוֹת מַתָּנָה 💝 שֶׁאֶפְשָׁר לִפְתּוֹחַ גַּם עַכְשָׁיו!")))
                }
            } else {
                lines.append(tr("עֲדַיִן אֵין דַּקּוֹת. עֲנוּ עַל שְׁאֵלוֹת כְּדֵי לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק! 🎮"))
            }
            if cap.enabled, !progress.dailyScreenTimeMaxedOut {
                lines.append(Gendered.g(tr("הַיּוֹם הִרְוַחְתָּ \(progress.minutesEarnedToday) מִתּוֹךְ \(cap.max) דַּקּוֹת."), tr("הַיּוֹם הִרְוַחַתְּ \(progress.minutesEarnedToday) מִתּוֹךְ \(cap.max) דַּקּוֹת.")))
            }
            if progress.carryOverMinutes > 0 {
                lines.append(tr("🎁 \(progress.carryOverMinutes) דַּקּוֹת נִשְׁמְרוּ לְמָחָר."))
            }
            return InfoContent(
                emoji: "🎮",
                title: tr("דַּקּוֹת מִשְׂחָק"),
                subtitle: Gendered.g(tr("זְמַן הַמִּשְׂחָק שֶׁלְּךָ"), tr("זְמַן הַמִּשְׂחָק שֶׁלָּךְ")),
                body: lines.joined(separator: "\n"),
                tip: tr("עוֹנִים נָכוֹן — מַרְוִיחִים עוֹד דַּקּוֹת!")
            )
        case .stars:
            return InfoContent(
                emoji: "⭐",
                title: tr("\(progress.stars.grouped) כּוֹכָבִים"),
                subtitle: tr("הַדֵּרוּג שֶׁלָּכֶם"),
                body: tr("אוֹסְפִים כּוֹכָב עַל כָּל תְּשׁוּבָה נְכוֹנָה. הַכּוֹכָבִים אַף פַּעַם לֹא יוֹרְדִים — הֵם הַנִּקּוּד שֶׁלָּכֶם בְּטַבְלַת הַחֲבֵרִים!"),
                tip: tr("כָּל מַה שֶּׁאַתֶּם לוֹמְדִים מְטַפֵּס בַּדֵּרוּג 🏆")
            )
        case .gift:
            let gift = progress.parentGiftMinutes
            return InfoContent(
                emoji: "💝",
                title: tr("\(gift) דַּקּוֹת מַתָּנָה"),
                subtitle: tr("מֵהַהוֹרִים 💝"),
                body: gift > 0
                    ? tr("אֶת הַדַּקּוֹת הָאֵלֶּה הַהוֹרִים נָתְנוּ לָכֶם בְּמַתָּנָה — לֹא צָרִיךְ לַעֲנוֹת עַל שְׁאֵלוֹת כְּדֵי לִפְתּוֹחַ אוֹתָן.")
                        + "\n" + tr("פּוֹתְחִים אוֹתָן בַּכַּפְתּוֹר הַוָּרוֹד לְמַטָּה 🎁")
                    : tr("כָּרֶגַע אֵין דַּקּוֹת מַתָּנָה. כְּשֶׁהַהוֹרִים יִשְׁלְחוּ מַתָּנָה — הִיא תּוֹפִיעַ כָּאן 💝"),
                tip: tr("דַּקּוֹת מַתָּנָה נִשְׁמָרוֹת בִּנְפָרָד מֵהַדַּקּוֹת שֶׁהִרְוַחְתֶּם 😊")
            )
        case .today:
            let cap = progress.dailyCap
            var lines: [String] = []
            if cap.enabled {
                lines.append(Gendered.g(tr("הַיּוֹם הִרְוַחְתָּ \(progress.minutesEarnedToday) מִתּוֹךְ \(cap.max) דַּקּוֹת."), tr("הַיּוֹם הִרְוַחַתְּ \(progress.minutesEarnedToday) מִתּוֹךְ \(cap.max) דַּקּוֹת.")))
                lines.append(tr("כְּשֶׁמַּגִּיעִים לַמַּקְסִימוּם הַיּוֹמִי (\(cap.max) דַּקּוֹת), מַה שֶּׁמַּרְוִיחִים אַחַר כָּךְ נִשְׁמָר לְמָחָר 🎁"))
            } else {
                lines.append(tr("הַיּוֹם הִרְוַחְתֶּם \(progress.minutesEarnedToday) דַּקּוֹת."))
            }
            lines.append(tr("הַמִּסְפָּר הַזֶּה לֹא יוֹרֵד כְּשֶׁמְּשַׂחֲקִים — הוּא סוֹפֵר כַּמָּה הִרְוַחְתֶּם הַיּוֹם. כַּמָּה נִשְׁאַר לְשַׂחֵק? אֶת זֶה רוֹאִים לְיַד ⏱ דַּקּ׳ לְשַׂחֵק."))
            return InfoContent(
                emoji: "⏱",
                title: tr("\(progress.minutesEarnedToday) דַּקּוֹת הַיּוֹם"),
                subtitle: tr("כַּמָּה הִרְוַחְתֶּם הַיּוֹם"),
                body: lines.joined(separator: "\n"),
                tip: tr("עוֹנִים נָכוֹן — מַרְוִיחִים עוֹד דַּקּוֹת!")
            )
        case .correct:
            let left = max(0, ProgressStore.dailyChallengeTarget - progress.correctToday)
            return InfoContent(
                emoji: "✅",
                title: tr("\(progress.correctToday) תְּשׁוּבוֹת נְכוֹנוֹת"),
                subtitle: tr("הַיּוֹם"),
                body: tr("כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחָה \(progress.secondsPerCorrect) שְׁנִיּוֹת מִשְׂחָק, כּוֹכָבִים ⭐ וְיַהֲלוֹמִים 💎.")
                    + "\n" + (left > 0 ? tr("עוֹד \(left) תְּשׁוּבוֹת נְכוֹנוֹת וְהָאֶתְגָּר הַיּוֹמִי נִפְתָּח! 🔥")
                                         : tr("הָאֶתְגָּר הַיּוֹמִי הֻשְׁלַם! 🔥")),
                tip: tr("מָחָר מַתְחִילִים מֵאֶפֶס — וְהַכּוֹכָבִים נִשְׁאָרִים לְתָמִיד ⭐")
            )
        case .diamonds:
            return InfoContent(
                emoji: "💎",
                title: tr("\(progress.diamonds.grouped) יַהֲלוֹמִים"),
                subtitle: tr("הָאַרְנָק שֶׁלָּכֶם"),
                body: tr("מַרְוִיחִים יַהֲלוֹמִים עַל תְּשׁוּבוֹת נְכוֹנוֹת, מִמַּתָּנוֹת וּמִגַּלְגַּל הַמַּזָּל — וְקוֹנִים בָּהֶם בַּחֲנוּת."),
                tip: tr("קְנִיָּה לֹא פּוֹגַעַת בַּדֵּרוּג שֶׁלָּכֶם 😊")
            )
        }
    }

    // MARK: - 🏆 Boss waiting

    /// Once a day, the fox points at a boss that is waiting in the last room.
    private func announceWaitingBoss() {
        let key = "boss.waiting.said.\(profiles.activeID?.uuidString ?? "none")"
        guard !DayGate.usedToday(UserDefaults.standard.object(forKey: key) as? Date),
              let profile = profiles.active else { return }
        let waiting = Worlds.all.first { w in
            !w.isBonusWorld && profile.playableTopics.contains(w.topic)
                && progress.hasVisited(w.id) && progress.worldTier(in: w.id) < ProgressStore.worldTierCount
                && progress.progress(in: w.id) >= w.rooms - 1
        }
        guard let w = waiting else { return }
        UserDefaults.standard.set(Date(), forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            companion.wow(Gendered.g(tr("הַבּוֹס שֶׁל \(w.name) מְחַכֶּה לְךָ! 🐉"), tr("הַבּוֹס שֶׁל \(w.name) מְחַכֶּה לָךְ! 🐉")))
        }
    }

    // MARK: - Hero title

    private var heroTitle: some View {
        VStack(spacing: 4) {
            // The wordmark now heads the screen (brandRow); this line keeps its
            // place over the worlds — the one the mockup kept (Rani).
            HStack(spacing: 8) {
                Text(tr("בּוֹחֲרִים עוֹלָם וְיוֹצְאִים לְהַרְפַּתְקָה ✨"))
                    .font(.system(size: isCompact ? 13 : 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                // 🏆 Crowns earned across all worlds (the mockup's top pill).
                if progress.totalCrowns > 0 {
                    Text(tr("👑 כְּתָרִים: \(progress.totalCrowns)"))
                        .font(.system(size: isCompact ? 12 : 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.2)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                }
            }
            .opacity(heroAppeared ? 1 : 0)
            // (The "רָמַת טוֹפִי" XP pill was removed — the level now lives in the
            // header card's level badge; tapping the avatar opens the level info.)
        }
        .sheet(isPresented: $showLevelInfo) {
            levelInfoSheet
                .environment(\.layoutDirection, .app)
                .presentationDetents([.medium])
        }
        .eraseToAnyView()
    }

    private var levelInfoSheet: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 14, size: 12)
            VStack(spacing: AppSpacing.lg) {
                Text("⭐").font(.system(size: 54))
                Text(tr("רָמַת טוֹפִי"))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(tr("כָּל תְּשׁוּבָה נְכוֹנָה נוֹתֶנֶת נְקוּדּוֹת. כְּשֶׁהַפַּס מִתְמַלֵּא עוֹלִים רָמָה — וּמְקַבְּלִים 💎 בּוֹנוּס לַחֲנוּת (10 עַל כָּל רָמָה). מֵרָמָה 5 הָאַוָּטָאר מְקַבֵּל מִסְגֶּרֶת בְּרוֹנְזָה, מֵ־10 כֶּסֶף, וּמֵ־20 זָהָב!"))
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.lg)

                VStack(spacing: 6) {
                    Text(tr("רָמָה נוֹכְחִית: \(progress.companionLevel)"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                    Text(tr("עוֹד \(progress.questionsUntilNextLevel) תְּשׁוּבוֹת נְכוֹנוֹת לָרָמָה הַבָּאָה"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.vertical, AppSpacing.md)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                .padding(.horizontal, AppSpacing.lg)

                Button { showLevelInfo = false } label: {
                    Text(tr("הֵבַנְתִּי!"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .glow(AppColor.starGold, radius: 10)
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(.vertical, AppSpacing.xl)
        }
    }

    private var xpProgress: Double {
        let range = max(1, progress.xpForNextLevel - progress.xpForCurrentLevel)
        let done = max(0, progress.xp - progress.xpForCurrentLevel)
        return min(1, Double(done) / Double(range))
    }

    // MARK: - Bottom CTAs

    @ViewBuilder
    private var bottomCTAs: some View {
        VStack(spacing: AppSpacing.sm) {
            // The daily gift now lives as a lively beacon in the top bar (see
            // DailyGiftBeacon) instead of a full-width bottom button. Every world
            // & Smart Adventure earns minutes, so the only bottom CTA left is the
            // "redeem my minutes" button below.
            // 💝 ONE button for everything the PARENTS gave: the gift pocket plus
            // any frozen leftover of an earlier parent window (the kid tapped "עצור
            // ושמור"). Both are parent time — never blurred with earned minutes.
            // Opens both together as one fixed manual window (outside the cap).
            if (giftOpenableSeconds > 0 || progress.hasPausedManualTime) && !progress.isUnlocked
                && peerWindow == nil {
                Button {
                    requestUnlock { redeemGift() }
                } label: {
                    HStack(spacing: 10) {
                        if isOpening {
                            ProgressView().tint(.white).scaleEffect(0.9)
                            Text(Gendered.g(tr("פּוֹתְחִים לְךָ… ✨"), tr("פּוֹתְחִים לָךְ… ✨")))
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                        } else {
                            Text("💝").font(.system(size: isShort ? 19 : 22))
                            Text(giftButtonTitle)
                                .font(.system(size: isShort ? 18 : 20, weight: .heavy, design: .rounded))
                                .minimumScaleFactor(0.7).lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, isShort ? 11 : 16)
                    .frame(maxWidth: .infinity)
                    .ctaGlass(Color(hex: "FF5FA8"), Color(hex: "FFA53A"), colour: 0.82)
                }
                .buttonStyle(.juicy)
                .disabled(isOpening)
                .frame(maxWidth: 480)
                .padding(.bottom, isShort ? 0 : 6)
            }

            // Another device of THIS child has the window open — say so instead of
            // showing a "redeem" button that would be refused on tap, and offer
            // the TRANSFER: lock it THERE (stop-and-save, nothing lost), wait for
            // the honest confirmation, then the regular open buttons return here.
            if let other = peerWindow {
                let where_ = other.kindLabel == "ipad" ? tr("בָּאַיְפֵּד") : (other.kindLabel == "iphone" ? tr("בָּאַיְפוֹן") : tr("בְּמַכְשִׁיר אַחֵר"))
                VStack(spacing: 10) {
                    // Rani: the child must watch the OTHER device's time tick down
                    // here, live. Nothing extra is sent for this — the lease already
                    // carries `startedAt` + `grantedSeconds`, so the exact remainder
                    // is derived locally; it just has to be re-rendered each second
                    // instead of freezing until the next document change. Shown to
                    // the second, because that is exactly what moves across on a
                    // transfer.
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let left = max(0, peerWindow?.secondsLeft ?? 0)
                        bottomHint(Gendered.g(tr("🎮 הַזְּמַן שֶׁלְּךָ פָּתוּחַ עַכְשָׁיו \(where_) — נִשְׁאֲרוּ \(left / 60):\(String(format: "%02d", left % 60))"), tr("🎮 הַזְּמַן שֶׁלָּךְ פָּתוּחַ עַכְשָׁיו \(where_) — נִשְׁאֲרוּ \(left / 60):\(String(format: "%02d", left % 60))")))
                    }
                    if transferRequestedAt != nil {
                        bottomHint(tr("🔒 נוֹעֲלִים \(where_)… רֶגַע אֶחָד ⏳"))
                    } else {
                        // NO "open anyway" escape hatch (Rani). An override that
                        // opens a window while another device may still hold one
                        // is the exact hole this whole design closes — and it is
                        // no longer needed: a device that stopped playing hands
                        // the lease back on its own (honorReleaseRequestIfNeeded,
                        // and the wake-up sweep), and a genuinely dead lease
                        // expires. So the honest answer here is "try again".
                        if transferTimedOut {
                            bottomHint(tr("לֹא הִצְלַחְנוּ לִנְעֹל \(where_) עַכְשָׁיו — אוּלַי הוּא כָּבוּי. אֶפְשָׁר לְנַסּוֹת שׁוּב 😊"))
                        }
                        Button {
                            transferWindowHere(rowID: other.rowID, peerSecondsLeft: other.secondsLeft)
                        } label: {
                            HStack(spacing: 10) {
                                if isTransferring {
                                    ProgressView().tint(.white).scaleEffect(0.9)
                                    Text(tr("מַעֲבִירִים לְכָאן… ✨"))
                                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                                } else {
                                    Image(systemName: "lock.arrow.circlepath")
                                        .font(.system(size: 20, weight: .bold))
                                    Text(tr("נַעֲלוּ \(where_) וּפִתְחוּ כָּאן"))
                                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                                        .minimumScaleFactor(0.7).lineLimit(1)
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.xl)
                            .padding(.vertical, 15)
                            .frame(maxWidth: .infinity)
                            .ctaGlass(Color(hex: "5B6CFF"), Color(hex: "9B5DE5"))
                        }
                        .buttonStyle(.juicy)
                        .disabled(isTransferring)
                        .frame(maxWidth: 480)
                    }
                }
            } else if quiet.current != nil, let line = quiet.blockedMessage() {
                // 🏫🌙 School time / bedtime: the minutes wait, and the line says
                // until when — in place of the open button.
                bottomHint(line)
            } else if progress.canRedeemNow {
                Button {
                    requestUnlock { redeemMinutes() }
                } label: {
                    HStack(spacing: 10) {
                        // Claiming the lease is a round-trip to the server. Without
                        // this the button looked dead for 2–3 seconds (Rani).
                        if isOpening {
                            ProgressView().tint(.white).scaleEffect(0.9)
                            Text(Gendered.g(tr("פּוֹתְחִים לְךָ… ✨"), tr("פּוֹתְחִים לָךְ… ✨")))
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                        } else {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: isShort ? 21 : 24))
                            Text(tr("פִּתְחוּ לִי \(Self.timeLabel(progress.redeemableSecondsNow)) דַּקּוֹת לְשַׂחֵק"))
                                .font(.system(size: isShort ? 18 : 20, weight: .heavy, design: .rounded))
                                .minimumScaleFactor(0.7).lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, isShort ? 11 : 16)
                    .frame(maxWidth: .infinity)
                    .ctaGlass(Color(hex: "5E60CE"), Color(hex: "3E8BF0"))
                }
                .buttonStyle(.juicy)
                .disabled(isOpening)
                .frame(maxWidth: 480)
            } else if progress.dailyScreenTimeMaxedOut {
                // Wallet has minutes, but today's screen-time cap is used up — they
                // wait for tomorrow. Say so clearly (don't tell them to earn more).
                bottomHint(Gendered.g(tr("שִׂחַקְתָּ הַיּוֹם \(progress.minutesPlayedToday) מִתּוֹךְ \(progress.dailyCap.max) דַּקּוֹת 🌙 — \(progress.pendingMinutes) שְׁמוּרוֹת לְמָחָר"), tr("שִׂחַקְתְּ הַיּוֹם \(progress.minutesPlayedToday) מִתּוֹךְ \(progress.dailyCap.max) דַּקּוֹת 🌙 — \(progress.pendingMinutes) שְׁמוּרוֹת לְמָחָר")))
            } else if progress.redeemableMinutesNow > 0 {
                // Has some minutes but below the 15-min minimum we can enforce.
                // Say all three numbers — what they have, where opening starts, how
                // many more — or "12 דק' לשחק" above and "עוד 3" here read as a
                // contradiction (Rani, on the iPad).
                let have = progress.redeemableMinutesNow, from = progress.minimumUnlockMinutes
                bottomHint(tr("\(have) דַּקּ׳ לְשַׂחֵק · פּוֹתְחִים מִ־\(from) — עוֹד \(max(0, from - have))! 🎮"))
            } else {
                // Empty wallet (nothing earned / all opened). Nudge to earn instead
                // of leaving the spot blank.
                bottomHint(tr("עֲנוּ עַל שְׁאֵלוֹת כְּדֵי לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק 🎮"))
            }

            // "Protect my time" — the child's own code on the unlock buttons, so a
            // sibling/friend holding the device can't spend the earned minutes.
            // Discreet: a small text button, only where it's relevant (there's
            // something to protect, or a code already exists to manage).
            if let p = profiles.active,
               p.hasPlayPIN || progress.pendingMinutes > 0 || progress.hasPausedManualTime {
                Button {
                    Haptic.light()
                    playPINSheet = p.hasPlayPIN ? .manage : .setNew
                } label: {
                    // Rani (2026-09-07): "הגנו על הזמן שלכם בקוד" read like a parent
                    // setting; this is the child's own secret code for their minutes.
                    Label(p.hasPlayPIN ? tr("הַדַּקּוֹת שֶׁלִּי מוּגָנוֹת בְּקוֹד") : tr("קוֹד סוֹדִי לַדַּקּוֹת שֶׁלִּי"),
                          systemImage: p.hasPlayPIN ? "lock.fill" : "lock.open")
                        .font(.system(size: isShort ? 12.5 : 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14).padding(.vertical, isShort ? 5 : 8)
                        .background(Capsule().fill(.white.opacity(0.16)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, isShort ? 0 : 2)
            }

            // 🛡 Screen Time was never granted on this device, so nothing here can
            // actually be locked when the time runs out. The child is not asked to
            // fix it — they're told to fetch a grown-up, which is the only thing
            // they can do (the grant needs an adult's Apple ID either way).
            if settings.deviceRole == .child, !shields.isAuthorized {
                Label(tr("בִּקְשׁוּ מֵאַבָּא אוֹ מֵאִמָּא לְסַיֵּם אֶת הַהַגְדָּרָה שֶׁל טוֹפִי"),
                      systemImage: "exclamationmark.shield.fill")
                    .font(.system(size: isShort ? 12 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "2B1C04"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14).padding(.vertical, isShort ? 5 : 8)
                    .background(Capsule().fill(AppColor.starGold.opacity(0.92)))
                    .padding(.top, isShort ? 2 : 4)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// A pill-styled hint shown in the bottom CTA spot when there's no openable
    /// grant — so the area is never silently blank.
    private func bottomHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: isShort ? 13 : 14, weight: .heavy, design: .rounded))
            .foregroundStyle(GlassInk.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.lg).padding(.vertical, isShort ? 8 : 12)
            .frame(maxWidth: .infinity)
            // Floats over the scrolling grid, so it needs a darker body than a
            // pane on the bare gradient — otherwise tile titles read through it.
            .background(Color(hex: "2A1E5C").opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .glassPane(radius: 16, strength: 0.16)
            .frame(maxWidth: 480)
    }

    // MARK: - Play-protection code (the child's own 🔒)

    /// Which KidPIN screen is up. All flows re-ask for the code — the whole
    /// point is a sibling grabbing the device mid-session.
    enum PlayPINSheet: String, Identifiable {
        case verifyUnlock      // code before spending minutes
        case setNew            // first-time setup (enter → confirm)
        case manage            // has a code: choose change / remove
        case verifyThenSet     // change: prove you know it, then pick a new one
        case verifyThenClear   // remove: prove you know it, then clear
        case forgot            // "I forgot" — pings the parents + parent-code reset
        var id: String { rawValue }
    }

    /// Run `action` immediately when the child has no protection code, otherwise
    /// hold it and ask for the code first.
    private func requestUnlock(_ action: @escaping () -> Void) {
        guard let p = profiles.active else { return }
        guard !isOpening else { return }          // a claim is already in flight
        // 🏫🌙 Before the code sheet — asking for the code only to say "not now"
        // would be a small cruelty.
        if let line = QuietHoursManager.shared.blockedMessage() {
            Haptic.light()
            companion.console(line)
            return
        }
        Haptic.light()                            // the tap answers immediately
        // Family-wide double-spend guard: if THIS child's OTHER device already has
        // a play window open, don't open a second one here (the wallet drain
        // may not have synced yet — that's how 30 minutes became 60).
        if let other = HouseholdManager.shared.otherDeviceOpenWindow(forChildID: p.id) {
            let mins = max(1, (other.secondsLeft + 59) / 60)
            let where_ = other.device.kind == "ipad" ? tr("בָּאַיְפֵּד") : (other.device.kind == "iphone" ? tr("בָּאַיְפוֹן") : tr("בְּמַכְשִׁיר אַחֵר"))
            Haptic.warning()
            companion.console(Gendered.g(tr("הַזְּמַן שֶׁלְּךָ כְּבָר פָּתוּחַ \(where_) — עוֹד \(mins) דַּקּוֹת 🎮"), tr("הַזְּמַן שֶׁלָּךְ כְּבָר פָּתוּחַ \(where_) — עוֹד \(mins) דַּקּוֹת 🎮")))
            return
        }
        guard p.hasPlayPIN else { action(); return }
        pendingUnlockAction = action
        playPINSheet = .verifyUnlock
    }

    /// Speak (once) the gentle line left behind by an open that couldn't happen.
    private func speakOpenWindowMessageIfNeeded() {
        guard let line = progress.openWindowMessage else { return }
        progress.openWindowMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            companion.console(line)
        }
    }

    private func savePlayPIN(_ pin: String) {
        guard var p = profiles.active else { return }
        p.playPIN = pin
        profiles.update(p)
        companion.cheer(Gendered.g(tr("הַזְּמַן שֶׁלְּךָ מוּגָן! 🔒"), tr("הַזְּמַן שֶׁלָּךְ מוּגָן! 🔒")))
    }

    private func clearPlayPIN() {
        guard var p = profiles.active else { return }
        // "" (not nil) — the deliberate-clear sentinel that survives sync merges.
        p.playPIN = ""
        profiles.update(p)
        companion.cheer(tr("הַקּוֹד הוּסַר 🔓"))
    }

    /// The KidPIN full-screen flows, attached to the map's root in `body`.
    @ViewBuilder
    fileprivate func playPINCover(_ sheet: PlayPINSheet) -> some View {
        if let p = profiles.active {
            switch sheet {
            case .verifyUnlock:
                KidPINView(profile: p, mode: .verify(title: tr("פּוֹתְחִים זְמַן מִשְׂחָק"))) { _ in
                    playPINSheet = nil
                    let action = pendingUnlockAction
                    pendingUnlockAction = nil
                    // Present-dismiss race safety: run after the cover closes.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { action?() }
                } onCancel: {
                    pendingUnlockAction = nil
                    playPINSheet = nil
                } onForgot: {
                    pendingUnlockAction = nil
                    playPINSheet = .forgot
                }
            case .setNew:
                KidPINView(profile: p, mode: .setNew) { pin in
                    savePlayPIN(pin)
                    playPINSheet = nil
                } onCancel: { playPINSheet = nil }
            case .manage:
                PlayPINManageView(
                    onChange: { playPINSheet = .verifyThenSet },
                    onRemove: { playPINSheet = .verifyThenClear },
                    onClose: { playPINSheet = nil }
                )
            case .verifyThenSet:
                KidPINView(profile: p, mode: .verify(title: tr("קֹדֶם הַקּוֹד הַנּוֹכְחִי"))) { _ in
                    playPINSheet = .setNew
                } onCancel: { playPINSheet = nil }
                  onForgot: { playPINSheet = .forgot }
            case .verifyThenClear:
                KidPINView(profile: p, mode: .verify(title: tr("קֹדֶם הַקּוֹד הַנּוֹכְחִי"))) { _ in
                    clearPlayPIN()
                    playPINSheet = nil
                } onCancel: { playPINSheet = nil }
                  onForgot: { playPINSheet = .forgot }
            case .forgot:
                PlayPINForgotView(childName: p.name) {
                    // A parent authenticated with the PARENT code right here —
                    // clear the kid's code on the spot.
                    clearPlayPIN()
                    playPINSheet = nil
                    companion.cheer(tr("הַקּוֹד אֻפַּס! אֶפְשָׁר לִבְחוֹר חָדָשׁ 🔓"))
                } onClose: { playPINSheet = nil }
            }
        }
    }

    // MARK: - Actions

    // MARK: - 🔒→🔓 Window transfer between the child's own devices

    /// Ask the OTHER device (holding the open window) to lock: it stops-and-
    /// saves (earned → wallet, gift → 💝 pocket — nothing lost), acks, and
    /// uploads the refreshed balance. We do NOT open here yet — completion is
    /// detected in `completeWindowTransferIfReady` only when the other row's
    /// window is truly gone (the honest confirmation Rani asked for).
    /// Is the child's ONE play window held by another of their devices right now?
    /// The lease is authoritative when it's on; the old device-row inference is
    /// consulted only while the lease doc is idle, which is what lets a new build
    /// interoperate with a peer still on the old build.
    private var peerWindow: (kindLabel: String, secondsLeft: Int, rowID: String?)? {
        if PlayWindowLeaseManager.isEnabled {
            let l = leaseMgr.lease
            if l.isHeldElsewhere() {
                let row = (household.devicesByChild[profiles.activeID?.uuidString ?? ""] ?? [])
                    .first { $0.deviceID == l.ownerDeviceID }?.id
                return (l.ownerKind ?? "other", l.remainingSeconds(), row)
            }
            if l.isHeld { return nil }          // it's ours — nobody else
        }
        if let other = household.otherDeviceOpenWindow(forChildID: profiles.activeID ?? UUID()) {
            return (other.device.kind, other.secondsLeft, other.device.id)
        }
        return nil
    }

    /// "נעלו שם ופתחו כאן". With the lease ON this is one honest handshake:
    /// ask the owner to release, ring its doorbell, wait for the ONE atomic fact
    /// that proves it closed, then claim — the refunded minutes are already in the
    /// wallet the claim reads. Falls back to the legacy row-watching flow while
    /// the lease is off or the peer is on an old build.
    private func transferWindowHere(rowID: String?, peerSecondsLeft: Int) {
        if quietBlocksOpening() { return }
        guard PlayWindowLeaseManager.isEnabled, let cid = profiles.activeID else {
            if let rowID, let dev = (household.devicesByChild[cid_ns] ?? []).first(where: { $0.id == rowID }) {
                startWindowTransfer(other: dev)
            }
            return
        }
        Haptic.medium()
        guard !isTransferring else { return }
        transferTimedOut = false
        isTransferring = true
        transferRequestedAt = Date()
        transferFromKind = leaseMgr.lease.ownerKind ?? ""
        Task { @MainActor in
            defer { isTransferring = false }
            let kind = leaseMgr.lease.kind
            // Ask for what the CHILD is looking at. Reading only the lease made
            // this a dead end whenever the card came from the old device-row
            // inference instead: the lease is idle there, so `want` was 0 and the
            // claim came back `.insufficient` — the button visibly did nothing.
            let want = max(progress.redeemableMinutesNow,
                           max(leaseMgr.lease.remainingSeconds(), peerSecondsLeft) / 60)
            let outcome = await leaseMgr.transferHere(childID: cid, ownerDeviceRowID: rowID,
                                                      kind: kind, requestedSeconds: want * 60)
            transferRequestedAt = nil
            switch outcome {
            case .granted(let leaseID, let seconds, let wallet):
                let mins = seconds / 60
                guard seconds > 0 else { return }
                if let wallet { progress.applyClaimedWallet(wallet) }
                shields.unlock(minutes: max(1, (seconds + 59) / 60))
                progress.startUnlock(minutes: mins, manual: kind == .gift, leaseID: leaseID,
                                     leaseKind: kind.rawValue, extraSeconds: seconds % 60)
                LiveEventReporter.report(.screenTimeMoved, extra: ["fromKind": transferFromKind])
                Haptic.success()
                companion.hype(tr("נָעוּל שָׁם! ✅ אֶפְשָׁר לְשַׂחֵק כָּאן 🎉"))
            case .heldElsewhere:
                transferTimedOut = true      // owner never answered → "try again"
                Haptic.warning()
            case .insufficient, .offline:
                transferTimedOut = true
                Haptic.warning()
            }
        }
    }

    private var cid_ns: String { profiles.activeID?.uuidString ?? "" }

    private func startWindowTransfer(other: ChildDevice) {
        Haptic.medium()
        transferTimedOut = false
        transferRequestedAt = Date()
        transferFromKind = other.kind ?? ""
        household.lockOtherDeviceWindow(deviceRowID: other.id)
        // Honest timeout: the other device may be off/offline. Give it 30s;
        // the command stays queued in the cloud and will still apply when it
        // wakes — but we stop holding the kid here waiting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if transferRequestedAt != nil,
               household.otherDeviceOpenWindow(forChildID: profiles.activeID ?? UUID()) != nil {
                transferRequestedAt = nil
                transferTimedOut = true
                Haptic.warning()
            }
        }
    }

    /// Called when the live device rows change: if a transfer is in flight and
    /// the other window is CONFIRMED closed, pull the freshest cloud balance
    /// (the locked device just pushed it) and hand back the regular open flow.
    private func completeWindowTransferIfReady() {
        guard transferRequestedAt != nil, let cid = profiles.activeID,
              household.otherDeviceOpenWindow(forChildID: cid) == nil else { return }
        transferRequestedAt = nil
        // Tell the parents the play window moved between the child's devices —
        // they asked to know (Rani), and the lock there was already applied.
        LiveEventReporter.report(.screenTimeMoved, extra: ["fromKind": transferFromKind])
        Task { @MainActor in
            // MERGE, never a wholesale apply gated on `revision`: that gate used a
            // per-device counter, so the busier device ignored the balance the
            // locked device had just banked (opening its own stale wallet — a
            // double-spend caused by the very feature meant to prevent one), and
            // when it did apply it could lower local accumulators outright.
            if let cloud = await RemoteSyncManager.shared.fetchSnapshot(for: cid) {
                _ = ProgressStore.shared.mergeRemote(cloud)
            }
            Haptic.success()
            companion.hype(tr("נָעוּל שָׁם! ✅ הַדַּקּוֹת חָזְרוּ — אֶפְשָׁר לִפְתּוֹחַ כָּאן 🎉"))
        }
    }

    // MARK: - 🎮 Games warm-up gate (learning first, games after)

    /// Correct answers needed today before the mini-games open. One reward
    /// batch (10) for readers; 5 for גן kids (10 is a lot pre-reading).
    private var gamesGateTarget: Int {
        (profiles.active?.effectiveGrade ?? 1) <= 0 ? 5 : 10
    }
    private var gamesGateRemaining: Int { max(0, gamesGateTarget - progress.correctToday) }

    // MARK: - 🧹 Chores (header card, twin of the daily challenge)

    /// Compact chores entry beside אתגר יומי — identical size and anatomy:
    /// broom ring (available-count badge) → title → live line → today's-progress
    /// track (approved chores out of the day's list).
    private var choresTopCard: some View {
        let all = profiles.activeID.map { choreStore.chores(forChild: $0) } ?? []
        let pending = all.filter { $0.isPendingApproval }.count
        let doneToday = all.filter { $0.approvedToday }.count
        let frac = all.isEmpty ? 0 : CGFloat(doneToday) / CGFloat(all.count)
        let ring = ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "48BFE3"), Color(hex: "5E60CE")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1.5))
                .shadow(color: Color(hex: "48BFE3").opacity(0.55), radius: 9)
            Text("🧹").font(.system(size: 20))
        }
        let status = Text(pending > 0 ? (pending == 1 ? tr("אַחַת מְחַכָּה") : tr("\(pending) מְחַכּוֹת"))
                          : doneToday > 0 ? tr("\(doneToday) הֻשְׁלְמוּ הַיּוֹם! 💪")
                          : tr("עוֹזְרִים — וּבוֹחֲרִים פְּרָס!"))
            .font(.system(size: 11.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.88)).lineLimit(1).minimumScaleFactor(0.6)
        return Button {
            Haptic.light()
            requirePremium { showingChores = true }
        } label: {
            twinCard(ring: ring, title: tr("מַטְלוֹת הַבַּיִת"), status: status, frac: frac)
        }
        .buttonStyle(.juicy)
        .environment(\.layoutDirection, .app)
    }
    /// `correctToday` resets at midnight, so the warm-up is a fresh daily goal.
    private var gamesUnlockedToday: Bool { gamesGateRemaining == 0 }

    /// One celebratory line the first time the games open each day.
    private func celebrateGamesUnlockIfNeeded() {
        guard gamesUnlockedToday else { return }
        let key = "gamesUnlockCelebratedDate"
        if DayGate.usedToday(UserDefaults.standard.object(forKey: key) as? Date) { return }
        UserDefaults.standard.set(Date(), forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            companion.hype(Gendered.g(tr("פָּתַחְתָּ אֶת הַמִּשְׂחָקִים לְהַיּוֹם! 🎮✨"),
                                      tr("פָּתַחַתְּ אֶת הַמִּשְׂחָקִים לְהַיּוֹם! 🎮✨")))
        }
    }

    /// 📖 After an update, the story is the FIRST thing the child sees — Rani:
    /// "סטוריז צריך להיות מעל הכל בפעם הראשונה שעולים אחרי עדכון". Every pop-up
    /// that presents itself on this screen asks this first and waits.
    ///
    /// It is true from before the story's cover is even up (the check runs in
    /// whichever `onAppear` SwiftUI happens to call first), until it closes.
    /// `kidShouldShow` turns false the moment the story is marked shown, so a
    /// story that never opens cannot hold the others back for good.
    private var storyPending: Bool {
        if showWhatsNewStory { return true }
        guard !AppInfo.isDemoRun, let p = profiles.active, p.grade != nil,
              !SchoolYearCelebration.shouldCelebrate(p) else { return false }
        return WhatsNewStories.kidShouldShow(for: p)
    }

    /// Everything that would have popped on arrival but waited for the story,
    /// in the order it would have come: a parent's new pack first, then the
    /// event of the day, the wheel, and the one-time lock setup.
    private func presentDeferredPopups() {
        guard !storyPending else { return }
        maybeRevealPack()
        maybeShowEventSplash()
        maybeAutoPresentWheel()
        maybePromptAppLockSetup()
        CampaignTracker.shared.checkPopup(role: "child", profiles: profiles.active.map { [$0] } ?? [],
                                          premium: subs.isPremium)
        if case .recommended = AppUpdateConfig.shared.state, campaignTracker.popup == nil {
            showUpdateNotice = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { maybeStartKidTour() }
    }

    // MARK: - 🧭 The tour

    static func kidTourKey(_ childID: UUID) -> String { "kidHome.v1.\(childID.uuidString)" }

    /// After the story and every pop-up that waited for it — never on top of
    /// anything. Once per child (two siblings on one iPad each get theirs).
    private func maybeStartKidTour() {
        guard let id = profiles.activeID, !kidTourActive,
              !CoachTours.isDone(Self.kidTourKey(id)) || CoachTours.forcedInDemo,
              !AppInfo.isDemoRun || CoachTours.forcedInDemo,
              !storyPending, !showEventSplash, !showingWheel, packReveal == nil, packOffer == nil,
              !showChildGradePicker, !showSchoolYearParty, !showingAppLockSetup,
              selectedWorld == nil, !showingSmartFeed, campaignTracker.popup == nil,
              !showUpdateNotice, !showDailyChest, !showAppleTips,
              !UserDefaults.standard.bool(forKey: AppleScreenTimeTips.pendingKey) || AppInfo.isDemoRun,
              !ChildLockSetup.isPending || AppInfo.isDemoRun
        else { return }
        kidTourActive = true
    }

    /// The child's side — niqqud, and the right form for a boy or a girl.
    private var kidTourSteps: [CoachStep] {
        [
            CoachStep(id: "k.world", title: tr("עוֹלָמוֹת"),
                      text: tr("בּוֹחֲרִים עוֹלָם, וְעוֹנִים בּוֹ עַל שְׁאֵלוֹת אוֹ מְשַׂחֲקִים. כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחָה דַּקּוֹת.")),
            CoachStep(id: "k.tofyTime", title: tr("טוֹפִי טַיים"),
                      text: Gendered.g(tr("שְׁאֵלוֹת שֶׁטּוֹפִי בּוֹחֵר בִּשְׁבִילְךָ, מִכָּל הָעוֹלָמוֹת."),
                                       tr("שְׁאֵלוֹת שֶׁטּוֹפִי בּוֹחֵר בִּשְׁבִילֵךְ, מִכָּל הָעוֹלָמוֹת."))),
            CoachStep(id: "k.games", title: tr("מִשְׂחָקִים"),
                      text: tr("מִשְׂחָקִים קְצָרִים — נִפְתָּחִים אַחֲרֵי כַּמָּה תְּשׁוּבוֹת נְכוֹנוֹת בַּיּוֹם.")),
            CoachStep(id: "k.minutes", title: tr("הַדַּקּוֹת"),
                      text: Gendered.g(tr("כָּאן פּוֹתְחִים אֶת הַדַּקּוֹת שֶׁהִרְוַחְתָּ, וְהַטֶּלֶפוֹן נִפְתָּח."),
                                       tr("כָּאן פּוֹתְחִים אֶת הַדַּקּוֹת שֶׁהִרְוַחְתְּ, וְהַטֶּלֶפוֹן נִפְתָּח."))),
            CoachStep(id: "k.wallet", title: tr("כּוֹכָבִים וִיהַלוֹמִים"),
                      text: tr("כּוֹכָבִים עַל כָּל הַצְלָחָה, וִיהַלוֹמִים לִקְנִיּוֹת בַּחֲנוּת.")),
            CoachStep(id: "k.challenge", title: tr("אֶתְגַּר יוֹמִי"),
                      text: tr("מְשִׂימָה קְטַנָּה כָּל יוֹם — וּפְרָס כְּשֶׁמְּסַיְּמִים.")),
            CoachStep(id: "k.chores", title: tr("מְטָלוֹת"),
                      text: tr("עוֹזְרִים בַּבַּיִת וּמַרְוִיחִים — אַבָּא אוֹ אִמָּא מְאַשְּׁרִים.")),
            CoachStep(id: "k.shop", title: tr("חֲנוּת"),
                      text: tr("קוֹנִים דְּמֻיּוֹת וּבְגָדִים עִם הַיַּהֲלוֹמִים.")),
            CoachStep(id: "k.friends", title: tr("חֲבֵרִים"),
                      text: tr("טַבְלַת הַחֲבֵרִים, וּמִשְׂחָק חַי בְּיַחַד.")),
            CoachStep(id: "k.settings", title: tr("לַהוֹרִים"),
                      text: tr("הַהַגְדָּרוֹת שֶׁל אַבָּא וְאִמָּא — נִפְתָּחוֹת רַק עִם קוֹד.")),
        ]
    }

    /// Event splash: announce today's event ONCE a day as a full pop-up (like the
    /// lucky wheel) — it used to be a permanent row eating map space. Never on
    /// top of the grade picker / school-year party / the update story, and the
    /// day is only marked when it really shows, so one that waited still comes.
    /// Not for a child who has barely played: a brand-new child's first screen
    /// was "סוף שבוע כפול! היהלומים כפולים" — before the map, with zero diamonds
    /// and no idea what one is (CampaignTracker.childPopupMinAnswers).
    private func maybeShowEventSplash() {
        guard GameEvent.current() != nil, !showChildGradePicker, !showSchoolYearParty, !storyPending,
              progress.totalAnswered >= CampaignTracker.childPopupMinAnswers else { return }
        let day = Calendar.current.component(.year, from: Date()) * 1000
            + (Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0)
        let key = "eventSplash.lastShownDay"
        guard UserDefaults.standard.integer(forKey: key) != day else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard !AppInfo.isDemoRun, !storyPending, !showEventSplash else { return }
            UserDefaults.standard.set(day, forKey: key)
            showEventSplash = true
        }
    }

    private func greetIfNeeded() {
        if progress.dayStreak == 0 {
            companion.cheer(tr("הֵיי! יַאלְלָה לְהַרְפַּתְקָה 🌟"))
        } else if progress.dayStreak == 1 {
            companion.cheer(Gendered.g(tr("בָּרוּךְ הַבָּא! 👋"), tr("בְּרוּכָה הַבָּאָה! 👋")))
        } else {
            companion.cheer(Gendered.g(tr("חָזַרְתָּ! \(progress.dayStreak) יָמִים בְּרֶצֶף 🔥"), tr("חָזַרְתְּ! \(progress.dayStreak) יָמִים בְּרֶצֶף 🔥")))
        }
    }

    /// Auto-presents the Lucky Wheel once the child has earned a free spin
    /// (after `questionsPerWheel` answers), then resets the counter so it
    /// won't pop again until the next batch. Replaces the old top-bar button.
    private func maybeAutoPresentWheel() {
        guard progress.freeWheelAvailable, !showingWheel, !showingSmartFeed, !storyPending else { return }
        progress.resetWheelProgress()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showingWheel = true
        }
    }

    /// One-time, after a child device joins: ask the parent (who is standing
    /// right there) what stays open. Shielding is device-local, so this has to
    /// happen here on the child device.
    ///
    /// NOTE deliberately NOT re-shown to existing installs: this screen opens
    /// Apple's picker without the parent code in front of it, and a child who
    /// found it could add apps to the allow-list. Families who already finished
    /// setup are nudged from the PARENT's device instead (the device row in the
    /// child's report), and the picker itself lives behind the gear + code.
    private func maybePromptAppLockSetup() {
        // 🔒 Retired (2026-10-05). The lock no longer needs this choice: a
        // child device is fully locked from the start (`newAppLockArmed`), and
        // "what stays open" is optional, behind the gear. This screen told a
        // new parent to "pick Tofy itself" or new apps would stay open — no
        // longer true, and one more step Rani wanted gone ("זה יותר מידי
        // התעסקות ואין מצב שאנשים יוכלו לסדר את זה לבד").
        return
        guard settings.deviceRole == .child,
              !settings.hasPromptedChildAppLock,
              settings.openByDesignApps.isEmpty,
              SelectionStorage.isEmpty(settings.activitySelectionData),
              !showingWheel, !showingSmartFeed, !storyPending
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showingAppLockSetup = true
        }
    }

    /// 🏫🌙 Inside school time / bedtime no minutes open (the parent's own open
    /// still can). Say when they come back, warmly, and stay on the map.
    private func quietBlocksOpening() -> Bool {
        guard let line = QuietHoursManager.shared.blockedMessage() else { return false }
        Haptic.light()
        progress.openWindowMessage = line
        return true
    }

    private func checkWorldUnlocks() {
        for world in Worlds.all where !progress.unlockedWorlds.contains(world.id) {
            if progress.canUnlock(world: world) {
                progress.unlockWorld(world.id)
                companion.wow(tr("\(world.emoji) \(world.name) נִפְתַּח!"))
            }
        }
    }

    /// Open earned minutes. With the lease ON, the CLAIM commits first (wallet
    /// debit + lease write in one transaction) and the shield only opens on a
    /// granted claim — never unshield before the claim is durable.
    private func redeemMinutes() {
        guard !progress.isUnlocked, !quietBlocksOpening() else { return }
        guard PlayWindowLeaseManager.isEnabled, let cid = profiles.activeID else {
            legacyRedeemMinutes(); return
        }
        // To the second (see `redeemableSecondsNow`): the leftover under a minute
        // is the child's too, and asking for whole minutes stranded it.
        let want = progress.redeemableSecondsNow
        guard want > 0, !isOpening else { return }
        progress.beginOpeningWindow(gift: false)
        Task { @MainActor in
            let outcome = await PlayWindowLeaseManager.shared.claim(
                childID: cid, kind: .earned, requestedSeconds: want)
            switch outcome {
            case .granted(let leaseID, let seconds, let wallet):
                guard seconds > 0 else {
                    progress.endOpeningWindow(message: tr("רֶגַע, לֹא הִצְלַחְנוּ לִפְתֹּחַ עַכְשָׁיו — נְנַסֶּה שׁוּב 😊"))
                    return
                }
                let mins = seconds / 60
                if let wallet { progress.applyClaimedWallet(wallet) }
                shields.unlock(minutes: max(1, (seconds + 59) / 60))
                progress.startUnlock(minutes: mins, leaseID: leaseID, leaseKind: "earned",
                                     extraSeconds: seconds % 60)
                LearningHistoryStore.shared.recordMinutesUsed(mins)
                LiveEventReporter.report(.screenTimeStart, extra: ["minutes": max(1, mins)])
                progress.endOpeningWindow()          // the play screen takes over
            case .heldElsewhere:
                // The lease listener drives the "open on your iPad" card + transfer.
                Haptic.warning()
                progress.endOpeningWindow(message: Gendered.g(tr("הַזְּמַן שֶׁלְּךָ פָּתוּחַ עַכְשָׁיו בְּמַכְשִׁיר אַחֵר 🎮"), tr("הַזְּמַן שֶׁלָּךְ פָּתוּחַ עַכְשָׁיו בְּמַכְשִׁיר אַחֵר 🎮")))
            case .insufficient:
                Haptic.light()
                progress.endOpeningWindow(message: Gendered.g(tr("עוֹד קְצָת דַּקּוֹת וְנִפְתַּח לְךָ! 💪"), tr("עוֹד קְצָת דַּקּוֹת וְנִפְתַּח לָךְ! 💪")))
            case .offline:
                // Transactions don't queue offline. Fall back to the bounded local
                // window so a kid with no network is never stranded.
                progress.endOpeningWindow()
                legacyRedeemMinutes()
            }
        }
    }

    private func legacyRedeemMinutes() {
        // Re-check (a fast double-tap with the 💝 button could open a manual
        // window first; without this guard startUnlock would overwrite it and
        // the gift window's banked leftover would be lost).
        guard !progress.isUnlocked, !quietBlocksOpening() else { return }
        // Cap a single unlock to today's remaining screen-time allowance; the
        // accumulated wallet beyond the daily cap stays for future days.
        let minutes = progress.consumeMinutesForUnlock()
        // Same rule as the gift: never return to the map in silence. The button is
        // only on screen when the wallet says there is time, so reaching this line
        // means our own numbers disagreed — which is ours to say out loud, kindly.
        guard minutes > 0 else {
            progress.endOpeningWindow(message: Gendered.g(tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַדַּקּוֹת שֶׁלְּךָ — נְנַסֶּה שׁוּב? 😊"), tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַדַּקּוֹת שֶׁלָּךְ — נְנַסֶּה שׁוּב? 😊")))
            return
        }
        shields.unlock(minutes: minutes)
        progress.startUnlock(minutes: minutes)
        LearningHistoryStore.shared.recordMinutesUsed(minutes)
        // Tell the parent the child just opened screen time (+ how many minutes).
        LiveEventReporter.report(.screenTimeStart, extra: ["minutes": minutes])
    }

    /// "מַתָּנָה מֵהַהוֹרִים · 29:40 + ❄️ 8 שְׁמוּרוֹת" — whatever parts exist.
    /// Shows the odd seconds when there are any: a child who locked at 29:40 and
    /// is told "30 דקות" (or "29") has been quietly rounded, which is exactly the
    /// kind of small lie about their time that costs trust.
    /// The gift pocket as the button sees it. DEMO_GIFT_MINUTES (screenshots
    /// only — the cloud snapshot would wipe a locally seeded pocket) overrides.
    private var giftOpenableSeconds: Int {
        if let m = ProcessInfo.processInfo.environment["DEMO_GIFT_MINUTES"].flatMap(Int.init) { return m * 60 }
        return progress.openableSeconds(gift: true)
    }

    /// "16" when it is whole minutes, "16:45" when there are odd seconds — the
    /// one format BOTH buttons use, so a child is never quietly rounded.
    /// Always "m:ss" — for a chip whose own label is the unit ("זְמַן מָסָךְ"),
    /// where a bare "2" would not say what it counts.
    static func clockLabel(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    static func timeLabel(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60)"
                          : "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    private var giftButtonTitle: String {
        let seconds = giftOpenableSeconds
        let frozen = progress.pausedManualMinutes
        var parts: [String] = []
        if seconds > 0 { parts.append(tr("\(Self.timeLabel(seconds)) דַּקּוֹת")) }
        if frozen > 0 { parts.append(tr("❄️ \(frozen) שְׁמוּרוֹת")) }
        return tr("מַתָּנָה מֵהַהוֹרִים · ") + parts.joined(separator: " + ")
    }

    /// 💝 Open ALL parent time as one fixed manual window: the gift pocket plus
    /// any frozen leftover. Outside the daily cap; leftover freezes again on
    /// stop-and-save (so nothing a parent gave is ever wasted).
    private func redeemGift() {
        guard !progress.isUnlocked, !quietBlocksOpening() else { return }
        guard PlayWindowLeaseManager.isEnabled, let cid = profiles.activeID,
              progress.openableSeconds(gift: true) > 0 else { legacyRedeemGift(); return }
        // Seconds included. Asking for `minutes * 60` stranded the carry: a window
        // locked at 29:40 re-opened at 29:00 and those 40 seconds could never be
        // spent — they just accumulated out of reach.
        let want = progress.openableSeconds(gift: true)
        guard !isOpening else { return }
        progress.beginOpeningWindow(gift: true)
        Task { @MainActor in
            let outcome = await PlayWindowLeaseManager.shared.claim(
                childID: cid, kind: .gift, requestedSeconds: want)
            switch outcome {
            case .granted(let leaseID, let seconds, let wallet):
                // Every second counts, including a pocket under a minute. Requiring
                // a whole minute here left Noa's last 0:24 unopenable FOREVER: the
                // button showed it, the tap failed, and after two tries we even
                // told her parents something was wrong (Rani, 2026-10-05). The
                // window is exactly what the lease granted — never less, and never
                // rounded up either (a bigger window than we debited would refund
                // seconds that never existed).
                guard seconds > 0 else { giftOpenFailed("grantTooSmall"); return }
                let mins = seconds / 60
                if let wallet { progress.applyClaimedWallet(wallet) }
                shields.unlock(minutes: max(1, (seconds + 59) / 60))
                progress.startUnlock(minutes: mins, manual: true, leaseID: leaseID, leaseKind: "gift",
                                     extraSeconds: seconds % 60)
                LiveEventReporter.report(.screenTimeStart, extra: ["minutes": max(1, mins), "gift": true])
                progress.giftOpenFailureStreak = 0
                progress.endOpeningWindow()
            case .heldElsewhere:
                Haptic.warning()
                progress.endOpeningWindow(message: Gendered.g(tr("הַזְּמַן שֶׁלְּךָ פָּתוּחַ עַכְשָׁיו בְּמַכְשִׁיר אַחֵר 🎮"), tr("הַזְּמַן שֶׁלָּךְ פָּתוּחַ עַכְשָׁיו בְּמַכְשִׁיר אַחֵר 🎮")))
            case .insufficient:
                // The button only exists when OUR pocket says there is time, so the
                // cloud saying otherwise is two ledgers disagreeing — not an empty
                // pocket. Never phrase it to the child as "you have nothing".
                Haptic.light()
                giftOpenFailed("cloudInsufficient")
            case .offline:
                progress.endOpeningWindow()
                legacyRedeemGift()
            }
        }
    }

    private func legacyRedeemGift() {
        guard !progress.isUnlocked, !quietBlocksOpening() else { return }   // re-check: PIN cover runs us later
        let gift = progress.consumeParentGiftForUnlock()
        // Frozen seconds resume as their own manual window; fold the gift on top.
        let frozenMinutes = progress.hasPausedManualTime ? progress.resumeManualUnlock() : 0
        let total = gift + frozenMinutes
        // THE SILENT RETURN THAT STARTED ALL THIS. A child tapped a 60-minute gift,
        // this guard fired, and she was put back on the map without a word — the
        // home screen's own "חזרת! 4 ימים ברצף" was the only thing she heard.
        guard total > 0 else { giftOpenFailed("walletDisagreement"); return }
        if gift > 0 {
            if frozenMinutes > 0 { progress.extendUnlock(minutes: gift) }
            else { progress.startUnlock(minutes: gift, manual: true, leaseKind: "gift") }
        }
        shields.unlock(minutes: total)
        progress.giftOpenFailureStreak = 0
        LiveEventReporter.report(.screenTimeStart, extra: ["minutes": total, "gift": true])
    }

    /// 💝 A gift open that did not happen.
    ///
    /// Two rules here, both deliberate. The child ALWAYS hears something — a silent
    /// return to the map is the defect this exists to delete. And nothing is ever
    /// taken away: the pocket stays exactly as it was, because a disagreement
    /// between two of our OWN ledgers must never cost a child minutes a parent
    /// really gave them. (The tempting opposite — wipe the gift after two failures
    /// and make the parent re-send it — destroys real time to paper over a bug of
    /// ours, and in this very case the counters were the side that was right.)
    ///
    /// The parent is told on the SECOND failure in a row. Once is a blip: a slow
    /// network, a window still open on the iPad. Twice means the child is tapping
    /// something that will not open, and only a parent can move it.
    private func giftOpenFailed(_ reason: String) {
        progress.giftOpenFailureStreak += 1
        let tellingParent = progress.giftOpenFailureStreak >= 2
        progress.endOpeningWindow(message: tellingParent
            ? Gendered.g(tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַמַּתָּנָה שֶׁלְּךָ — סִפַּרְתִּי לַהוֹרִים שֶׁלְּךָ וְהֵם יַעַזְרוּ 😊"), tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַמַּתָּנָה שֶׁלָּךְ — סִפַּרְתִּי לַהוֹרִים שֶׁלָּךְ וְהֵם יַעַזְרוּ 😊"))
            : Gendered.g(tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַמַּתָּנָה שֶׁלְּךָ — נְנַסֶּה שׁוּב? 😊"), tr("רֶגַע, אֲנִי בּוֹדֵק אֶת הַמַּתָּנָה שֶׁלָּךְ — נְנַסֶּה שׁוּב? 😊")))
        guard tellingParent else { return }
        LiveEventReporter.report(.giftOpenFailed,
                                 extra: ["minutes": giftOpenableSeconds / 60, "reason": reason])
        progress.giftOpenFailureStreak = 0   // told once; start counting afresh
    }

}

/// Minimal animated XP bar for the hero header.
struct XPBarMini: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(AppGradient.gold)
                    .frame(width: geo.size.width * progress)
                    .glow(AppColor.starGold, radius: 4)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    WorldMapView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ShieldManager.shared)
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .app)
}

/// Aligns the avatar, the name, and each header button CIRCLE on one line — the
/// button captions hang below without shifting it.
private extension VerticalAlignment {
    enum HeaderIconID: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }
    static let headerIcon = VerticalAlignment(HeaderIconID.self)
}

/// Type-erasure boundary for the header/scaffold builders above. NOT cosmetic:
/// without it, the fully-inlined generic type of body (topBar → navButtonsRow →
/// navButton → …) is so deep that a DEBUG build EXC_BAD_ACCESSes inside the Swift
/// runtime's metadata instantiation (buildDescriptorPath) on a physical device —
/// the main thread there has a 1MB stack vs 8MB in the simulator, which is why it
/// only crashed on-device. AnyView at each builder caps the nesting depth.
private extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}


/// Small deterministic PRNG (SplitMix64) — enough to shuffle a handful of cards
/// reproducibly, without pulling in a dependency or touching the system RNG.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// The gold "new today" breathing border used by a freshly gifted world and a
/// just-launched pack on the kid's home.
private struct FirstDayGlow: ViewModifier {
    let on: Bool
    @State private var glow = false
    func body(content: Content) -> some View {
        content
            .overlay {
                if on {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color(hex: "FFD23F").opacity(glow ? 0.95 : 0.25), lineWidth: 2.5)
                }
            }
            .shadow(color: Color(hex: "FFD23F").opacity(on ? (glow ? 0.7 : 0.15) : 0), radius: glow ? 22 : 8)
            .scaleEffect(on && glow ? 1.03 : 1)
            .onAppear {
                guard on else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { glow = true }
            }
    }
}
extension View {
    func firstDayGlow(_ on: Bool) -> some View { modifier(FirstDayGlow(on: on)) }
}
extension View {
    /// The kid's big action buttons on glass: the brand gradient at 85 % over a
    /// blur, a light edge, a soft drop shadow — never an opaque slab (Rani).
    func ctaGlass(_ a: Color, _ b: Color, colour: Double = 0.6) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return self
            .background {
                ZStack {
                    // Glass first, colour second: a white pane with the gradient
                    // glowing through it at ~60 %, and the top highlight every
                    // pane has — so the button reads as glass, not a slab (Rani).
                    // A faint dark base keeps whatever scrolls beneath from
                    // reading through the label.
                    shape.fill(Color(hex: "2A1E5C").opacity(0.35))
                    shape.fill(.white.opacity(0.16))
                    shape.fill(LinearGradient(colors: [a.opacity(colour + 0.02), b.opacity(colour - 0.02)],
                                              startPoint: .leading, endPoint: .trailing))
                    shape.fill(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                              startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)))
                }
            }
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.3)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1.2))
            .clipShape(shape)
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
    }
}
