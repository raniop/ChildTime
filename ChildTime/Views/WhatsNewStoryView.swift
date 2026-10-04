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

    @Environment(\.horizontalSizeClass) private var hsc
    @Environment(\.layoutDirection) private var direction
    @ObservedObject private var display = DisplayGeometry.shared

    @State private var index = 0
    /// How much of the CURRENT segment is filled, 0…1 — animated linearly for
    /// exactly as long as the story lasts, so the bar IS the clock.
    @State private var fill: CGFloat = 0
    @State private var ticker: Task<Void, Never>?
    /// Art and text arrive with a small rise. Never a `scaleEffect` — it blurs
    /// text for the whole animation, and this screen is mostly text.
    @State private var risen = false
    @State private var finished = false

    private var isCompact: Bool { hsc == .compact }
    private var short: Bool { display.isShort }
    private var isKid: Bool { audience == .child }

    /// The story on screen. `items` can never be empty here (the callers check),
    /// but a defensive placeholder beats a crash on an index.
    private var item: StoryItem? { items.indices.contains(index) ? items[index] : items.first }

    var body: some View {
        ZStack {
            GlassBackdrop()
            // Few and small: a sparkle landing on a word reads as a typo, and
            // this screen is mostly words.
            SparkleField(count: short ? 5 : 7, size: 10)

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
                if let item {
                    if isKid { kidBody(item) } else { parentBody(item) }
                }
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
        .environment(\.layoutDirection, .app)
        .onAppear {
            if startAt > 0, items.indices.contains(startAt) { index = startAt } else { begin() }
        }
        .onDisappear { ticker?.cancel(); SpeechReader.shared.stop() }
        .onChangeCompat(of: index) { _, _ in begin() }
        .gesture(swipe)
    }

    // MARK: - 👧 The child's story: art first, name under it

    @ViewBuilder
    private func kidBody(_ item: StoryItem) -> some View {
        VStack(spacing: short ? 8 : 14) {
            StoryArtView(art: item.art, isCompact: isCompact, short: short)
                .frame(maxWidth: .infinity)
                .frame(height: kidArtHeight)

            Text(item.title)
                .font(.system(size: kidTitleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.55)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)

            Text(item.line)
                .font(.system(size: kidLineSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, short ? 6 : 14)
        .padding(.bottom, short ? 6 : 16)
        .offset(y: risen ? 0 : 16)
        .opacity(risen ? 1 : 0)
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
            StoryArtView(art: item.art, isCompact: isCompact, short: short)
                .frame(maxWidth: .infinity)
                .frame(height: parentStageHeight(item.art))
                .padding(.vertical, short ? 10 : 16)
                .glassPane(radius: 24)
                .padding(.top, short ? 8 : 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, short ? 10 : 18)
        .padding(.bottom, short ? 8 : 16)
        .offset(y: risen ? 0 : 16)
        .opacity(risen ? 1 : 0)
    }

    // MARK: - Chrome

    /// The thin segments children know: one per story, filling in real time.
    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.3))
                        Capsule().fill(AppColor.starGold)
                            .frame(width: g.size.width * segmentFill(i))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 4)
            }
        }
        .frame(height: 4)
    }

    private func segmentFill(_ i: Int) -> CGFloat {
        i < index ? 1 : (i == index ? fill : 0)
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
                roundButton("🔊", label: tr("הַקְשִׁיבוּ שׁוּב")) {
                    if let item { SpeechReader.shared.speak(item.spokenText) }
                }
                roundButton("✕", label: tr("סְגִירָה")) { finish() }
            } else {
                // The version AND the build, in the corner — a parent reporting
                // something should be able to read out exactly which Tofy this is.
                Text(verbatim: "\(tr("טופי")) · \(AppInfo.version) (\(AppInfo.build))")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
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
                Text(isKid ? tr("הַחְלִיקוּ לַבָּא") : tr("מתחלף לבד · אפשר להחליק"))
                Image(systemName: AppSymbol.forwardChevron).font(.system(size: 11, weight: .black))
            }
            .font(.system(size: isCompact ? 13 : 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.78))
        }
    }

    // MARK: - Moving between stories

    /// Leading third → back, the rest → on. In Hebrew the leading edge is the
    /// right one, so "back" is where the story came from — the same way round
    /// as every story a child has already used.
    private var tapZones: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle())
                    .frame(width: g.size.width * 0.3)
                    .onTapGesture { back() }
                Color.clear.contentShape(Rectangle())
                    .frame(maxWidth: .infinity)
                    .onTapGesture { advance() }
            }
        }
        .ignoresSafeArea()
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 28)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let towardsStart = value.translation.width > 0
                let forward = direction == .rightToLeft ? towardsStart : !towardsStart
                forward ? advance() : back()
            }
    }

    private func begin() {
        ticker?.cancel()
        fill = 0
        risen = false
        withAnimation(.easeOut(duration: 0.38)) { risen = true }
        // 📸 A screenshot run holds the story still — the segment is drawn
        // part-filled so the bar still reads as "mid-story".
        guard !AppInfo.isDemoRun else { risen = true; fill = 0.45; return }
        let seconds = item?.seconds ?? 5
        withAnimation(.linear(duration: seconds)) { fill = 1 }
        speakIfPreReader()
        ticker = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            advance()
        }
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
            index += 1
        } else {
            finish()
        }
    }

    private func back() {
        guard !finished, index > 0 else { return }
        Haptic.light()
        index -= 1
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

    private var safeH: CGFloat { display.safeSize.height }
    private var safeW: CGFloat { display.safeSize.width }

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

    /// 👧 Art first and big — on a large screen it takes more than half.
    private var kidArtHeight: CGFloat {
        share(isCompact ? 0.45 : 0.55, min: 170, max: 860)
    }

    /// 👨‍👩‍👧 The stage's height, inside the glass pane's own padding.
    ///
    /// A hero or a grid happily fills whatever it is given. A list of example
    /// ROWS does not — stretched over an iPad's share it becomes three
    /// enormous bands with a line of text floating in each — so the pane hugs
    /// them instead, and a row stays the size of a row.
    private func parentStageHeight(_ art: StoryArt) -> CGFloat {
        let height = share(isCompact ? 0.40 : 0.48, min: 150, max: 780)
        guard case .rows(let list) = art else { return height }
        let n = CGFloat(Swift.max(list.count, 1))
        let tallestRow: CGFloat = isCompact ? 58 : 112
        let gap = Swift.max(8, height * 0.045)
        return Swift.min(height, n * tallestRow + (n - 1) * gap)
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

    /// 🎮 The game's own emoji, and under it the real board it plays on — so
    /// the child recognises the screen before they ever open it. The miniature
    /// draws its גן form by itself for a pre-reader.
    ///
    /// The frame HUGS the board: `MiniGamePreview` draws at `min(w, h × 1.6)`,
    /// so a box in that exact ratio is filled edge to edge instead of being a
    /// large pane of padding around a small board.
    private func gameArt(_ kind: MiniGameKind, topic: Topic) -> some View {
        let gap = box.height * 0.04
        let emojiBand = box.height * 0.32
        let boardH = box.height - emojiBand - gap
        let pad = Swift.max(8, box.height * 0.035)
        let boardW = Swift.min(box.width, (boardH - pad * 2) * 1.6 + pad * 2)
        return VStack(spacing: gap) {
            ZStack {
                glow(AppColor.starGold, size: emojiBand * 1.5)
                Text(kind.emoji)
                    .font(.system(size: emojiBand * 0.92))
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 9)
            }
            .frame(height: emojiBand)

            MiniGamePreview(kind: kind, topic: topic)
                .frame(width: boardW - pad * 2, height: boardH - pad * 2)
                .padding(pad)
                .glassInset(radius: Swift.max(14, box.height * 0.055))
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
                    if row.kind == .bullet {
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

    var body: some View {
        WhatsNewStoryView(audience: audience,
                          items: WhatsNewStories.current(for: audience),
                          onFinish: {},
                          startAt: startAt)
            .onAppear {
                guard let grade = Int(ProcessInfo.processInfo.environment["DEMO_GRADE"] ?? ""),
                      var p = ProfileStore.shared.active else { return }
                p.grade = grade
                p.gradeSchoolYear = Profile.schoolYear()
                ProfileStore.shared.update(p)
            }
    }
}
