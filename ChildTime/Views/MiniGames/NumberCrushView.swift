import SwiftUI
import Combine

/// 🧱 "מְפַצְּחִים" — a target at the top ("יַעַד: 10") and a grid of colourful
/// number blocks. Tap blocks whose sum (product in a × round; ½ ⅓ ¼ or 0.1s in
/// ה׳+) makes the target exactly: picked blocks get a gold edge, a hit bursts
/// them and new blocks drop in from above. Going past the target only lets go
/// of the selection with a small shake. The board always holds at least one
/// way to the target. 60 seconds (45 in a surprise round).
///
/// 👶 גן plays a different game on the same screen: pure COUNTING, with no
/// numeral and no addition. A basket at the top wants four flowers; six cards
/// hold one to five each; the child taps the one that has exactly four and its
/// flowers fly into the basket. Five baskets filled and the round is over.
///
/// It got there the hard way. The first גן version asked the child to COMBINE
/// cards until they added up to the basket, and Rani said "זה לא מובן" twice —
/// because composing 3 + 1 is a first-grade skill, not a גן one. A five-year-old
/// counts to five. The combining board is untouched from א׳ upward.
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser every hit
/// earns screen time like a regular answer (paced — see MiniGameEarnSession).
struct NumberCrushView: View {
    var topic: Topic? = nil
    /// ⚡ Launched by the runner's surprise round: no intro, one round, ×2.
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc
    /// 🖼 A miniature on a What's-New story card: show the real screen,
    /// but do not play it — no round is scored and no clock runs.
    @Environment(\.isInertPreview) private var inertPreview

    private struct Block: Identifiable, Equatable {
        let id = UUID()
        let value: Int
        let color: Color
    }

    private enum Phase { case intro, playing, done }

    /// The balloons' palette — the app's own accents.
    private static let palette: [Color] = [Color(hex: "FF6B9D"), Color(hex: "06D6A0"), Color(hex: "FFB84D"),
                                           Color(hex: "48BFE3"), Color(hex: "9B5DE5")]

    @State private var phase: Phase = .intro
    @State private var rules = CrushRules(mode: .sum, target: 10, values: Array(1...9))
    /// `columns[c][0]` is the BOTTOM block of column c.
    @State private var columns: [[Block]] = []
    @State private var picked: [UUID] = []
    @State private var bursting: Set<UUID> = []
    @State private var hits = 0
    @State private var startedAt = Date()
    @State private var now = Date()
    @State private var pickStartedAt = Date()
    @State private var shake: CGFloat = 0
    @State private var targetPop = false
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?
    /// 👶 גן: the basket, its six cards and the spoken rule.
    @State private var collect: PreReaderGames.Collect?
    /// The card the child got right — it turns mint and swells for a moment
    /// before the next goal comes.
    @State private var preSolved: Int?
    /// The card that was just tapped and isn't the one — it wobbles and stays.
    @State private var preWrong: Int?
    /// Already counted a miss this basket (one answer per basket in reports).
    @State private var preMissed = false
    /// Between baskets: taps do nothing while the flowers settle.
    @State private var preSettling = false
    /// 👶 Dealt before the intro card, so the card shows the row to collect;
    /// ▶️ then consumes it.
    @State private var preDealt = false

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var isCompact: Bool { hsc == .compact }
    /// The child's level in math (adaptive), not just the class.
    private var grade: Int { MiniGameLevel.grade(for: .math) }
    /// 👶 A pre-reader (גן): objects instead of numerals, and no clock.
    /// One definition for all five games — see `PreReaderGames`.
    /// 🖼 A story card showing the גן form to a PARENT has no גן child
    /// active, so it says which form it wants. Everywhere else this is nil
    /// and the answer is simply "is the child using the app a pre-reader".
    var forcePreReader: Bool? = nil

