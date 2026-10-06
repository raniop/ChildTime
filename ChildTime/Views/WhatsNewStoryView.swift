import SwiftUI

/// 📖 The "מה חדש" STORY — one player, two readers.
///
/// Approved from `reports/games/kid-whatsnew2.html` (direction ב) and
/// `reports/games/parent-story.html`. What Rani asked for, and what each of
/// these lines is here to keep true:
///
/// * **It opens by itself** on the first launch after an update: "זה צריך
///   להפתח לו ישירות בפעם הראשונה שהוא נכנס לטופי אחרי העדכון מבלי שהוא צריך
///   לעשות פעולה!" — so there is no gift box and nothing to tap to begin.
/// * **No button that leaves for another screen**: "בלי כפתור שמעביר למסך
///   פשוט אחרי שמסיימים לצפות בסטורים עוברים למסך הראשי של טופי או פתור דלג
///   והוא גם מעביר למסך הראשי". The last story simply ends and the cover
///   closes; ✕ / "דלג" does the same thing, immediately. The LAST card also
///   carries a button ("צריך כפתור למטה במסך האחרון") — it only does what
///   the ending already does, so nothing ever waits for it.
/// * **Every new thing gets its own story** — the content list decides how
///   many, never this view.
///
/// It advances by itself, a tap or a swipe moves on, and a tap on the side the
/// story came FROM (the right in Hebrew, mirrored with the layout direction,
/// exactly like the story format children already know) goes back.
struct WhatsNewStoryView: View {
    let audience: StoryAudience
    let items: [StoryItem]
    /// Called exactly once, when the last story ends or the child skips.
    let onFinish: () -> Void
    /// Screenshot runs only: open on a particular story instead of the first.
    var startAt: Int = 0
    /// Screenshot runs only: keep the clock RUNNING instead of holding the
    /// story still, so the segment bar can be driven and checked by hand.
    var liveInDemo: Bool = false
    /// Screenshot runs only (`DEMO_SLOW=1`): a long clock, so the bar can be
    /// photographed mid-fill after each tap.
    var demoSeconds: Double? = nil

    @Environment(\.horizontalSizeClass) private var hsc

    /// 🧊 The glass this story has, MEASURED here.
    ///
    /// This used to be `@ObservedObject DisplayGeometry.shared`, and that is
    /// what froze the screen black on one card: the probe republishes whenever
    /// the root's safe-area insets change, those insets flip by a single point
    /// between passes (`t67 b33` ⇄ `t68 b34`), and every publish re-evaluated
    /// this body, which re-laid out, which published again — an endless loop
    /// with nothing ever drawn. A story only needs its own size, so it takes
    /// its own size and observes nothing.
    @State private var canvas: CGSize = .zero

    @State private var index = 0
    /// How much of the CURRENT segment is filled, 0…1 — animated linearly for
    /// exactly as long as the story lasts, so the bar IS the clock.
    @State private var fill: CGFloat = 0
    @State private var ticker: Task<Void, Never>?
    /// Art and text arrive with a small rise. Never a `scaleEffect` — it blurs
    /// text for the whole animation, and this screen is mostly text.
    @State private var risen = false
    @State private var finished = false
    /// `startAt` has been applied — see `onAppear`.
    @State private var started = false
    /// How far a dismiss drag has pulled the card down, in points.
    @State private var dragY: CGFloat = 0

    // ⏸ The clock can stop. Rani: "אם שמתי את האצבע על המסך באמצע שזה יעצור
    // את הסטורי כדי שיהיה לי זמן לקרוא, וגם פליי פאוז ליד הרמקול". Two ways,
    // as in every story app: a finger held down stops it until it lifts, and
    // ⏸ stops it until ▶ — across cards too, so a slow reader stays in charge.
    /// ⏸ was pressed. Survives moving between cards; ▶ clears it.
    @State private var userPaused = false
    /// A finger is held on the card right now.
    @State private var holding = false
    /// Seconds of the current card already shown, not counting the run now going.
    @State private var shownBefore: Double = 0
    /// When the run now going started; nil while the clock is stopped.
    @State private var runStartedAt: Date?
    /// Bumped on every stop, so the gold bar is redrawn AT the stopped point
    /// instead of a tween running on to the end underneath it (see `segments`).
    @State private var stopCount = 0
    /// The touch now down on the card, if any — when it landed, and the timer
    /// that turns it from a tap into a hold.
    @State private var touchDownAt: Date?
    @State private var holdTimer: Task<Void, Never>?

    private var isCompact: Bool { hsc == .compact }
    /// A short screen — the open foldable, an SE — read off our own canvas.
    private var short: Bool { canvas.height > 0 && canvas.height < DisplayGeometry.shortHeight }
    private var isKid: Bool { audience == .child }

    /// The story on screen. `items` can never be empty here (the callers check),
    /// but a defensive placeholder beats a crash on an index.
    private var item: StoryItem? { items.indices.contains(index) ? items[index] : items.first }

    /// The AVAILABLE space is measured by an outer reader whose child is pinned
    /// to that very size. Measuring from inside the stack instead would read
    /// back the CONTENT's height — which these sizes then change — and that
    /// feedback is what hung one card on a black screen for good.
    var body: some View {
        GeometryReader { geo in
            story
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear { if canvas != geo.size { canvas = geo.size } }
                .onChangeCompat(of: geo.size) { _, new in if canvas != new { canvas = new } }
        }
    }

