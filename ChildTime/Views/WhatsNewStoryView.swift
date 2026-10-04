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
            .frame(maxWidth: 560)
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
            StoryArtView(art: item.art, isKid: true, isCompact: isCompact, short: short)
                .frame(maxWidth: .infinity)
                .frame(height: kidArtHeight)

            Text(item.title)
                .font(.system(size: kidTitleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.55)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)

            Text(item.line)
                .font(.system(size: isCompact ? (short ? 15 : 17) : 20, weight: .bold, design: .rounded))
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
                    .font(.system(size: isCompact ? 13.5 : 15, weight: .black, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
            }
            Text(item.title)
                .font(.system(size: parentTitleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.26), radius: 9, y: 3)

            Text(item.line)
                .font(.system(size: isCompact ? (short ? 14 : 15.5) : 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)

            // The stage runs from under the lead to just above the footer, as
            // the mockup draws it — it is what grows on a tall screen.
            StoryArtView(art: item.art, isKid: false, isCompact: isCompact, short: short)
                .frame(maxWidth: .infinity)
                .frame(height: parentStageHeight)
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

    /// The art is a SHARE of the screen, not a constant — the mockup gives it
    /// a little under half, and that has to hold on a short foldable, a tall
    /// phone and an iPad in either orientation. Clamped so it can never
    /// squeeze the real board out or grow past what the emoji can fill.
    private func share(_ fraction: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        let h = display.safeSize.height
        guard h > 0 else { return lo }
        return Swift.min(Swift.max(h * fraction, lo), hi)
    }

    private var kidArtHeight: CGFloat { share(0.45, min: 170, max: 560) }
    private var parentStageHeight: CGFloat { share(0.40, min: 150, max: 540) }

    private var kidTitleSize: CGFloat {
        isCompact ? (short ? 26 : 32) : 40
    }
    private var parentTitleSize: CGFloat {
        isCompact ? (short ? 23 : 28) : 34
    }
}

// MARK: - The art

/// Everything that can fill the middle of a story. Adding a kind of card is a
/// case here plus a case in `StoryArt` — never a new screen.
private struct StoryArtView: View {
    let art: StoryArt
    let isKid: Bool
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
            glow(AppColor.starGold)
            CharacterView(character: character(who))
                .frame(width: heroSize * 1.6, height: heroSize * 1.6)
                .float(amplitude: 8)
        }
    }

    /// One huge emoji on its own glow — the simplest story there is.
    private func hero(_ emoji: String) -> some View {
        ZStack {
            glow(AppColor.starGold)
            Text(emoji)
                .font(.system(size: heroSize))
                .shadow(color: .black.opacity(0.32), radius: 18, y: 12)
        }
    }

    /// 🎮 The game's own emoji, and under it the real board it plays on — so
    /// the child recognises the screen before they ever open it. The miniature
    /// draws its גן form by itself for a pre-reader.
    private func gameArt(_ kind: MiniGameKind, topic: Topic) -> some View {
        VStack(spacing: short ? 6 : 12) {
            ZStack {
                glow(AppColor.starGold)
                Text(kind.emoji)
                    .font(.system(size: heroSize * 0.78))
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 9)
            }
            .frame(height: heroSize * 0.92)

            MiniGamePreview(kind: kind, topic: topic)
                .frame(maxWidth: 330)
                .frame(maxHeight: short ? 150 : 230)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .glassInset(radius: 18)
        }
    }

    /// Every game at once — what the parent actually got, in one look.
    private func tiles(_ list: [String]) -> some View {
        let side: CGFloat = isCompact ? (short ? 36 : 44) : 54
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: 9), count: 4), spacing: 9) {
            ForEach(Array(list.enumerated()), id: \.offset) { _, e in
                Text(e)
                    .font(.system(size: side * 0.52))
                    .frame(width: side, height: side)
                    .background(RoundedRectangle(cornerRadius: side * 0.28, style: .continuous).fill(.white.opacity(0.2)))
                    .overlay(RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                        .strokeBorder(.white.opacity(0.32), lineWidth: 1))
            }
        }
    }

    /// A real example instead of an explanation — the parent's cards show the
    /// thing itself: the words a ג׳ child gets, the switch where it really sits.
    private func rowsArt(_ rows: [StoryRow]) -> some View {
        VStack(spacing: 9) {
            ForEach(rows) { row in
                HStack(spacing: 9) {
                    if row.kind == .bullet {
                        Text("●").font(.system(size: 13)).foregroundStyle(GlassInk.good)
                    }
                    Text(row.label)
                        .font(.system(size: isCompact ? 13.5 : 15.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    Spacer(minLength: 6)
                    switch row.kind {
                    case .switchOn:
                        fakeSwitch
                    case .bullet:
                        Text(row.value)
                            .font(.system(size: isCompact ? 13.5 : 15.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2).minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassInset(radius: 14)
            }
        }
        .padding(.horizontal, 18)
    }

    /// The switch as it looks in the child's page, drawn rather than live —
    /// nothing in a story is tappable except the story itself.
    private var fakeSwitch: some View {
        Capsule()
            .fill(LinearGradient(colors: [GlassInk.good, AppColor.successMint],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 46, height: 27)
            .overlay(alignment: .trailing) {
                Circle().fill(.white).frame(width: 21, height: 21).padding(3)
            }
            .accessibilityHidden(true)
    }

    /// ⭐/💎 for having watched to the end, handed over by the child's own buddy.
    private func gift(_ who: StoryCharacter, stars: Int, diamonds: Int) -> some View {
        VStack(spacing: short ? 8 : 14) {
            ZStack {
                glow(AppColor.gemPurple)
                CharacterView(character: character(who))
                    .frame(width: heroSize * 1.45, height: heroSize * 1.45)
                    .float(amplitude: 8)
            }
            HStack(spacing: 9) {
                chip("⭐", "+\(stars)")
                chip("💎", "+\(diamonds)")
            }
        }
    }

    private func chip(_ emoji: String, _ amount: String) -> some View {
        HStack(spacing: 5) {
            Text(emoji).font(.system(size: 16))
            Text(amount)
                .font(.system(size: isCompact ? 16 : 18, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 15).padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.2)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 1))
    }

    private func glow(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: heroSize * 1.5, height: heroSize * 1.5)
            .blur(radius: 38)
            .opacity(0.55)
    }

    private var heroSize: CGFloat {
        if !isCompact { return short ? 130 : 165 }
        return short ? 96 : 132
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
