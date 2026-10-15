import SwiftUI

// MARK: - 🎞️ The stories

/// One picture of a story: its drawing (`ChoreArt` key, an emoji where there is
/// none), the words read aloud for it, and its place in the story. Steps with
/// the SAME rank may come in either order — brushing teeth and getting dressed
/// are both right after making the bed — so a child is never told "wrong" for
/// an order that is just as true.
struct SequenceStep: Hashable, Identifiable {
    let art: String
    let emoji: String
    let spoken: String
    let rank: Int
    var id: String { art + spoken }
}

/// A short everyday story the child puts back in order (Sasha, 2026-10-15:
/// "שגרת בוקר", "ארוחה" — "ויזואלי לחלוטין, ללא צורך בקריאה, עם גרירה").
struct SequenceStory: Identifiable {
    let key: String
    /// What the story is — heard, with the instruction, when it opens.
    let spoken: String
    let steps: [SequenceStep]
    var id: String { key }
}

enum SequenceStories {
    static var all: [SequenceStory] { [
        SequenceStory(key: "morning", spoken: tr("בֹּקֶר טוֹב! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), steps: [
            SequenceStep(art: "wakeup", emoji: "⏰", spoken: tr("מִתְעוֹרְרִים"), rank: 0),
            SequenceStep(art: "bed", emoji: "🛏️", spoken: tr("מְסַדְּרִים אֶת הַמִּטָּה"), rank: 1),
            SequenceStep(art: "teeth", emoji: "🦷", spoken: tr("מְצַחְצְחִים שִׁנַּיִם"), rank: 2),
            SequenceStep(art: "dress", emoji: "👚", spoken: tr("מִתְלַבְּשִׁים"), rank: 2),
            SequenceStep(art: "breakfast", emoji: "🥣", spoken: tr("אוֹכְלִים אֲרוּחַת בֹּקֶר"), rank: 3),
            SequenceStep(art: "bag", emoji: "🎒", spoken: tr("לוֹקְחִים תִּיק וְהוֹלְכִים לַגַּן"), rank: 4),
        ]),
        SequenceStory(key: "meal", spoken: tr("אֲרוּחָה! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), steps: [
            SequenceStep(art: "cooking", emoji: "🍳", spoken: tr("מְבַשְּׁלִים"), rank: 0),
            SequenceStep(art: "table", emoji: "🍴", spoken: tr("עוֹרְכִים אֶת הַשֻּׁלְחָן"), rank: 0),
            SequenceStep(art: "plate", emoji: "🍽️", spoken: tr("אוֹכְלִים"), rank: 1),
            SequenceStep(art: "dishes", emoji: "🧽", spoken: tr("שׁוֹטְפִים אֶת הַכֵּלִים"), rank: 2),
            SequenceStep(art: "trash", emoji: "🗑️", spoken: tr("זוֹרְקִים אֶת הַשְּׁאֵרִיּוֹת לַפַּח"), rank: 2),
        ]),
        SequenceStory(key: "plant", spoken: tr("שׁוֹתְלִים פֶּרַח! מָה קוֹרֶה קֹדֶם, וּמָה אַחַר כָּךְ?"), steps: [
            SequenceStep(art: "seed", emoji: "🌰", spoken: tr("שָׂמִים זְרָעִים בָּאֲדָמָה"), rank: 0),
            SequenceStep(art: "plants", emoji: "💧", spoken: tr("מַשְׁקִים"), rank: 1),
            SequenceStep(art: "sprout", emoji: "🌱", spoken: tr("יוֹצֵא נֶבֶט קָטָן"), rank: 2),
            SequenceStep(art: "flower", emoji: "🌸", spoken: tr("פּוֹרֵחַ פֶּרַח"), rank: 3),
        ]),
        SequenceStory(key: "laundry", spoken: tr("כְּבִיסָה! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), steps: [
            SequenceStep(art: "clothes", emoji: "🧺", spoken: tr("שָׂמִים בְּגָדִים בַּסַּל"), rank: 0),
            SequenceStep(art: "washer", emoji: "🫧", spoken: tr("מְכַבְּסִים בַּמְּכוֹנָה"), rank: 1),
            SequenceStep(art: "clothesline", emoji: "👕", spoken: tr("תּוֹלִים לְיִבּוּשׁ"), rank: 2),
            SequenceStep(art: "laundry", emoji: "👚", spoken: tr("מְקַפְּלִים"), rank: 3),
        ]),
        SequenceStory(key: "cake", spoken: tr("אוֹפִים עוּגָה! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), steps: [
            SequenceStep(art: "mixing", emoji: "🥣", spoken: tr("מְעַרְבְּבִים"), rank: 0),
            SequenceStep(art: "oven", emoji: "🔥", spoken: tr("אוֹפִים בַּתַּנּוּר"), rank: 1),
            SequenceStep(art: "cake", emoji: "🎂", spoken: tr("מַדְלִיקִים נֵרוֹת וְחוֹגְגִים"), rank: 2),
        ]),
        SequenceStory(key: "evening", spoken: tr("עֶרֶב! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), steps: [
            SequenceStep(art: "bath", emoji: "🛁", spoken: tr("מִתְרַחֲצִים"), rank: 0),
            SequenceStep(art: "bedtime", emoji: "🌙", spoken: tr("לוֹבְשִׁים פִּיגָ'מָה"), rank: 1),
            SequenceStep(art: "teeth", emoji: "🦷", spoken: tr("מְצַחְצְחִים שִׁנַּיִם"), rank: 1),
            SequenceStep(art: "reading", emoji: "📖", spoken: tr("קוֹרְאִים סִפּוּר"), rank: 2),
            SequenceStep(art: "lights", emoji: "💡", spoken: tr("מְכַבִּים אֶת הָאוֹר וְהוֹלְכִים לִישֹׁן"), rank: 3),
        ]),
    ] }