    private var story: some View {
        ZStack {
            // 🖼 Edge to edge. The story is laid out inside the safe area, and
            // the backdrop used to be too — so the strip behind the clock and
            // the one under the home bar showed the flat colour of whatever was
            // behind the story (Rani: "הרקע פה משהו לא תקין בחלק התחתון
            // והעליון"). The glass now runs under both; only the content keeps
            // to the safe area.
            GlassBackdrop()
                .ignoresSafeArea()
            // Few and small: a sparkle landing on a word reads as a typo, and
            // this screen is mostly words.
            SparkleField(count: short ? 5 : 7, size: 10)
                .ignoresSafeArea()

            // The tap layer sits UNDER the chrome, so 🔊 and ✕ keep their taps.
            tapZones

            VStack(spacing: 0) {
                segments
                    .padding(.horizontal, 14)
                    .padding(.top, short ? 6 : 10)
                topRow
                    .padding(.horizontal, 16)
                    .padding(.top, short ? 8 : 12)

                // The chrome is pinned (segments and corners at the top, the
                // footer at the bottom) and the story itself is one block of a
                // measured height, with the slack split above and below it. A
                // plain top-pinned VStack left a third of a tall phone — and
                // half an iPad — empty under the last line.
                Spacer(minLength: 0)
                // 👆 A story is looked at, never operated. The real app screens
                // shrunk into the phone frame are LIVE views — the balloons,
                // the vault — and they used to swallow every tap that landed
                // on them, so a tap on the side did nothing over half the
                // card (Rani: "הצדדים לא תקינים בלחיצות"). Nothing in here is
                // a control, so taps go straight through to the side zones.
                Group {
                    if let item {
                        if isKid { kidBody(item) } else { parentBody(item) }
                    }
                }
                .allowsHitTesting(false)
                Spacer(minLength: 0)

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, short ? 10 : 18)
            }
            // A story is a POSTER, not a phone screen parked in the middle of
            // an iPad. The column still has a readable cap, but a generous one:
            // on a 13" iPad it uses most of the glass instead of a 560pt strip
            // marooned in the centre.
            .frame(maxWidth: columnWidth)
            .frame(maxWidth: .infinity)
        }
        // 👇 Swipe-down-to-dismiss: the whole card rides the finger and takes a
        // sheet's corner radius on the way, so letting go feels like letting go
        // of a story rather than like a button.
        // A mask that reaches past the safe area too — a plain `clipShape` cut
        // the edge-to-edge backdrop above back to the safe area.
        .mask {
            RoundedRectangle(cornerRadius: dragY > 0 ? 34 : 0, style: .continuous)
                .ignoresSafeArea()
        }
        .offset(y: dragY)
        .environment(\.layoutDirection, .app)
        .onAppear {
            // The start index is applied ONCE. `onAppear` can fire again for
            // the same story (a re-layout, a return from the background), and
            // re-applying `startAt` then threw a tap's move away.
            if !started, startAt > 0, items.indices.contains(startAt) {
                started = true
                index = startAt
            } else {
                started = true
                begin()
            }
        }
        .onDisappear { ticker?.cancel(); holdTimer?.cancel(); SpeechReader.shared.stop() }
        .onChangeCompat(of: index) { _, _ in begin() }
    }

    // MARK: - 👧 The child's story: art first, name under it

    /// 🎮 …except on a GAME card, where the name goes ON TOP. Rani pictured
    /// it that way — "תמונה מוקטנת של כל משחק עם הסבר קטן למעלה" — and he is
    /// right: the board is the thing to look at, so it gets the bottom of the
    /// card to itself instead of being a lid over two lines of text.
    private func namesGameFirst(_ item: StoryItem) -> Bool {
        switch item.art {
        case .game, .gameGrid: return true
        default: return false
        }
    }

    @ViewBuilder
    private func kidBody(_ item: StoryItem) -> some View {
        VStack(spacing: short ? 8 : 14) {
            if namesGameFirst(item) {
                kidTitle(item)
                kidLine(item)
            }

            StoryArtView(art: item.art, isCompact: isCompact, short: short)
                .frame(maxWidth: .infinity)
                .frame(height: kidArtHeight)

            if !namesGameFirst(item) {
                kidTitle(item)
                kidLine(item)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, short ? 6 : 14)
        .padding(.bottom, short ? 6 : 16)
        .offset(y: risen ? 0 : 16)
        .opacity(risen ? 1 : 0)
    }

    /// The card already shows the real screen — the game's emoji on top of that
    /// was noise, and inline it pushed a centred RTL title off-centre. Dropped
    /// entirely (Rani, build 188): the name alone.
    private func kidTitle(_ item: StoryItem) -> some View {
        let (_, name) = Self.splitLeadingMark(item.title)
        return VStack(spacing: 0) {
            Text(name)
                .font(.system(size: kidTitleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.55)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
    }

    /// Splits "🎈 בַּלּוֹנִים" into ("🎈", "בַּלּוֹנִים"); returns (nil, title) when
    /// the title does not start with one.
    static func splitLeadingMark(_ title: String) -> (String?, String) {
        guard let first = title.first, first.unicodeScalars.contains(where: { $0.properties.isEmoji && $0.value > 0x238C }),
              let space = title.firstIndex(of: " ") else { return (nil, title) }
        let mark = String(title[title.startIndex..<space])
        let rest = String(title[title.index(after: space)...])
        guard !rest.isEmpty else { return (nil, title) }
        return (mark, rest)
    }

    private func kidLine(_ item: StoryItem) -> some View {
        Text(item.line)
            .font(.system(size: kidLineSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 👨‍👩‍👧 The parent's story: the point first, the example under it

    @ViewBuilder
    private func parentBody(_ item: StoryItem) -> some View {
        VStack(spacing: short ? 6 : 10) {
            if let kicker = item.kicker {
                Text(kicker)
                    .font(.system(size: parentKickerSize, weight: .black, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
            }
            Text(item.title)
                .font(.system(size: parentTitleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.26), radius: 9, y: 3)

            Text(item.line)
                .font(.system(size: parentLineSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)

            // The stage runs from under the lead to just above the footer, as
            // the mockup draws it — it is what grows on a tall screen.
            //
            // 📱 …except a card that IS a phone. That art already carries a
            // device frame of its own, and a glass pane around a phone is two
            // frames arguing, with a band of empty glass between them.
            StoryArtView(art: item.art, isCompact: isCompact, short: short)
                .frame(maxWidth: .infinity)
                .frame(height: parentStageHeight(item.art))
                .padding(.vertical, framesItself(item.art) ? 0 : (short ? 10 : 16))
                .glassPaneUnless(framesItself(item.art), radius: 24)
                .padding(.top, short ? 8 : 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, short ? 10 : 18)
        .padding(.bottom, short ? 8 : 16)
        .offset(y: risen ? 0 : 16)
        .opacity(risen ? 1 : 0)
    }

    /// A phone-framed screen brings its own border and shadow.
    private func framesItself(_ art: StoryArt) -> Bool {
        switch art {
        case .game, .preReaderGame, .gameGrid, .chooser, .chat: return true
        case .chips: return ProfileStore.shared.active != nil
        default: return false
        }
    }

    // MARK: - Chrome

    /// The thin segments children know: one per story, filling in real time.
    ///
    /// 🐛 Twice now, from Rani tapping through by hand: "החיווי למעלה שעוברים
    /// מסך ידני עדיין לא תקין". Two separate causes, both fixed here.
    ///
    /// 1️⃣ ANIMATION. One animated `fill` drove every segment's width, so a
    /// segment a tap skipped past kept the interrupted `.linear` animation and
    /// crawled toward its new target for the rest of that animation. The bar is
    /// now a pure function of `(index, fill)` and only the CURRENT segment may
    /// animate at all; everything else snaps.
    ///
    /// 2️⃣ DIRECTION. I pinned this bar left-to-right once, reasoning that a
    /// progress bar is a time axis rather than a sentence. That was wrong, and
    /// Rani sent it back: "תחזיר מצד ימין לשמאל בעברית". In Hebrew the whole
    /// story mirrors — the first card is on the RIGHT, a tap on the right goes
    /// back, the swipe runs right-to-left — and a bar that filled the other
    /// way fought every one of them. That mismatch is what made the side taps
    /// feel "הפוכים": the bar said story 1 was on the left, the taps said it
    /// was on the right.
    ///
    /// So the bar mirrors with everything else. Segment 0 sits on the leading
    /// edge — right in Hebrew and Arabic, left in English and Russian — and
    /// the gold grows towards the trailing edge, inside each segment too.
    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.3))
                        Capsule().fill(AppColor.starGold)
                            .frame(width: g.size.width * segmentFill(i))
                            // 🐛 3️⃣ THE CRAWL — caught on the simulator with a
                            // slowed clock. Leave a segment before it is full
                            // and its `.linear` tween is still in flight; its
                            // target (full) does not even change, so SwiftUI
                            // lets that tween run on and the segment you left
                            // creeps up for the rest of its seconds while the
                            // next one is already filling. Switching the
                            // animation off cannot stop a tween already
                            // running — a NEW view can. The gold bar takes a
                            // fresh identity whenever its segment changes
                            // phase (done / now / next), so it is born in its
                            // final state with nothing left over to finish.
                            .id(segmentPhase(i))
                            .transaction { t in if i != index { t.animation = nil } }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 4)
            }
        }
        .frame(height: 4)
        // 🧭 The same direction as the taps and the swipe — see above. Stated
        // rather than inherited, so no parent can flip the bar away from them.
        .environment(\.layoutDirection, .app)
    }

    /// Read it as state, not as a timeline: before = done, current = running,
    /// after = not started.
    private func segmentPhase(_ i: Int) -> String {
        "\(i)." + (i < index ? "done" : i == index ? "now.\(stopCount)" : "next")
    }

    private func segmentFill(_ i: Int) -> CGFloat {
        if i < index { return 1 }
        if i == index { return fill }
        return 0
    }

    /// Change state with every animation switched off — used for the reset and
    /// for every manual move, so a tap can never leave a tween behind.
    private func snap(_ change: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, change)
    }

    @ViewBuilder
    private var topRow: some View {
        HStack(spacing: 10) {
            if isKid {
                // The mockup's own corners: the brand line leads, ✕ closes from
                // the far side, and 🔊 sits where a child's thumb already is.
                Text(tr("⚡ חָדָשׁ בְּטוֹפִי"))
                    .font(.system(size: isCompact ? 13.5 : 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer(minLength: 0)
                // 🔊 reads the story out loud. A child who cannot read yet hears
                // it automatically (below) and can always ask again here.
                pauseButton
                roundButton("🔊", label: tr("הַקְשִׁיבוּ שׁוּב")) {
                    if let item { SpeechReader.shared.speak(item.spokenText) }
                }
                roundButton("✕", label: tr("סְגִירָה")) { finish() }
            } else {
                // Just the name. The version and build used to sit here so a
                // parent could quote them — but it made the card read like a
                // changelog, and the version is on the home screen anyway
                // (Rani, build 189).
                Text(tr("טופי"))
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
                pauseButton
                Button { finish() } label: {
                    Text(tr("דלג"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.16)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.32), lineWidth: 1))
                }
                .buttonStyle(.juicy)
            }
        }
    }

    /// ⏸ / ▶ — beside 🔊 for a child, beside "דלג" for a parent.
    private var pauseButton: some View {
        Button {
            Haptic.light()
            userPaused.toggle()
            userPaused ? stopClock() : startClock()
        } label: {
            Image(systemName: userPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(.white.opacity(userPaused ? 0.34 : 0.2)))
                .overlay(Circle().strokeBorder(.white.opacity(0.42), lineWidth: 1))
        }
        .buttonStyle(.juicy)
        .accessibilityLabel(userPaused
                            ? (isKid ? Gendered.g(tr("הַמְשֵׁךְ"), tr("הַמְשִׁיכִי")) : tr("המשך"))
                            : (isKid ? tr("עֲצִירָה") : tr("עצירה")))
    }

    private func roundButton(_ glyph: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            Text(glyph)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(.white.opacity(0.2)))
                .overlay(Circle().strokeBorder(.white.opacity(0.42), lineWidth: 1))
        }
        .buttonStyle(.juicy)
        .accessibilityLabel(label)
    }

    /// The bottom line — and, on the LAST story only, a real button instead.
    ///
    /// Rani: "צריך כפתור למטה במסך האחרון עם כניסה לאפליקציה או משהו". Nothing
    /// about the ending changed: the story still closes by itself when the last
    /// one runs out, and ✕ / "דלג" still close it at any point. This is one
    /// more way out, on the one card where there is nothing else to press — so
    /// the last frame doesn't feel like it ended on its own. It replaces the
    /// "עוברים למסך הבית…" line rather than sitting under it saying the same
    /// thing twice.
    @ViewBuilder
    private var footer: some View {
        if index == items.count - 1 {
            Button {
                Haptic.success()
                finish()
            } label: {
                Text(isKid ? tr("יַאלְלָה, מַמְשִׁיכִים! 🚀") : tr("כניסה לטופי"))
                    .font(.system(size: isCompact ? 19 : 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.textOnLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, short ? 13 : 16)
                    .background(AppGradient.gold, in: Capsule())
                    .glow(AppColor.starGold, radius: 14)
            }
            .buttonStyle(.juicy)
            .frame(maxWidth: 420)
            .padding(.horizontal, 8)
        } else {
            HStack(spacing: 6) {
                // 👆 The gesture that is actually used is a TAP on the side, so
                // the hint names the side (Rani: "רשמת החליקו לבא — יש החלקה
                // או רק לחיצה בצדדים?"). The side is in each translation: left
                // in Hebrew and Arabic, right in English and Russian — and the
                // chevron beside it points the same way.
                Text(isKid ? tr("לוֹחֲצִים מִשְּׂמֹאל לַבָּא") : tr("מתחלף לבד · לחיצה משמאל לבא"))
                Image(systemName: AppSymbol.forwardChevron).font(.system(size: 11, weight: .black))
            }
            .font(.system(size: isCompact ? 13 : 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.78))
        }
    }

    // MARK: - Moving between stories

    /// Instagram's two zones, full height: the third on the START side goes
    /// back, everything else goes on. Rani: "תן לי אפשרות לעשות טאפ בצדדים
    /// שמעביר לכל צד כמו באינסטגרם" — and then, on the device: "הצדדים
    /// הפוכים! תחזיר מצד ימין לשמאל בעברית".
    ///
    /// In Hebrew and Arabic the story runs right to left: the first card is on
    /// the RIGHT (so is the first segment of the bar), a tap on the right goes
    /// BACK and a tap on the left goes ON. English and Russian are the mirror.
    ///
    /// 🐛 Measured on the simulator: in a Hebrew screen a tap's LOCAL x comes
    /// back mirrored — a tap on the physical left edge reported x ≈ width —
    /// so the side zones ran backwards, exactly what Rani felt on the device.
    /// The tap is now read in GLOBAL (screen) coordinates, which no layout
    /// direction ever mirrors, against this layer's own global frame, and
    /// `sideTap` says in one line which physical side is which.
    ///
    /// This layer sits under the chrome in the ZStack, so 🔊, ✕ / "דלג" and the
    /// last card's button keep their own taps; the card's content is
    /// `allowsHitTesting(false)` so it cannot swallow a tap meant for a side.
    ///
    /// ⏸ It is also where a finger is HELD. One touch, read three ways: lifted
    /// quickly in place → a tap on a side; held in place → the clock stops
    /// until it lifts (and lifting moves nowhere); moved → a swipe. They are
    /// one gesture rather than three because a tap, a hold and a swipe on the
    /// same layer would otherwise fight over the same finger.
    private var tapZones: some View {
        GeometryReader { g in
            Color.clear
                .contentShape(Rectangle())
                .gesture(touch(in: g))
        }
        .ignoresSafeArea()
    }

    /// Held this long without moving, a touch is reading, not tapping.
    private static let holdAfter: Double = 0.22
    /// Moved further than this, a touch is a swipe.
    private static let tapSlop: CGFloat = 12

    private func touch(in g: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard !finished else { return }
                if touchDownAt == nil {
                    touchDownAt = Date()
                    holdTimer?.cancel()
                    holdTimer = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(Self.holdAfter * 1_000_000_000))
                        guard !Task.isCancelled, touchDownAt != nil, dragY == 0 else { return }
                        holding = true
                        stopClock()
                    }
                }
                let dx = value.translation.width, dy = value.translation.height
                if hypot(dx, dy) > Self.tapSlop, !holding { holdTimer?.cancel() }
                // 👇 Pulling down drags the whole card towards dismissal.
                if dragY > 0 || (dy > Self.tapSlop && dy > abs(dx)) {
                    holdTimer?.cancel()
                    if dragY == 0 { stopClock() }   // nothing advances under the finger
                    dragY = max(0, dy)
                }
            }
            .onEnded { value in
                holdTimer?.cancel()
                let wasHolding = holding
                holding = false
                touchDownAt = nil
                guard !finished else { return }
                let dx = value.translation.width, dy = value.translation.height

                // A drag that was going down — finish the dismiss or spring back.
                if dragY > 0 {
                    let projected = dy + value.predictedEndTranslation.height * 0.25
                    if dy > Self.dismissDistance || projected > Self.dismissDistance * 2 {
                        Haptic.light()
                        finish()
                    } else {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { dragY = 0 }
                        startClock()   // carries on from where it stopped
                    }
                    return
                }

                // Sideways — between stories.
                if abs(dx) > Self.tapSlop, abs(dx) > abs(dy) {
                    let towardsStart = dx > 0
                    let forward = LayoutDirection.app == .rightToLeft ? towardsStart : !towardsStart
                    forward ? advance() : back()
                    startClock()   // a held finger that swiped lets go of the clock too
                    return
                }

                // Held to read — letting go carries on, and moves nowhere.
                if wasHolding { startClock(); return }

                // A tap.
                guard hypot(dx, dy) <= Self.tapSlop else { startClock(); return }
                let frame = g.frame(in: .global)
                sideTap(fromLeft: (value.location.x - frame.minX) / max(1, frame.width))
            }
    }

    /// `fromLeft` is 0 at the physical left edge and 1 at the right.
    private func sideTap(fromLeft: CGFloat) {
        let rtl = LayoutDirection.app == .rightToLeft
        let onStartSide = rtl ? fromLeft > 0.68 : fromLeft < 0.32
        onStartSide ? back() : advance()
    }

    /// How far down a drag has to go to let go of the story.
    private static let dismissDistance: CGFloat = 130

    private func begin() {
        ticker?.cancel()
        // Snap the reset: assigned under a running `.linear`, `fill = 0` would
        // RETARGET that animation instead of ending it, and the segment we just
        // left would keep crawling.
        snap { fill = 0; risen = false }
        withAnimation(.easeOut(duration: 0.38)) { risen = true }
        // 📸 A screenshot run holds the story still — the segment is drawn
        // part-filled so the bar still reads as "mid-story".
        guard !AppInfo.isDemoRun || liveInDemo else { snap { risen = true; fill = 0.45 }; return }
        shownBefore = 0
        runStartedAt = nil
        speakIfPreReader()
        startClock()
    }

    /// This card's whole time on screen.
    private var cardSeconds: Double { demoSeconds ?? item?.seconds ?? 5 }

    /// Runs the clock from wherever it stopped — unless something is still
    /// holding it: ⏸, a finger, a dismiss drag, or a screenshot run.
    private func startClock() {
        guard !finished, runStartedAt == nil, !userPaused, !holding, dragY == 0,
              !AppInfo.isDemoRun || liveInDemo else { return }
        let seconds = cardSeconds
        let left = max(0.05, seconds - shownBefore)
        runStartedAt = Date()
        withAnimation(.linear(duration: left)) { fill = 1 }
        ticker?.cancel()
        ticker = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(left * 1_000_000_000))
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    /// Stops the clock and the gold bar exactly where they are.
    private func stopClock() {
        ticker?.cancel()
        guard let started = runStartedAt else { return }
        shownBefore = min(cardSeconds, shownBefore + Date().timeIntervalSince(started))
        runStartedAt = nil
        let at = CGFloat(shownBefore / max(0.05, cardSeconds))
        snap { stopCount += 1; fill = at }
    }

    /// 👶 A child who cannot read yet gets the story spoken without asking —
    /// the pictures and the voice carry it, and the text is there for whoever
    /// is reading along. Everyone else taps 🔊 if they want it.
    private func speakIfPreReader() {
        guard isKid, PreReaderGames.activeChildIsPreReader, let item else { return }
        SpeechReader.shared.speak(item.spokenText)
    }

    private func advance() {
        guard !finished else { return }
        Haptic.light()
        if index + 1 < items.count {
            // `fill = 0` in the SAME transaction as the move: the new segment
            // is born empty instead of inheriting the old one's full bar for
            // a frame.
            snap { index += 1; fill = 0 }
        } else {
            finish()
        }
    }

    private func back() {
        guard !finished, index > 0 else { return }
        Haptic.light()
        snap { index -= 1; fill = 0 }
    }

    /// One way out, used by the last story, by ✕ and by "דלג" alike — and only
    /// ever once, so a tap racing the timer cannot dismiss twice.
    private func finish() {
        guard !finished else { return }
        finished = true
        ticker?.cancel()
        SpeechReader.shared.stop()
        onFinish()
    }

    // MARK: - Sizes

    // MARK: Sizes
    //
    // Everything here is a SHARE of the glass this story actually has, not a
    // constant: the mockup's art dominates the frame, and that has to stay true
    // on a short foldable, a tall phone and a 13" iPad alike. A fixed column
    // with fixed type made the iPad a phone layout floating in the middle.

    private var safeH: CGFloat { canvas.height }
    private var safeW: CGFloat { canvas.width }

    /// Height-driven value, clamped. Falls back to `lo` before the first
    /// measurement lands.
    private func share(_ fraction: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        guard safeH > 0 else { return lo }
        return Swift.min(Swift.max(safeH * fraction, lo), hi)
    }

    /// The readable column. A phone uses all of it; a big screen keeps a cap,
    /// but a poster-sized one. Only ever a CAP — nothing inside is given a
    /// fixed width, or a screen narrower than the cap would overflow it.
    private var columnWidth: CGFloat {
        guard !isCompact, safeW > 0 else { return 560 }
        return Swift.min(safeW * 0.92, 900)
    }

    /// 👧 Art first and big. 📱 A game card is now a whole PHONE, so it takes
    /// every point it can get — the frame is tall and narrow, and the slack
    /// left over goes beside it, not above it.
    private var kidArtHeight: CGFloat {
        switch item?.art {
        case .game?, .gameGrid?: return share(isCompact ? 0.62 : 0.66, min: 200, max: 980)
        default: break
        }
        return share(isCompact ? 0.48 : 0.58, min: 170, max: 860)
    }

    /// 👨‍👩‍👧 The stage's height, inside the glass pane's own padding.
    ///
    /// A hero or a grid happily fills whatever it is given. A list of example
    /// ROWS does not — stretched over an iPad's share it becomes three
    /// enormous bands with a line of text floating in each — so the pane hugs
    /// them instead, and a row stays the size of a row.
    private func parentStageHeight(_ art: StoryArt) -> CGFloat {
        let height = share(isCompact ? 0.40 : 0.48, min: 150, max: 780)
        let gap = Swift.max(8, height * 0.045)
        switch art {
        case .rows(let list):
            let n = CGFloat(Swift.max(list.count, 1))
            let tallestRow: CGFloat = isCompact ? 58 : 112
            return Swift.min(height, n * tallestRow + (n - 1) * gap)
        case .chat where framesItself(art), .chooser, .chips where framesItself(art):
            return share(isCompact ? 0.52 : 0.58, min: 180, max: 900)
        case .chat(let lines):
            // Bubbles, like rows, look stranded in a pane built for a poster.
            let n = CGFloat(Swift.max(lines.count, 1))
            return Swift.min(height, n * (isCompact ? 104 : 140) + gap)
        case .game, .preReaderGame, .gameGrid:
            // A phone wants height, and the parent's cards have text above it.
            return share(isCompact ? 0.52 : 0.58, min: 180, max: 900)
        default:
            return height
        }
    }

    private func type(_ fraction: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        guard safeH > 0 else { return lo }
        return Swift.min(Swift.max(safeH * fraction, lo), hi)
    }

    private var kidTitleSize: CGFloat {
        isCompact ? (short ? 26 : 32) : type(0.046, min: 38, max: 72)
    }
    private var kidLineSize: CGFloat {
        isCompact ? (short ? 15 : 17) : type(0.023, min: 20, max: 36)
    }
    private var parentTitleSize: CGFloat {
        isCompact ? (short ? 23 : 28) : type(0.039, min: 32, max: 60)
    }
    private var parentLineSize: CGFloat {
        isCompact ? (short ? 14 : 15.5) : type(0.020, min: 18, max: 30)
    }
    private var parentKickerSize: CGFloat {
        isCompact ? 13.5 : type(0.016, min: 15, max: 24)
    }
}

