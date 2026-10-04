import SwiftUI

/// 🔗 "חַבְּרוּ אֶת הַזּוּגוֹת" — five pairs in two columns, both shuffled. Tap
/// one on each side: a right pair turns mint and locks, a wrong one gives a
/// short gentle shake in the answers' soft warm and lets go. The board follows
/// the world it came from: country ↔ capital (🌍), word ↔ English (🇬🇧),
/// exercise ↔ result (🧮), or short question ↔ answer from the world's bank.
///
/// 👶 גן plays it with no words at all: four PICTURE pairs a five-year-old can
/// reason about — 🦴 and 🐶, 🥚 and 🐣, ☂️ and 🌧️ — on tiles a size up, with
/// "חַבְּרוּ כָּל תְּמוּנָה לַתְּמוּנָה שֶׁהוֹלֶכֶת אִתָּהּ" read aloud instead of printed.
/// See `PreReaderGames`.
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser each pair
/// matched first time earns screen time like a regular answer.
struct PairsGameView: View {
    var topic: Topic? = nil
    /// ⚡ Launched by the runner's surprise round: no intro, one board, ×2.
    var surprise: Bool = false
    /// From a world's chooser: each pair matched first time earns like a question.
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    /// The most pairs a board ever shows (two columns of six).
    static let pairCount = 6

    private struct Card: Identifiable { let pair: Int; let text: String; var id: Int { pair } }
    private enum Side { case left, right }

    @State private var started = false
    @State private var source: MatchPairsSource = .math
    @State private var lefts: [Card] = []
    @State private var rights: [Card] = []
    @State private var matched: Set<Int> = []
    @State private var pickedLeft: Int?
    @State private var pickedRight: Int?
    /// Pairs the child tried wrongly before matching — recorded as a miss once.
    @State private var missed: Set<Int> = []
    @State private var wrongLeft: Int?
    @State private var wrongRight: Int?
    @State private var shake: CGFloat = 0
    @State private var done = false
    @State private var grant: MiniGameReward.Grant?
    @State private var burst = 0
    @State private var confetti = 0
    @State private var boardShownAt = Date()
    /// 👶 גן: the spoken rule (nil for a reader).
    @State private var cue: PreReaderCue?