    /// How many pictures a story shows at this level: 3 · 4 · all of it.
    static func stepCount(for difficulty: Difficulty) -> Int {
        switch difficulty { case .easy: return 3; case .medium: return 4; case .hard: return 6 }
    }

    /// The pictures of one story for this round, in story order. A short story
    /// keeps one picture per rank where it can — "first, then, last" with no
    /// two that could swap — and always keeps the first and the last.
    static func pick(_ story: SequenceStory, count: Int) -> [SequenceStep] {
        let steps = story.steps.sorted { $0.rank < $1.rank }
        guard count < steps.count else { return steps }
        var byRank: [Int: [SequenceStep]] = [:]
        for s in steps { byRank[s.rank, default: []].append(s) }
        let ranks = byRank.keys.sorted()
        var chosen: [SequenceStep] = []
        if ranks.count >= count {
            // Spread over the ranks, first and last included.
            let idx = (0..<count).map { i in Int((Double(i) * Double(ranks.count - 1) / Double(max(1, count - 1))).rounded()) }
            for i in Array(Set(idx)).sorted() { chosen.append(byRank[ranks[i]]!.randomElement()!) }
        }
        if chosen.count < count {
            let rest = steps.filter { !chosen.contains($0) }.shuffled()
            chosen += rest.prefix(count - chosen.count)
        }
        return chosen.sorted { $0.rank < $1.rank }
    }

    /// A round: three different stories.
    static func round(difficulty: Difficulty) -> [(story: SequenceStory, steps: [SequenceStep])] {
        all.shuffled().prefix(3).map { ($0, pick($0, count: stepCount(for: difficulty))) }
    }
}

// MARK: - 🎞️ The game

/// "סַדְּרוּ לְפִי הַסֵּדֶר" — a story's pictures are shuffled at the bottom and
/// an empty frame waits for each above, numbered 1 → 2 → 3 from the left. The child
/// drags a picture into its frame (or taps the picture, then the frame): right
/// → it clicks in and its words are read; too early or too late → it floats
/// back, the frame glows warm for a moment, nothing said but "כִּמְעַט".
/// Three stories a round, no clock. Played by גן with no words on screen, and
/// by א׳–ב׳ the same way — the stories are life, not reading.
struct SequenceGameView: View {
    var topic: Topic? = nil
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc
    @Environment(\.isInertPreview) private var inertPreview

