import SwiftUI

/// 🧠 "הַתַּבְנִית" — a row of five or six glass tiles, one of them a gold "?",
/// and four answers. Numbers (+k, ×k, squares, Fibonacci-like, into the
/// negatives in ז׳), letters in the English / Hebrew worlds, pictures for the
/// youngest and the logic worlds. A right answer drops into the "?" in mint; a
/// miss glows soft warm and the child tries again. Six per round.
///
/// 👶 גן plays it with no words and no numbers: 🔴 🔵 🔴 🔵 🔴 ❓ — two
/// pictures, five cells, three big choices, four sequences, and "מָה מַמְשִׁיךְ
/// אֶת הַסִּדְרָה?" read aloud rather than printed. See `PreReaderGames`.
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser every
/// pattern solved first time earns screen time like a regular answer.
struct PatternGameView: View {
    var topic: Topic? = nil
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc
    /// 🖼 A miniature on a What's-New story card: show the real screen,
    /// but do not play it — no round is scored and no clock runs.
    @Environment(\.isInertPreview) private var inertPreview

    private enum Phase { case intro, playing, done }

    @State private var phase: Phase = .intro
    @State private var round: PatternRound?
    @State private var index = 0
    @State private var picked: String?
    @State private var wrongPicks: Set<String> = []
    @State private var missed = false
    @State private var clean = 0
    @State private var shake: CGFloat = 0
    @State private var shownAt = Date()
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?