// MARK: - The art

/// Everything that can fill the middle of a story. Adding a kind of card is a
/// case here plus a case in `StoryArt` — never a new screen.
///
/// Every size below is derived from `box`, the glass this card actually got.
/// That is the whole difference between a poster on a 13" iPad and a phone
/// card stranded in the middle of one.
private struct StoryArtView: View {
    let art: StoryArt
    let isCompact: Bool
    let short: Bool

    /// The card MEASURES the space it was given rather than being told a
    /// width. A width handed down from `DisplayGeometry` is a fixed width, and
    /// a fixed width wider than the screen pushes the whole column off both
    /// edges — which is exactly what it did on a 420pt phone.
    var body: some View {
        GeometryReader { geo in
            Box(art: art, box: geo.size, isCompact: isCompact, short: short)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// The card itself, once its space is known.
private struct Box: View {
    let art: StoryArt
    /// The space this card is drawn in. Nothing here is a constant.
    let box: CGSize
    let isCompact: Bool
    let short: Bool

    var body: some View {
        switch art {
        case .emoji(let e):
            hero(e)
        case .character(let who):
            characterHero(who)
        case .game(let kind, let topic):
            gameArt(kind, topic: topic)
        case .preReaderGame(let kind, let topic):
            gameArt(kind, topic: topic, preReader: true)
        case .gameGrid(let kinds, let names):
            gameGridArt(kinds, names: names)
        case .chooser(let kind, let topic):
            chooserArt(kind, topic: topic)
        case .vault(let code, let clues):
            vaultArt(code: code, clues: clues)
        case .chips(let list, let selected):
            chipsArt(list, selected: selected)
        case .chat(let lines):
            chatArt(lines)
        case .tiles(let list):
            tiles(list)
        case .rows(let rows):
            rowsArt(rows)
        case .gift(let who, let stars, let diamonds):
            gift(who, stars: stars, diamonds: diamonds)
        }
    }

    /// Tofy's own artwork, never the system emoji that happens to look like the
    /// same animal — the child's buddy is the one they chose in the shop.
    private func character(_ who: StoryCharacter) -> Character3D {
        switch who {
        case .lion:        return Character3DCatalog.find("lion")
        case .childsBuddy: return ProfileStore.shared.active?.character ?? Character3DCatalog.find(nil)
        }
    }

    private func characterHero(_ who: StoryCharacter) -> some View {
        ZStack {
            glow(AppColor.starGold, size: glowSize)
            CharacterView(character: character(who))
                .frame(width: heroSize * 1.3, height: heroSize * 1.3)
                .float(amplitude: 8)
        }
        .frame(width: box.width, height: box.height)
    }

    /// One huge emoji on its own glow — the simplest story there is.
    private func hero(_ emoji: String) -> some View {
        ZStack {
            glow(AppColor.starGold, size: glowSize)
            Text(emoji)
                .font(.system(size: heroSize))
                .shadow(color: .black.opacity(0.32), radius: 18, y: 12)
        }
        .frame(width: box.width, height: box.height)
    }

    /// 📱 THE REAL SCREEN, JUST SMALLER.
    ///
    /// Rani, after build 188: "אני רוצה שהסטוריז התצוגה של מסך חדש תהיה
    /// אמיתית מתוך האפליקציה פשוט מוקטנת קצת" — with a picture of the whole
    /// grocery screen inside a phone. So the card no longer draws a stylised
    /// board at all: `MiniGameScreenPreview` builds the game's REAL view at a
    /// phone's size, inert, and scales it into the stage inside a device
    /// frame. The title and its one line stay above it.
    private func gameArt(_ kind: MiniGameKind, topic: Topic, preReader: Bool? = nil) -> some View {
        Group {
            if let preReader {
                MiniGameScreenPreview(kind: kind, topic: topic, preReader: preReader, box: box)
            } else {
                MiniGameScreenPreview(kind: kind, topic: topic, box: box)
            }
        }
        .frame(width: box.width, height: box.height)
    }

    /// 🎮🎮 Up to four games on one card — each the REAL screen in its own
    /// phone, its name under it. Two to a row; an odd last one sits centred.
    /// Every size comes from `box`, so the same card is four small phones on
    /// an SE and four big ones on a 13" iPad.
    private func gameGridArt(_ kinds: [MiniGameKind], names: [String]) -> some View {
        let cols = kinds.count == 1 ? 1 : 2
        let rows = (kinds.count + cols - 1) / cols
        let gap = Swift.max(10, Swift.min(box.width, box.height) * 0.04)
        let label = Swift.max(18, Swift.min(34, box.height * 0.045))
        let cellW = (box.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let cellH = (box.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        let phone = CGSize(width: cellW, height: Swift.max(40, cellH - label - 6))
        return VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(r * cols ..< Swift.min(kinds.count, r * cols + cols), id: \.self) { i in
                        VStack(spacing: 6) {
                            MiniGameScreenPreview(kind: kinds[i],
                                                  topic: WhatsNewStories.previewTopic(kinds[i]),
                                                  box: phone)
                                .frame(width: phone.width, height: phone.height)
                            Text(names.indices.contains(i) ? names[i] : "")
                                .font(.system(size: label * 0.8, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                                .frame(height: label)
                        }
                        .frame(width: cellW)
                    }
                }
            }
        }
        .frame(width: box.width, height: box.height)
    }

    /// The real board in a frame that HUGS it: `MiniGamePreview` draws at
    /// `min(w, h × 1.6)`, so a box in that ratio is filled edge to edge
    /// instead of being a big pane of padding around a small board.
    private func board(_ kind: MiniGameKind, topic: Topic,
                       preReader: Bool?, height: CGFloat, maxWidth: CGFloat? = nil) -> some View {
        let pad = Swift.max(8, box.height * 0.035)
        let limit = maxWidth ?? box.width
        let w = Swift.min(limit, (height - pad * 2) * 1.6 + pad * 2)
        return Group {
            if let preReader {
                MiniGamePreview(kind: kind, topic: topic, preReader: preReader)
            } else {
                MiniGamePreview(kind: kind, topic: topic)
            }
        }
        .frame(width: w - pad * 2, height: height - pad * 2)
        .padding(pad)
        .glassInset(radius: Swift.max(14, box.height * 0.055))
    }

    /// 🕹 The chooser, as the child meets it: "שאלות" on one side, a real game
    /// board on the other, with the game outlined the way the screen outlines
    /// a pick. Two real choices, not an icon of a choice.
    /// 🕹 The chooser, as the child really meets it — the real
    /// `WorldGameChooserView` on a fixed world, inert, inside the phone.
    ///
    /// It needs the three stores it normally gets from the app, so they are
    /// handed to it explicitly: a story can be presented from a cover whose
    /// environment is not the one the screen was written for.
    private func chooserArt(_ kind: MiniGameKind, topic: Topic) -> some View {
        PhoneFrame(box: box) {
            WorldGameChooserView(world: Self.chooserWorld)
                .environmentObject(ParentSettings.shared)
                .environmentObject(ProgressStore.shared)
                .environmentObject(ProfileStore.shared)
        }
    }

    /// One world, always the same one, so the card does not change shape
    /// between showings. Maths is the world every child has unlocked.
    private static var chooserWorld: World {
        Worlds.all.first { $0.id == "math_kingdom" } ?? Worlds.all[0]
    }

    /// 🔐 The vault's point in one picture: the code with one digit known, and
    /// the clues that are open so far.
    private func vaultArt(code: [String], clues: [String]) -> some View {
        let slot = Swift.min(box.height * 0.22, box.width * 0.17)
        let font = Swift.min(Swift.max(box.height * 0.07, 13), 22)
        return VStack(spacing: box.height * 0.07) {
            // The code reads left to right, like every number in the app.
            HStack(spacing: slot * 0.26) {
                ForEach(Array(code.enumerated()), id: \.offset) { _, digit in
                    Text(digit)
                        .font(.system(size: slot * 0.5, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(digit == "?" ? .white.opacity(0.45) : AppColor.starGold)
                        .frame(width: slot, height: slot)
                        .background(RoundedRectangle(cornerRadius: slot * 0.26, style: .continuous)
                            .fill(.white.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: slot * 0.26, style: .continuous)
                            .strokeBorder(.white.opacity(0.38), lineWidth: 1.5))
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            VStack(alignment: .leading, spacing: font * 0.45) {
                ForEach(Array(clues.enumerated()), id: \.offset) { _, clue in
                    HStack(spacing: font * 0.45) {
                        Text("💡").font(.system(size: font))
                        Text(clue)
                            .font(.system(size: font, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
        }
    }

    /// ⏱ The real daily-cap picker, with an option taken. It wants a child
    /// and a binding; the binding is constant, so nothing it does can change
    /// a cap. Falls back to the drawn chips when there is no child yet.
    @ViewBuilder
    private func chipsArt(_ list: [String], selected: Int) -> some View {
        if let profile = ProfileStore.shared.active {
            PhoneFrame(box: box) {
                DailyCapStepView(profile: profile,
                                 minutes: .constant(DailyCapChoice.defaultMinutes),
                                 onContinue: {})
            }
        } else {
            drawnChips(list, selected: selected)
        }
    }

    /// The chips as a drawing — kept for a device with no child on it yet.
    private func drawnChips(_ list: [String], selected: Int) -> some View {
        let font = Swift.min(Swift.max(box.height * 0.085, 13), 22)
        let gap = font * 0.5
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: font * 5.2, maximum: font * 9), spacing: gap)],
                         spacing: gap) {
            ForEach(Array(list.enumerated()), id: \.offset) { i, name in
                Text(name)
                    .font(.system(size: font, weight: .heavy, design: .rounded))
                    .foregroundStyle(i == selected ? AppColor.textOnLight : .white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, font * 0.52)
                    .background {
                        if i == selected {
                            Capsule().fill(AppGradient.gold)
                        } else {
                            Capsule().fill(.white.opacity(0.18))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.34), lineWidth: 1))
                        }
                    }
            }
        }
        .padding(.horizontal, gap)
    }

    /// 💬 The real chat screen with a fixed three-message exchange. In a
    /// preview it opens no listener, marks nothing read and clears no pushes
    /// (`SupportChatView` checks `isInertPreview` before any of that), so the
    /// card costs one local array and no network at all.
    private func chatArt(_ lines: [StoryChatLine]) -> some View {
        PhoneFrame(box: box) {
            NavigationStack {
                SupportChatView(householdID: "whatsnew.preview", mode: .parent)
            }
        }
    }

    /// Every game at once — what the parent actually got, in one look.
    private func tiles(_ list: [String]) -> some View {
        let columns = 4
        let rows = CGFloat((list.count + columns - 1) / columns)
        let gap = Swift.max(7, box.height * 0.035)
        let byWidth = (box.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let byHeight = (box.height - gap * (rows - 1)) / rows
        let side = Swift.max(30, Swift.min(byWidth, byHeight))
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: gap), count: columns),
                         spacing: gap) {
            ForEach(Array(list.enumerated()), id: \.offset) { _, e in
                Text(e)
                    .font(.system(size: side * 0.54))
                    .frame(width: side, height: side)
                    .background(RoundedRectangle(cornerRadius: side * 0.28, style: .continuous).fill(.white.opacity(0.2)))
                    .overlay(RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                        .strokeBorder(.white.opacity(0.32), lineWidth: 1))
            }
        }
    }

    /// A real example instead of an explanation — the parent's cards show the
    /// thing itself: the words a ג׳ child gets, the switch where it really sits.
    private func rowsArt(_ list: [StoryRow]) -> some View {
        let n = CGFloat(Swift.max(list.count, 1))
        let gap = Swift.max(8, box.height * 0.045)
        let rowH = Swift.max(42, (box.height - gap * (n - 1)) / n)
        // A phone keeps the label and its example on ONE line; only a big
        // screen earns the bigger type.
        let font = Swift.min(Swift.max(rowH * 0.32, 13.5), isCompact ? 15 : 26)
        return VStack(spacing: gap) {
            ForEach(list) { row in
                HStack(spacing: font * 0.65) {
                    if case .bullet = row.kind {
                        Text("●").font(.system(size: font * 0.9)).foregroundStyle(GlassInk.good)
                    }
                    Text(row.label)
                        .font(.system(size: font, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    Spacer(minLength: 6)
                    switch row.kind {
                    case .switchOn:
                        fakeSwitch(font * 2.1)
                    case .action(let title):
                        // The real button, drawn — this is where a parent will
                        // look for it, so it has to look like what they'll see.
                        Text(title)
                            .font(.system(size: font * 0.92, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.textOnLight)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .padding(.horizontal, font * 0.8)
                            .padding(.vertical, font * 0.38)
                            .background(Capsule().fill(AppGradient.gold))
                    case .bullet:
                        Text(row.value)
                            .font(.system(size: font, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2).minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, font)
                .frame(height: rowH)
                .glassInset(radius: Swift.min(rowH * 0.32, 22))
            }
        }
        // A label and the thing beside it belong in one glance: left to the
        // full width of an iPad, "כיתה" and "ד׳" end up a hand apart.
        .frame(maxWidth: Swift.min(box.width, DisplayGeometry.readableWidth))
    }

    /// The switch as it looks in the child's page, drawn rather than live —
    /// nothing in a story is tappable except the story itself.
    private func fakeSwitch(_ width: CGFloat) -> some View {
        let h = width * 0.58
        return Capsule()
            .fill(LinearGradient(colors: [GlassInk.good, AppColor.successMint],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: width, height: h)
            .overlay(alignment: .trailing) {
                Circle().fill(.white).frame(width: h - 6, height: h - 6).padding(3)
            }
            .accessibilityHidden(true)
    }

    /// ⭐/💎 for having watched to the end, handed over by the child's own buddy.
    ///
    /// The buddy's band is MEASURED off what the chips leave — a `ZStack` left
    /// to size itself takes the glow's diameter, which on an iPad pushed the
    /// chips straight through the title underneath.
    private func gift(_ who: StoryCharacter, stars: Int, diamonds: Int) -> some View {
        let chip = Swift.min(Swift.max(box.height * 0.075, 16), 34)
        let gap = box.height * 0.05
        let band = Swift.max(box.height - chip * 2.4 - gap, 70)
        return VStack(spacing: gap) {
            ZStack {
                glow(AppColor.gemPurple, size: Swift.min(band, box.width))
                CharacterView(character: character(who))
                    .frame(width: band * 0.86, height: band * 0.86)
                    .float(amplitude: 8)
            }
            .frame(height: band)
            HStack(spacing: chip * 0.55) {
                chipView("⭐", "+\(stars)", font: chip)
                chipView("💎", "+\(diamonds)", font: chip)
            }
        }
    }

    private func chipView(_ emoji: String, _ amount: String, font: CGFloat) -> some View {
        HStack(spacing: font * 0.3) {
            Text(emoji).font(.system(size: font))
            Text(amount)
                .font(.system(size: font, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, font * 0.9).padding(.vertical, font * 0.48)
        .background(Capsule().fill(.white.opacity(0.2)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 1))
    }

    private func glow(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: Swift.max(24, size * 0.2))
            .opacity(0.55)
    }

    /// A hero fills the card it was given — it is the story, not a bullet point.
    private var heroSize: CGFloat {
        Swift.max(Swift.min(box.height * 0.62, box.width * 0.56), 70)
    }
    /// The glow stays inside the card, so it never pushes what is under it.
    private var glowSize: CGFloat {
        Swift.min(heroSize * 1.5, box.height, box.width)
    }
}

// MARK: - 📸 Screenshot host

/// `DEMO_SCREEN=kidstory | parentstory` — the story on its own, held still so
/// it can be captured. `DEMO_GRADE=0` puts the active child in גן, which makes
/// the game miniatures draw their text-free boards; `DEMO_STORY=7` opens on
/// the seventh story instead of the first; `DEMO_LANG` works everywhere.
struct WhatsNewStoryDemo: View {
    let audience: StoryAudience

    private var startAt: Int {
        Int(ProcessInfo.processInfo.environment["DEMO_STORY"] ?? "") ?? 0
    }
    /// `DEMO_LIVE=1` — run the clock, so taps and the segment bar can be
    /// exercised for real instead of frozen for a screenshot.
    private var live: Bool {
        ProcessInfo.processInfo.environment["DEMO_LIVE"] == "1"
    }

    var body: some View {
        WhatsNewStoryView(audience: audience,
                          items: WhatsNewStories.current(for: audience),
                          onFinish: {},
                          startAt: startAt,
                          liveInDemo: live,
                          demoSeconds: ProcessInfo.processInfo.environment["DEMO_SLOW"] == "1" ? 30 : nil)
            .onAppear {
                guard let grade = Int(ProcessInfo.processInfo.environment["DEMO_GRADE"] ?? ""),
                      var p = ProfileStore.shared.active else { return }
                p.grade = grade
                p.gradeSchoolYear = Profile.schoolYear()
                ProfileStore.shared.update(p)
            }
    }
}