    private var isCompact: Bool { hsc == .compact }
    private var grade: Int { max(1, profiles.active?.effectiveGrade ?? 2) }
    /// 👶 A pre-reader (גן): pictures only, four pairs, bigger tiles.
    private var preReader: Bool { PreReaderGames.isPreReader(profiles.active?.effectiveGrade ?? 1) }
    /// 🎚️ Five pairs up to ד׳, six from ה׳ — a sixth row needs the height,
    /// so a short screen keeps five whatever the grade. 👶 גן: four.
    private var pairCount: Int {
        if preReader { return PreReaderGames.pairCount }
        return MiniGameBand.of(grade) >= .upper && !display.isShort ? Self.pairCount : 5
    }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: preReader
                                      ? "🔗 " + PreReaderChrome.dots(done: matched.count, total: pairCount)
                                      : "🔗 \(matched.count)/\(pairCount)",
                                      surprise: surprise)
                }
                if !started {
                    Spacer()
                    if preReader {
                        PreReaderIntroCard(kind: .pairs, cue: cue ?? PreReaderCue(spoken: PreReaderGames.startCue)) { deal() }
                    } else {
                        MiniGameIntroCard(kind: .pairs) { deal() }
                    }
                    Spacer()
                } else if done {
                    Spacer()
                    if preReader {
                        PreReaderEndCard(
                            title: missed.isEmpty ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                            detail: tr("כָּל הַזּוּגוֹת מְחֻבָּרִים!"),
                            tally: "🔗", tallyCount: matched.count, grant: grant, surprise: surprise,
                            againLabel: tr("עוֹד לוּחַ 🔁"),
                            onAgain: { deal() }, onDone: onClose)
                    } else {
                        MiniGameEndCard(
                            title: missed.isEmpty ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                            detail: tr("כָּל הַזּוּגוֹת מְחֻבָּרִים!"),
                            grant: grant,
                            surprise: surprise,
                            againLabel: tr("עוֹד לוּחַ 🔁"),
                            onAgain: { deal() },
                            onDone: onClose)
                    }
                    Spacer()
                } else {
                    board
                }
            }

            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if (surprise || earn != nil) && !started { deal() } }
    }

    private var subtitle: String {
        switch source {
        case .capitals:     return tr("כָּל מְדִינָה וְעִיר הַבִּירָה שֶׁלָּהּ")
        case .englishWords:
            return LanguageStore.shared.current == .en
                ? tr("כָּל תְּמוּנָה וְהַמִּלָּה שֶׁלָּהּ")
                : tr("כָּל מִלָּה וְהַתַּרְגּוּם שֶׁלָּהּ בְּאַנְגְּלִית")
        case .math:         return tr("כָּל תַּרְגִּיל וְהַתּוֹצָאָה שֶׁלּוֹ")
        case .bank:         return tr("כָּל שְׁאֵלָה וְהַתְּשׁוּבָה שֶׁלָּהּ")
        }
    }

    // MARK: - Board

    /// An iPad: the title card and the board sit together in the middle of the
    /// glass, tiles a size up — top-aligned they left the bottom half empty
    /// (Rani). Whatever doesn't fit (an iPad in landscape) scrolls instead.
    @ViewBuilder
    private var board: some View {
        if roomy {
            ViewThatFits(in: .vertical) {
                VStack(spacing: AppSpacing.md) {
                    Spacer(minLength: 0)
                    boardTitle
                    columns
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {
                        boardTitle
                        columns
                    }
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
            }
        } else {
            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                boardTitle
                ScrollView(showsIndicators: false) { columns }
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
    }

    /// The runner's question card, as the board's title.
    @ViewBuilder
    private var boardTitle: some View {
        if preReader, let cue {
            VStack(spacing: 10) {
                PreReaderCueCard(cue: cue, compact: isCompact)
                pips
            }
            .padding(.horizontal, AppSpacing.sm)
        } else {
            VStack(spacing: 8) {
                Text(tr("חַבְּרוּ אֶת הַזּוּגוֹת 🔗"))
                    .font(.system(size: isCompact ? 26 : 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                pips
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .glassPane(radius: 22)
            .padding(.horizontal, AppSpacing.sm)
        }
    }

    /// One mint dot per pair matched — a count with no numeral on it.
    private var pips: some View {
        HStack(spacing: 6) {
            ForEach(0..<pairCount, id: \.self) { i in
                Circle()
                    .fill(i < matched.count ? AppColor.successMint : Color.white.opacity(0.25))
                    .frame(width: preReader ? 13 : 9, height: preReader ? 13 : 9)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: matched.count)
    }

    /// A regular-width screen with height to spare.
    private var roomy: Bool { !isCompact && !display.isShort }

    private var columns: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            column(lefts, side: .left)
            column(rights, side: .right)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .environment(\.layoutDirection, .app)
    }

    private func column(_ cards: [Card], side: Side) -> some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                let isMatched = matched.contains(card.pair)
                let isPicked = (side == .left ? pickedLeft : pickedRight) == card.pair
                let isWrong = (side == .left ? wrongLeft : wrongRight) == card.pair
                let state: MiniGameTileState = isMatched ? .correct : (isWrong ? .wrong : (isPicked ? .picked : .normal))
                Button { tap(card, side: side) } label: {
                    Text(MiniGameText.show(card.text))
                        .font(.system(size: fontSize(card.text, side: side), weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(4).minimumScaleFactor(0.55)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity,
                               minHeight: preReader ? (display.isShort ? 80 : (isCompact ? 96 : 130))
                                                    : (display.isShort ? 56 : (isCompact ? 68 : 104)))
                        .mathLTR(MiniGameText.isMath(card.text))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .miniGameTile(state, tint: OptionCard.tints[(i + (side == .left ? 0 : 2)) % OptionCard.tints.count],
                                      radius: 20)
                        .scaleEffect(isPicked ? 1.04 : (isMatched ? 0.98 : 1))
                        .modifier(MiniGameShake(animatableData: isWrong ? shake : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
                }
                .buttonStyle(.juicy)
                .disabled(isMatched)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func fontSize(_ text: String, side: Side) -> CGFloat {
        // 👶 A גן tile carries one picture and nothing else — so it fills it.
        if preReader { return display.isShort ? 40 : (isCompact ? 52 : 68) }
        let longest = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(\.count).max() ?? text.count
        let base: CGFloat = isCompact ? 20 : 28
        if longest >= 11 || text.count > 30 { return base - 4 }
        return base
    }

    // MARK: - Logic

    private func deal() {
        if preReader {
            let round = PreReaderGames.pairs(count: pairCount)
            cue = round.cue
            source = .bank(.logic)
            lefts = round.pairs.enumerated().map { Card(pair: $0.offset, text: $0.element.left) }.shuffled()
            rights = round.pairs.enumerated().map { Card(pair: $0.offset, text: $0.element.right) }.shuffled()
            matched = []; missed = []; pickedLeft = nil; pickedRight = nil
            wrongLeft = nil; wrongRight = nil; grant = nil
            boardShownAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { started = true; done = false }
            return
        }
        cue = nil
        let picked = MatchPairsSource.pick(for: topic, grade: grade)
        // Math follows the child's adaptive level in math.
        let g = picked == .math ? MiniGameLevel.grade(for: .math) : grade
        let built = picked.pairs(count: pairCount, grade: g, profile: profiles.active)
        source = built.source
        let pairs = built.pairs
        lefts = pairs.enumerated().map { Card(pair: $0.offset, text: $0.element.left) }.shuffled()
        rights = pairs.enumerated().map { Card(pair: $0.offset, text: $0.element.right) }.shuffled()
        matched = []; missed = []; pickedLeft = nil; pickedRight = nil
        wrongLeft = nil; wrongRight = nil; grant = nil
        boardShownAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { started = true; done = false }
    }

    private func tap(_ card: Card, side: Side) {
        guard !done, !matched.contains(card.pair), wrongLeft == nil else { return }
        Haptic.selection()
        if side == .left { pickedLeft = (pickedLeft == card.pair) ? nil : card.pair }
        else { pickedRight = (pickedRight == card.pair) ? nil : card.pair }
        check()
    }

    private func check() {
        guard let l = pickedLeft, let r = pickedRight else { return }
        if l == r {
            // One answer per pair in the parent's reports: right the first time,
            // or a miss if it took more than one try. No minutes.
            // A pair that took a miss was already recorded as one (below).
            if !missed.contains(l) {
                MiniGameLedger.record(correct: true, topic: source.topic,
                                      responseMs: Date().timeIntervalSince(boardShownAt) * 1000 / Double(pairCount),
                                      earn: earn, surprise: surprise)
            }
            SoundPlayer.shared.play(.correctSmall)
            Haptic.success()
            burst += 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { _ = matched.insert(l) }
            pickedLeft = nil; pickedRight = nil
            if matched.count == lefts.count { finish() }
        } else {
            if missed.insert(l).inserted {
                MiniGameLedger.record(correct: false, topic: source.topic, earn: earn, surprise: surprise)
            }
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            if preReader { SpeechReader.shared.speak(PreReaderGames.almost) }
            wrongLeft = l; wrongRight = r
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 0.2)) {
                    wrongLeft = nil; wrongRight = nil
                    pickedLeft = nil; pickedRight = nil
                }
            }
        }
    }

    private func finish() {
        grant = MiniGameReward.grant(game: "pairs", correct: matched.count, starsPer: 2, diamondsPer: 2,
                                     cap: pairCount, surprise: surprise)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { done = true }
            SoundPlayer.shared.play(.chestOpen)
            Haptic.success()
            confetti += 1
        }
        AppAnalytics.log("pairs_game_done", ["source": source.topic.rawValue, "missed": "\(missed.count)"])
    }
}

#Preview {
    PairsGameView(onClose: {})
}