    private var isCompact: Bool { hsc == .compact }
    private var count: Int {
        if preReader { return PreReaderGames.patternCount }
        return surprise ? 5 : PatternGen.roundCount
    }
    /// 👶 A pre-reader (גן): pictures only, bigger cells, four rows a round.
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
    private var grade: Int {
        if preReader { return 0 }
        switch topic {
        case .english?, .hebrew?: return max(1, profiles.active?.effectiveGrade ?? 2)
        default: return MiniGameLevel.grade(for: topic ?? .math)
        }
    }
    private var solved: Bool { picked != nil && picked == round?.answer }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: preReader
                                      ? "🧠 " + PreReaderChrome.dots(done: index, total: count)
                                      : "🧠 \(min(index + 1, count))/\(count)",
                                      surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    if preReader {
                        PreReaderIntroCard(kind: .pattern, cue: PreReaderGames.patternCue) { start() }
                    } else {
                        MiniGameIntroCard(kind: .pattern) { start() }
                    }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    if preReader {
                        PreReaderEndCard(
                            title: clean == count ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                            detail: tr("פִּצַּחְתֶּם \(count) תַּבְנִיּוֹת!"),
                            tally: "🧠", tallyCount: clean, grant: grant, surprise: surprise,
                            againLabel: tr("עוֹד סִבּוּב 🔁"),
                            onAgain: { start() }, onDone: onClose)
                    } else {
                        MiniGameEndCard(
                            title: clean == count ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                            detail: tr("פִּצַּחְתֶּם \(count) תַּבְנִיּוֹת!"),
                            grant: grant,
                            surprise: surprise,
                            againLabel: tr("עוֹד סִבּוּב 🔁"),
                            onAgain: { start() },
                            onDone: onClose)
                    }
                    Spacer()
                }
            }

            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if (surprise || earn != nil || inertPreview) && phase == .intro { start() } }
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.lg) {
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                if preReader {
                    // 👶 The row itself is the question; the 🔊 says it in words.
                    PreReaderCueCard(cue: PreReaderGames.patternCue, compact: isCompact)
                } else {
                    Text(tr("מָה מַשְׁלִים אֶת הַתַּבְנִית?"))
                        .font(.system(size: isCompact ? 20 : 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                sequenceRow
            }
            .padding(.horizontal, 12).padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .glassPane(radius: 16)
            .modifier(MiniGameShake(animatableData: shake))
            .id(index)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            answers
            Spacer(minLength: 0)
        }
        .frame(maxWidth: preReader ? (isCompact ? 560 : 620) : (isCompact ? 640 : 820))
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    private var sequenceRow: some View {
        let cells = round?.cells ?? []
        return GeometryReader { geo in
            let gap: CGFloat = isCompact ? 6 : 10
            let maxSide: CGFloat = preReader
                ? (display.isShort ? 62 : (isCompact ? 86 : 120))
                : (isCompact ? 70 : 104)
            let side = min(maxSide, (geo.size.width - gap * CGFloat(max(0, cells.count - 1))) / CGFloat(max(1, cells.count)))
            HStack(spacing: gap) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    let hole = cell == "?"
                    let shown = hole && solved ? (round?.answer ?? "?") : cell
                    Text(shown)
                        .font(.system(size: side * (shown.count > 3 ? 0.3 : (shown.count > 2 ? 0.36 : 0.46)), weight: .black, design: .rounded))
                        .foregroundStyle(hole && !solved ? AppColor.starGold : .white)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .monospacedDigit()
                        .frame(width: side, height: side)
                        .miniGameTile(hole ? (solved ? .correct : .picked) : .normal, tint: .white.opacity(0.25), radius: side * 0.24)
                        .overlay {
                            if hole && !solved {
                                RoundedRectangle(cornerRadius: side * 0.2, style: .continuous)
                                    .strokeBorder(AppColor.starGold.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                                    .padding(4)
                            }
                        }
                        .scaleEffect(hole && solved ? 1.12 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: solved)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: preReader
               ? (display.isShort ? 66 : (isCompact ? 90 : 124))
               : (isCompact ? 74 : 108))
        // Numbers and pictures read left-to-right; Hebrew letters from the right.
        .environment(\.layoutDirection, round?.direction ?? .leftToRight)
    }

    private var answers: some View {
        let opts = round?.options ?? []
        // 👶 גן: three choices in one row, each a big picture.
        let cols = preReader ? min(3, max(1, opts.count)) : (isCompact ? 2 : 4)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: cols), spacing: 12) {
            ForEach(Array(opts.enumerated()), id: \.element) { i, opt in
                let state: MiniGameTileState = opt == picked && solved ? .correct : (wrongPicks.contains(opt) ? .wrong : .normal)
                Button { pick(opt) } label: {
                    Text(opt)
                        .font(.system(size: preReader
                                      ? (display.isShort ? 34 : (isCompact ? 46 : 58))
                                      : (isCompact ? 32 : 42),
                                      weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity,
                               minHeight: preReader
                               ? (display.isShort ? 70 : (isCompact ? 100 : 120))
                               : (isCompact ? 76 : 110))
                        .miniGameTile(state, tint: OptionCard.tints[i % OptionCard.tints.count], radius: 22)
                        .mathLTR(round?.direction == .leftToRight)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
                }
                .buttonStyle(.juicy)
                .disabled(solved || wrongPicks.contains(opt))
            }
        }
    }

    // MARK: - Logic

    private func start() {
        index = 0; clean = 0; grant = nil
        load()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    private func load() {
        var r = PatternGen.make(topic: topic, grade: grade)
        // Never the very same row twice in a row.
        var tries = 0
        while r.cells == round?.cells, tries < 5 { r = PatternGen.make(topic: topic, grade: grade); tries += 1 }
        round = r
        picked = nil; wrongPicks = []; missed = false; shownAt = Date()
    }

    private func pick(_ opt: String) {
        guard phase == .playing, !solved, let r = round else { return }
        if opt == r.answer {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { picked = opt }
            if !missed { clean += 1 }
            // A round solved on the second try still pays — exactly what the
            // runner does when it re-asks a question the child first missed.
            MiniGameLedger.record(correct: true, topic: r.topic, responseMs: Date().timeIntervalSince(shownAt) * 1000,
                                  streak: clean, earn: earn, surprise: surprise, retry: missed)
            burst += 1
            SoundPlayer.shared.play(.correctBig)
            Haptic.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard phase == .playing else { return }
                if index + 1 < count {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { index += 1; load() }
                } else {
                    finish()
                }
            }
        } else {
            if !missed {
                missed = true
                MiniGameLedger.record(correct: false, topic: r.topic, earn: earn, surprise: surprise)
            }
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            if preReader { SpeechReader.shared.speak(PreReaderGames.almost) }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { _ = wrongPicks.insert(opt) }
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        // Every round the child SOLVED pays (the board only moves on when it is
        // solved, so that is all of them) — `clean` is the headline, not the price.
        grant = MiniGameReward.grant(game: "pattern", correct: count, starsPer: 2, diamondsPer: 1,
                                     cap: count, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        confetti += 1
        AppAnalytics.log("pattern_game_done", ["clean": "\(clean)", "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    PatternGameView(topic: .math, onClose: {})
}