    private var preReader: Bool {
        if let forcePreReader { return forcePreReader }
        _ = profiles.active      // redraw when the active child changes
        return PreReaderGames.activeChildIsPreReader
    }
    /// Hits count in the world they're played in when it is a numbers world.
    private var recordTopic: Topic {
        // 👶 A גן round is counting, whatever world it was opened from.
        if PreReaderGames.activeChildIsPreReader { return .math }
        if let topic, [.math, .money, .logic, .gifted].contains(topic) { return topic }
        return .math
    }
    private var roundSeconds: TimeInterval { TimeInterval(MiniGameKind.crush.seconds(surprise: surprise)) }
    private var remaining: TimeInterval { max(0, roundSeconds - now.timeIntervalSince(startedAt)) }
    /// 4×3 on a phone (and the foldable), 5×4 on an iPad. (גן doesn't use
    /// this board at all — see `preReaderCards`.)
    private var colCount: Int { isCompact || display.isShort ? 4 : 5 }
    private var rowCount: Int { isCompact || display.isShort ? 3 : 4 }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: preReader
                                      ? (collect?.emoji ?? "🧱") + " "
                                        + PreReaderChrome.dots(done: hits, total: PreReaderGames.countingHits)
                                      : "🧱 \(hits)",
                                      surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    if preReader {
                        PreReaderIntroCard(kind: .crush,
                                           cue: collect?.cue ?? PreReaderCue(spoken: PreReaderGames.startCue)) { start() }
                    } else {
                        MiniGameIntroCard(kind: .crush) { start() }
                    }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    if preReader {
                        PreReaderEndCard(
                            title: hits >= PreReaderGames.countingHits ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                            detail: preReaderSummary,
                            tally: collect?.emoji ?? "🧱", tallyCount: hits, grant: grant,
                            surprise: surprise,
                            againLabel: tr("עוֹד סִבּוּב 🔁"),
                            onAgain: { start() }, onDone: onClose)
                    } else {
                        MiniGameEndCard(
                            title: hits >= 10 ? tr("וָואוּ, מְצֻיָּן! 🏆") : tr("כָּל הַכָּבוֹד! 🎉"),
                            detail: summaryLine,
                            grant: grant,
                            surprise: surprise,
                            againLabel: tr("עוֹד סִבּוּב 🔁"),
                            onAgain: { start() },
                            onDone: onClose)
                    }
                    Spacer()
                }
            }

            StarBurst(count: 12, color: AppColor.starGold, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            if preReader, !preDealt { dealPreReader() }
            if (surprise || earn != nil || inertPreview) && phase == .intro { start() }
        }
        .onReceive(ticker) { t in
            guard !inertPreview else { return }
            guard phase == .playing else { return }
            now = t
            // 👶 גן has no clock on screen: the round ends after five
            // collections. The long backstop only keeps a child who never
            // finds a pair from being left on the board forever — and it ends
            // the same celebrating way, with whatever they did collect.
            if preReader {
                if t.timeIntervalSince(startedAt) > 180 { finish() }
            } else if remaining <= 0 {
                finish()
            }
        }
    }

    private var summaryLine: String {
        switch hits {
        case 0:  return surprise ? tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") : tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
        case 1:  return tr("פִּצַּחְתֶּם אֶת הַיַּעַד פַּעַם אַחַת!")
        default: return tr("פִּצַּחְתֶּם אֶת הַיַּעַד \(hits) פְּעָמִים!")
        }
    }

    /// 👶 What a גן round produced, in words: cards matched, not targets hit.
    private var preReaderSummary: String {
        switch hits {
        case 0:  return tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
        case 1:  return tr("מָצָאתֶם אֶת הַכַּרְטִיס הַנָּכוֹן פַּעַם אַחַת!")
        default: return tr("מָצָאתֶם אֶת הַכַּרְטִיס הַנָּכוֹן \(hits) פְּעָמִים!")
        }
    }

    // MARK: - Playing

    private var pickedValues: [Int] {
        picked.compactMap { id in columns.joined().first { $0.id == id }?.value }
    }

    @ViewBuilder
    private var playing: some View {
        if preReader, let collect {
            // 👶 גן plays a different layout entirely: goal, arrow, tray, board,
            // with no gap between them. See `preReaderBoard`.
            preReaderBoard(collect)
        } else {
            readerBoard
        }
    }

    /// 👶 The גן screen: one basket that wants N, six cards that hold one to
    /// five each, and exactly one of them right. Tap it and its objects fill
    /// the basket. No adding up, no running total, nothing to keep in mind.
    ///
    /// The basket and the cards are one act, so they sit together with no gap:
    /// goal, the sentence, the arrow, then the cards straight underneath.
    private func preReaderBoard(_ collect: PreReaderGames.Collect) -> some View {
        // 📐 On a phone the cards are height-bound and fill what is left. On an
        // iPad they are capped, so the leftover height is real: the question,
        // the goal and the cards sit together as ONE centred group rather than
        // clinging to the top of a very tall screen.
        let capped = !isCompact && !display.isShort
        let rows = Int(ceil(Double(PreReaderGames.countingCards) / Double(preReaderCardColumns)))
        let cardsHeight = preReaderCardMaxSide * CGFloat(rows) + 14 * CGFloat(rows - 1)
        return VStack(spacing: display.isShort ? AppSpacing.xs : AppSpacing.sm) {
            if capped { Spacer(minLength: 0) }
            preReaderGoal(collect)
            preReaderCards(collect)
                .frame(maxHeight: capped ? cardsHeight : .infinity)
            if capped { Spacer(minLength: 0) }
        }
        .frame(maxWidth: isCompact ? 620 : 700)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    /// What to look for, drawn as the THING ITSELF: three flowers in a gold
    /// frame, the same picture and the same size they have on the cards below.
    ///
    /// It took three tries to get here. A 🎯 beside the row read as a fourth
    /// item; a 🧺 at the end of it did the same ("הסל מבלבל!"); and dashed
    /// placeholder circles are an abstraction a five-year-old has to decode
    /// before the game even starts. Showing the real objects makes the round
    /// pure matching — "find the card that looks like this" — which needs no
    /// reading, no counting-out-loud and no explaining. Nothing else goes in
    /// the frame, because anything else in it gets counted too.
    private func preReaderGoal(_ collect: PreReaderGames.Collect) -> some View {
        VStack(spacing: display.isShort ? 7 : 12) {
            // 1️⃣ The question first, centred, and the biggest text here —
            //    it IS the question, so it has to look like one. The 🔊 sits
            //    beside it instead of floating at the opposite edge.
            HStack(spacing: isCompact ? 9 : 13) {
                Text(collect.cue.spoken)
                    .font(.system(size: display.isShort ? 16 : (isCompact ? 19 : 26),
                                  weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3).minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                PreReaderSpeakButton(spoken: collect.cue.spoken,
                                     side: display.isShort ? 40 : (isCompact ? 46 : 58))
            }
            .frame(maxWidth: .infinity)

            // 2️⃣ …and under it, centred, what to look for.
            HStack(spacing: isCompact ? 3 : 6) {
                ForEach(Array(0..<max(1, collect.target)), id: \.self) { _ in
                    Text(collect.emoji).font(.system(size: goalGlyph(collect.target)))
                }
            }
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.vertical, display.isShort ? 7 : 12)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColor.starGold.opacity(0.20)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppColor.starGold.opacity(0.9), lineWidth: 2.5))
            .glow(AppColor.starGold, radius: 10)
            .scaleEffect(targetPop ? 1.08 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: targetPop)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12).padding(.vertical, display.isShort ? 9 : 14)
        .glassPane(radius: 22)
    }

    /// Five objects in the frame still have to fit a phone's width beside the
    /// gold border, so the more there are the smaller each one is — but the
    /// goal is the content, so it is drawn larger than any single card's
    /// object, not smaller.
    private func goalGlyph(_ count: Int) -> CGFloat {
        let base: CGFloat = display.isShort ? 40 : (isCompact ? 62 : 92)
        switch count {
        case ...2: return base
        case 3:    return base * 0.92
        case 4:    return base * 0.84
        default:   return base * 0.76
        }
    }

    /// Six cards, each holding one to five objects. One tap, one answer.
    ///
    /// On a phone upright they go 2 across and 3 down: the leftover height was
    /// dead space either way, and spent on the cards it makes every one of them
    /// half as wide again — which is what a five-year-old's finger wants. On a
    /// short screen (a phone on its side) the height is what runs out, so they
    /// go 3 across and 2 down; kept at 2 × 3 there, six cards shrank to a
    /// narrow column in the middle. On an iPad they go 3 across too — at 2 the
    /// grid stretched a two-apple card to 450pt, which is a poster, not a card.
    private var preReaderCardColumns: Int { (display.isShort || !isCompact) ? 3 : 2 }

    /// A card is sized to a hand, not to the screen. Past this it stops being
    /// easier to hit and just starts crowding out the question above it.
    private var preReaderCardMaxSide: CGFloat { isCompact ? 190 : 210 }

    private func preReaderCards(_ collect: PreReaderGames.Collect) -> some View {
        GeometryReader { geo in
            let cols = preReaderCardColumns
            let rows = Int(ceil(Double(PreReaderGames.countingCards) / Double(cols)))
            let gap: CGFloat = isCompact ? 10 : 14
            let w = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let h = (geo.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            let side = max(60, min(min(w, h), preReaderCardMaxSide))
            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { col in
                            let i = row * cols + col
                            if i < collect.cards.count {
                                preReaderCard(collect, index: i, side: side)
                            }
                        }
                    }
                }
            }
            .frame(width: side * CGFloat(cols) + gap * CGFloat(cols - 1),
                   height: side * CGFloat(rows) + gap * CGFloat(rows - 1))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func preReaderCard(_ collect: PreReaderGames.Collect, index: Int, side: CGFloat) -> some View {
        let count = collect.cards[index]
        let right = preSolved == index
        let wrong = preWrong == index
        return Button { preReaderTap(collect, index: index) } label: {
            Text(String(repeating: collect.emoji, count: max(1, count)))
                .font(.system(size: side * cardGlyphScale(count)))
                .lineLimit(2).minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
                .frame(width: side, height: side)
                .miniGameTile(right ? .correct : (wrong ? .wrong : .normal),
                              tint: Self.palette[index % Self.palette.count], radius: side * 0.22)
                .scaleEffect(right ? 1.08 : 1)
                .modifier(MiniGameShake(animatableData: wrong ? shake : 0))
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: right)
        }
        .buttonStyle(.juicy)
        .disabled(preSettling)
    }

    /// One object fills the card; five of them wrap into two rows.
    private func cardGlyphScale(_ count: Int) -> CGFloat {
        switch count {
        case ...1: return 0.52
        case 2:    return 0.36
        case 3:    return 0.28
        case 4:    return 0.26
        default:   return 0.24
        }
    }

    /// A tap on one card. Right → its objects fill the basket and the next one
    /// comes. Not right → that card wobbles and stays; the child tries again.
    /// Nothing is ever lost and nothing is ever called a mistake.
    private func preReaderTap(_ collect: PreReaderGames.Collect, index: Int) {
        guard phase == .playing, !preSettling else { return }
        if collect.cards[index] == collect.target {
            preSettling = true
            preWrong = nil
            hits += 1
            burst += 1
            SoundPlayer.shared.play(hits % 5 == 0 ? .streakUp : .correctBig)
            Haptic.success()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                preSolved = index
                targetPop = true
            }
            MiniGameLedger.record(correct: true, topic: recordTopic,
                                  responseMs: Date().timeIntervalSince(pickStartedAt) * 1000,
                                  streak: hits, earn: earn, surprise: surprise)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                guard phase == .playing else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { targetPop = false }
                if hits >= PreReaderGames.countingHits {
                    finish()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { dealPreReader() }
                    preDealt = false
                    preSettling = false
                }
            }
        } else {
            if !preMissed {
                preMissed = true
                MiniGameLedger.record(correct: false, topic: recordTopic, earn: earn, surprise: surprise)
            }
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            SpeechReader.shared.speak(PreReaderGames.almost)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { preWrong = index }
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.2)) { if preWrong == index { preWrong = nil } }
            }
        }
    }

    private var readerBoard: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            // The target, in the runner's question card.
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(tr("יַעַד:"))
                        .font(.system(size: isCompact ? 24 : 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(rules.targetText)
                        .font(.system(size: isCompact ? 44 : 56, weight: .black, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                        .glow(AppColor.starGold, radius: 10)
                        .scaleEffect(targetPop ? 1.25 : 1)
                    if rules.mode == .product {
                        MiniGameChip {
                            Text(tr("כֶּפֶל ×"))
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                Text(pickedValues.isEmpty ? selectionLine : MiniGameText.ltr(selectionLine))
                    .font(.system(size: isCompact ? 17 : 21, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .mathLTR(!pickedValues.isEmpty)
                MiniGameTimerBar(remaining: remaining, total: roundSeconds)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .glassPane(radius: 22)
            .modifier(MiniGameShake(animatableData: shake))

            Spacer(minLength: 0)
            grid
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 620 : 760)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    /// "3 + 4 = 7" while picking; the rule when nothing is picked.
    private var selectionLine: String {
        let vals = pickedValues
        guard !vals.isEmpty else {
            return rules.mode == .product ? tr("בַּחֲרוּ קֻבִּיּוֹת שֶׁהַמַּכְפֵּלָה שֶׁלָּהֶן מַגִּיעָה לַיַּעַד")
                                          : tr("בַּחֲרוּ קֻבִּיּוֹת שֶׁהַסְּכוּם שֶׁלָּהֶן מַגִּיעַ לַיַּעַד")
        }
        let total = rules.total(vals)
        let totalText: String
        switch rules.mode {
        case .sum, .product: totalText = "\(total)"
        case .fraction:      totalText = total == 12 ? "1" : rules.display(total)
        case .decimal:       totalText = total >= 10 ? "1" : "0.\(total)"
        }
        return rules.expression(vals) + " = " + totalText
    }

    private var grid: some View {
        GeometryReader { geo in
            let gap: CGFloat = isCompact ? 10 : 14
            let w = (geo.size.width - gap * CGFloat(colCount - 1)) / CGFloat(colCount)
            let h = min(w, (geo.size.height - gap * CGFloat(rowCount - 1)) / CGFloat(rowCount))
            let side = min(w, h)
            let boardW = side * CGFloat(colCount) + gap * CGFloat(colCount - 1)
            let boardH = side * CGFloat(rowCount) + gap * CGFloat(rowCount - 1)
            ZStack(alignment: .topLeading) {
                ForEach(Array(columns.enumerated()), id: \.offset) { c, column in
                    ForEach(Array(column.enumerated()), id: \.element.id) { r, block in
                        blockView(block, side: side)
                            .position(x: CGFloat(c) * (side + gap) + side / 2,
                                      y: CGFloat(rowCount - 1 - r) * (side + gap) + side / 2)
                            .transition(.asymmetric(insertion: .offset(y: -boardH).combined(with: .opacity),
                                                    removal: .scale(scale: 1.4).combined(with: .opacity)))
                    }
                }
            }
            .frame(width: boardW, height: boardH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: isCompact ? 330 : 640)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func blockView(_ b: Block, side: CGFloat) -> some View {
        let isPicked = picked.contains(b.id)
        let isBursting = bursting.contains(b.id)
        return Button { tap(b) } label: {
            Text(MiniGameText.ltr(rules.display(b.value)))
                .font(.system(size: side * (rules.mode == .decimal ? 0.32 : 0.42), weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: side, height: side)
                .miniGameTile(isBursting ? .correct : (isPicked ? .picked : .normal), tint: b.color, radius: side * 0.24)
                .background(
                    RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                        .fill(b.color.opacity(0.35))
                )
                .scaleEffect(isBursting ? 1.15 : (isPicked ? 1.06 : 1))
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPicked)
        }
        .buttonStyle(.juicy)
        .disabled(isBursting)
    }

    // MARK: - Logic

    private func start() {
        if preReader {
            // 👶 גן never builds the combining board — its round is six cards
            // and one tap. See `preReaderBoard`.
            if !preDealt { dealPreReader() }
            preDealt = false
            columns = []
            picked = []; bursting = []; hits = 0; grant = nil
            preSettling = false
            startedAt = Date(); now = Date(); pickStartedAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
            return
        }
        collect = nil
        rules = CrushBoards.rules(grade: grade, topic: topic)
        var cols: [[Block]] = (0..<colCount).map { _ in (0..<rowCount).map { _ in newBlock() } }
        cols = ensureSolvable(cols, fresh: Set(cols.joined().map(\.id)))
        columns = cols
        picked = []; bursting = []; hits = 0; grant = nil
        startedAt = Date(); now = Date(); pickStartedAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    /// 👶 One גן basket: the object, how many it wants, the six cards and the
    /// rule — spoken when the cue card appears, and printed beside the 🔊.
    private func dealPreReader() {
        collect = PreReaderGames.collecting()
        preSolved = nil
        preWrong = nil
        preMissed = false
        pickStartedAt = Date()
        preDealt = true
    }

    private func newBlock(_ value: Int? = nil) -> Block {
        Block(value: value ?? CrushBoards.randomValue(rules), color: Self.palette.randomElement()!)
    }

    private func tap(_ b: Block) {
        guard phase == .playing, bursting.isEmpty else { return }
        if let i = picked.firstIndex(of: b.id) {
            Haptic.selection()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { _ = picked.remove(at: i) }
            return
        }
        if picked.isEmpty { pickStartedAt = Date() }
        Haptic.light()
        SoundPlayer.shared.play(.uiTap)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { picked.append(b.id) }
        let vals = pickedValues
        if rules.hits(vals) {
            crush()
        } else if !rules.canStillReach(vals) {
            // Past the target: the selection lets go with a small shake — no
            // word about it, no answer recorded; the child simply tries again.
            SoundPlayer.shared.play(.wrongSoft)
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { picked = [] }
            }
        }
    }

    private func crush() {
        let ids = Set(picked)
        hits += 1
        bursting = ids
        burst += 1
        SoundPlayer.shared.play(hits % 5 == 0 ? .streakUp : .correctBig)
        Haptic.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { targetPop = true }
        // One answer per hit in the parent's reports.
        MiniGameLedger.record(correct: true, topic: recordTopic,
                              responseMs: Date().timeIntervalSince(pickStartedAt) * 1000,
                              streak: hits, earn: earn, surprise: surprise)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard phase == .playing else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { targetPop = false }
            // Remove the burst blocks — the rest fall — and drop new ones in on top.
            var cols = columns.map { $0.filter { !ids.contains($0.id) } }
            var fresh = Set<UUID>()
            for c in cols.indices {
                while cols[c].count < rowCount {
                    let b = newBlock()
                    fresh.insert(b.id)
                    cols[c].append(b)
                }
            }
            cols = ensureSolvable(cols, fresh: fresh)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                columns = cols
                picked = []
                bursting = []
            }
        }
    }

    /// The board must always hold a way to the target. Re-roll the new blocks a
    /// few times; failing that, turn one block into the partner of another.
    private func ensureSolvable(_ cols: [[Block]], fresh: Set<UUID>) -> [[Block]] {
        var cols = cols
        var freshIDs = fresh
        func solvable() -> Bool { CrushBoards.isSolvable(cols.joined().map(\.value), rules: rules) }
        var tries = 0
        while !solvable(), tries < 8, !freshIDs.isEmpty {
            tries += 1
            for c in cols.indices {
                for r in cols[c].indices where freshIDs.contains(cols[c][r].id) {
                    let b = Block(value: CrushBoards.randomValue(rules), color: cols[c][r].color)
                    freshIDs.remove(cols[c][r].id)
                    freshIDs.insert(b.id)
                    cols[c][r] = b
                }
            }
        }
        if solvable() { return cols }
        // Plant a guaranteed pair: a block that has a partner value, and a
        // different block — a new one if possible — turned into that partner.
        let positions = cols.indices.flatMap { c in cols[c].indices.map { (c: c, r: $0) } }.shuffled()
        for p in positions {
            guard let partner = rules.complement(of: cols[p.c][p.r].value) else { continue }
            let others = positions.filter { $0 != p }
            guard let q = others.first(where: { freshIDs.contains(cols[$0.c][$0.r].id) }) ?? others.first else { continue }
            cols[q.c][q.r] = Block(value: partner, color: cols[q.c][q.r].color)
            return cols
        }
        // Nothing on the board has a partner (a × round full of odd blocks):
        // rebuild two blocks from scratch.
        if positions.count >= 2, let v = rules.values.shuffled().first(where: { rules.complement(of: $0) != nil }),
           let partner = rules.complement(of: v) {
            let p = positions[0], q = positions[1]
            cols[p.c][p.r] = Block(value: v, color: cols[p.c][p.r].color)
            cols[q.c][q.r] = Block(value: partner, color: cols[q.c][q.r].color)
        }
        return cols
    }

    private func finish() {
        guard phase == .playing else { return }
        picked = []
        grant = MiniGameReward.grant(game: "crush", correct: hits, starsPer: 2, diamondsPer: 1,
                                     cap: preReader ? PreReaderGames.countingHits : (surprise ? 8 : 10),
                                     surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        if hits > 0 { confetti += 1 }
        AppAnalytics.log("number_crush_done", ["hits": "\(hits)", "mode": "\(rules.mode)",
                                               "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    NumberCrushView(onClose: {})
}