    private enum Phase { case intro, playing, done }
    private struct FramesKey: PreferenceKey {
        static let defaultValue: [Int: CGRect] = [:]
        static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
            value.merge(nextValue()) { $1 }
        }
    }
    private static let space = "sequenceSpace"

    @State private var phase: Phase = .intro
    @State private var round: [(story: SequenceStory, steps: [SequenceStep])] = []
    @State private var storyIndex = 0
    /// Frame index → the picture that sits in it.
    @State private var placed: [Int: SequenceStep] = [:]
    /// The pictures still to place, in the order they lie at the bottom.
    @State private var pool: [SequenceStep] = []
    @State private var selected: SequenceStep?
    @State private var dragging: SequenceStep?
    @State private var drag: CGSize = .zero
    @State private var glow: (slot: Int, right: Bool)?
    @State private var frames: [Int: CGRect] = [:]
    @State private var missed: Set<String> = []
    @State private var placedCount = 0
    @State private var cleanCount = 0
    @State private var streak = 0
    @State private var shownAt = Date()
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?

    private var isCompact: Bool { hsc == .compact }
    private var current: (story: SequenceStory, steps: [SequenceStep])? {
        round.indices.contains(storyIndex) ? round[storyIndex] : nil
    }
    private var total: Int { round.map(\.steps.count).reduce(0, +) }
    private var cue: PreReaderCue { PreReaderCue(spoken: current?.story.spoken ?? PreReaderGames.startCue) }
    /// Frames numbered 1 → 2 → 3 from LEFT to right in every language — numbers
    /// always run left to right (Rani, 2026-10-15).
    private var slotRows: [[Int]] {
        let idx = Array((current?.steps ?? []).indices)
        let rows = idx.count > 4 ? [Array(idx.prefix(3)), Array(idx.dropFirst(3))] : [idx]
        return rows
    }
    private var topicForLedger: Topic { topic ?? .logic }

    var body: some View {
        ZStack {
            MiniGameBackdrop()
            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "🎞️ " + PreReaderChrome.dots(done: placedCount, total: max(total, 1)), surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    PreReaderIntroCard(kind: .sequence, cue: PreReaderCue(spoken: tr("סַדְּרוּ אֶת הַתְּמוּנוֹת לְפִי הַסֵּדֶר: מָה קֹדֶם, וּמָה אַחַר כָּךְ?"))) { start() }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    PreReaderEndCard(
                        title: cleanCount == total ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: tr("\(round.count) סִפּוּרִים בַּסֵּדֶר הַנָּכוֹן"),
                        tally: "🎞️", tallyCount: placedCount, grant: grant, surprise: surprise,
                        againLabel: tr("עוֹד סִבּוּב 🔁"),
                        onAgain: { start() }, onDone: onClose)
                    Spacer()
                }
            }
            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            if (surprise || earn != nil || inertPreview) && phase == .intro { start() }
        }
    }

    // MARK: Playing

    private var playing: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            PreReaderCueCard(cue: cue, compact: isCompact)
                .id(storyIndex)
            Text(PreReaderChrome.streak(streak))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
            Spacer(minLength: 0)
            GeometryReader { g in
                let gap: CGFloat = 10
                // Up to three frames a row: a whole morning (six) is two rows
                // of big pictures rather than one row of stamps.
                let perRow = CGFloat(min(3, max(1, slotRows.first?.count ?? 1)))
                let side = min(isCompact ? 118 : 160, (g.size.width - 12 - gap * (perRow - 1)) / perRow)   // 12: room for the number badge
                let cardSide = min(isCompact ? 104 : 140, (g.size.width - gap * 2) / 3)
                VStack(spacing: isCompact ? 26 : 34) {
                    // The frames, in reading order.
                    VStack(spacing: gap + 6) {
                        ForEach(slotRows.indices, id: \.self) { r in
                            HStack(spacing: gap) {
                                ForEach(slotRows[r], id: \.self) { i in slot(i, side: side) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    // The pictures to place.
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(cardSide), spacing: gap), count: min(3, max(1, pool.count))), spacing: gap) {
                        ForEach(pool) { step in card(step, side: cardSide) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: isCompact ? 470 : 620)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 560 : 760)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(FramesKey.self) { frames = $0 }
        // Laid out left-to-right so a drag follows the finger, and so the
        // numbered frames read 1 → 2 → 3 from the left (see `slotRows`).
        .environment(\.layoutDirection, .leftToRight)
    }

    private func picture(_ step: SequenceStep, side: CGFloat) -> some View {
        Group {
            if let img = ChoreArt.image(key: step.art) { Image(uiImage: img).resizable().scaledToFit() }
            else { Text(step.emoji).font(.system(size: side * 0.6)) }
        }
        .padding(side * 0.08)
        .frame(width: side, height: side)
    }

    private func slot(_ i: Int, side: CGFloat) -> some View {
        let state: MiniGameTileState = glow.map { $0.slot == i ? ($0.right ? .correct : .wrong) : .normal } ?? (placed[i] != nil ? .correct : .normal)
        return ZStack(alignment: .topTrailing) {
            Group {
                if let step = placed[i] {
                    picture(step, side: side).transition(.scale(scale: 0.5).combined(with: .opacity))
                } else {
                    Color.clear.frame(width: side, height: side)
                }
            }
            .miniGameTile(state, tint: AppColor.starGold, radius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(placed[i] == nil ? 0.6 : 0), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .padding(4)
            )
            // Its place in the story — a number a גן child already knows.
            Text("\(i + 1)")
                .font(.system(size: max(12, side * 0.17), weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "3A2700"))
                .frame(width: max(22, side * 0.3), height: max(22, side * 0.3))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                .offset(x: 6, y: -8)
        }
        .scaleEffect(glow?.slot == i ? 1.06 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: placed[i])
        .background(GeometryReader { g in
            Color.clear.preference(key: FramesKey.self, value: [i: g.frame(in: .named(Self.space))])
        })
        .onTapGesture { if let s = selected { tryPlace(s, in: i) } else if let s = placed[i] { SpeechReader.shared.speak(s.spoken) } }
        .accessibilityLabel(placed[i]?.spoken ?? "\(i + 1)")
    }

    private func card(_ step: SequenceStep, side: CGFloat) -> some View {
        let isDragging = dragging == step
        return picture(step, side: side)
            .miniGameTile(selected == step ? .picked : .normal, tint: Color(hex: "48BFE3"), radius: 16)
            .shadow(color: .black.opacity(isDragging ? 0.35 : 0.15), radius: isDragging ? 14 : 6, y: isDragging ? 10 : 4)
            .scaleEffect(isDragging ? 1.1 : 1)
            .offset(isDragging ? drag : .zero)
            .zIndex(isDragging ? 5 : 0)
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
                    .onChanged { v in
                        if dragging != step { dragging = step; SpeechReader.shared.speak(step.spoken) }
                        drag = v.translation
                    }
                    .onEnded { v in
                        if let i = frames.first(where: { $0.value.insetBy(dx: -6, dy: -6).contains(v.location) })?.key {
                            tryPlace(step, in: i)
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { drag = .zero }
                            dragging = nil
                        }
                    }
            )
            .onTapGesture {
                // A tap hears the picture and picks it; a tap on a frame then places it.
                SpeechReader.shared.speak(step.spoken)
                Haptic.light()
                selected = selected == step ? nil : step
            }
            .accessibilityLabel(step.spoken)
    }

    // MARK: Logic

    private func start() {
        // DEMO_LEVEL=hard shows a whole six-picture story (screenshots).
        let level = ProcessInfo.processInfo.environment["DEMO_LEVEL"].flatMap(Difficulty.init(rawValue:))
            ?? MiniGameLevel.difficulty(for: topicForLedger)
        round = SequenceStories.round(difficulty: level)
        storyIndex = 0
        placedCount = 0; cleanCount = 0; streak = 0; grant = nil; missed = []
        openStory()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    private func openStory() {
        guard let cur = current else { return }
        placed = [:]
        pool = cur.steps.shuffled()
        // Never dealt already in order — that would be a free story.
        if pool.map(\.rank) == cur.steps.map(\.rank), pool.count > 1 { pool.swapAt(0, pool.count - 1) }
        selected = nil; dragging = nil; drag = .zero; glow = nil
        shownAt = Date()
        if !inertPreview { SpeechReader.shared.speak(cur.story.spoken) }
    }

    /// The rank this frame wants: the frames read the story's ranks in order.
    private func rankWanted(at i: Int) -> Int? { current?.steps.indices.contains(i) == true ? current!.steps[i].rank : nil }

    private func tryPlace(_ step: SequenceStep, in i: Int) {
        guard phase == .playing, placed[i] == nil, let want = rankWanted(at: i) else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { drag = .zero }
            dragging = nil
            return
        }
        if step.rank == want {
            let first = !missed.contains(step.id)
            if first { cleanCount += 1; streak += 1 }
            placedCount += 1
            MiniGameLedger.record(correct: true, topic: topicForLedger, responseMs: Date().timeIntervalSince(shownAt) * 1000,
                                  streak: streak, earn: earn, surprise: surprise, retry: !first)
            burst += 1
            SoundPlayer.shared.play(.correctSmall)
            Haptic.success()
            SpeechReader.shared.speak(step.spoken)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                placed[i] = step
                pool.removeAll { $0 == step }
                glow = (i, true)
                drag = .zero
            }
            dragging = nil; selected = nil
            shownAt = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { if glow?.slot == i { withAnimation { glow = nil } } }
            if pool.isEmpty { storyDone() }
        } else {
            if !missed.contains(step.id) {
                missed.insert(step.id)
                streak = 0
                MiniGameLedger.record(correct: false, topic: topicForLedger, earn: earn, surprise: surprise)
            }
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            SpeechReader.shared.speak(PreReaderGames.almost)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                drag = .zero
                glow = (i, false)
            }
            dragging = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.2)) { if glow?.slot == i { glow = nil } }
            }
        }
    }

    private func storyDone() {
        confetti += 1
        SoundPlayer.shared.play(.levelUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            guard phase == .playing else { return }
            if storyIndex + 1 < round.count {
                withAnimation(.easeInOut(duration: 0.3)) { storyIndex += 1 }
                openStory()
            } else {
                finish()
            }
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        grant = MiniGameReward.grant(game: "sequence", correct: placedCount, starsPer: 1, diamondsPer: 1,
                                     cap: total, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        AppAnalytics.log("sequence_game_done", ["clean": "\(cleanCount)", "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    SequenceGameView(onClose: {})
}
