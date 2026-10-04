import SwiftUI
import Combine

/// 🧺 "מִיּוּן לַסַּלִּים" — two (from ד׳ often three) glass baskets with dashed
/// rims at the bottom, one item at a time at the top. Drag it into its basket
/// (or tap the basket): right → it drops in with a pop; a miss → it floats
/// gently back, nothing said. Ten items or the clock, a 🔥 streak.
///
/// A world with no baskets of its own sorts its questions: "שְׁאֵלָה · תְּשׁוּבָה"
/// into ✓ נָכוֹן / ✗ לֹא נָכוֹן.
///
/// 👶 גן plays it with no words at all: each basket wears PICTURES instead of
/// a label (🐶🐱 against 🍎🍌, 🐘 against 🐭, 🌊 against 🌳, 🔴 against 🔵),
/// six pictures to place, baskets a size up and no clock. The sentence that
/// names the rule is read aloud on entry and on every 🔊. See `PreReaderGames`.
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser every item
/// placed first time earns screen time like a regular answer.
struct SortBasketsView: View {
    var topic: Topic? = nil
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    private enum Phase { case intro, playing, done }
    private struct FramesKey: PreferenceKey {
        static let defaultValue: [Int: CGRect] = [:]
        static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
            value.merge(nextValue()) { $1 }
        }
    }
    private static let space = "sortSpace"
    /// The item chip's own frame in `frames` (baskets are 0, 1, 2).
    private static let chipKey = -1
    private static let tints: [Color] = [Color(hex: "48BFE3"), Color(hex: "FF6B9D"), Color(hex: "FFB84D")]

    @State private var phase: Phase = .intro
    @State private var set: SortSet?
    @State private var queue: [SortItem] = []
    @State private var sorted: [Int: [SortItem]] = [:]
    @State private var missedCurrent = false
    @State private var cleanCount = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var drag: CGSize = .zero
    @State private var dropping: Int?
    @State private var glow: (basket: Int, right: Bool)?
    @State private var frames: [Int: CGRect] = [:]
    @State private var startedAt = Date()
    @State private var now = Date()
    @State private var shownAt = Date()
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?
    /// 👶 גן: the spoken rule (nil for a reader), and the round's own length.
    @State private var cue: PreReaderCue?
    @State private var roundTotal = SortSets.roundItems
    /// 👶 Dealt before the intro card, so the card speaks the rule of the
    /// baskets the child is about to see; ▶️ then consumes it.
    @State private var preDealt = false

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var isCompact: Bool { hsc == .compact }
    private var grade: Int { topic == .math ? MiniGameLevel.grade(for: .math) : max(1, profiles.active?.effectiveGrade ?? 2) }
    private var roundSeconds: TimeInterval { TimeInterval(MiniGameKind.sort.seconds(surprise: surprise)) }
    private var remaining: TimeInterval { max(0, roundSeconds - now.timeIntervalSince(startedAt)) }
    private var current: SortItem? { queue.first }
    private var total: Int { roundTotal }
    /// 👶 A pre-reader (גן): pictures only, and no clock to lose to.
    private var preReader: Bool { PreReaderGames.isPreReader(profiles.active?.effectiveGrade ?? 1) }
    private var placedCount: Int { sorted.values.map(\.count).reduce(0, +) }
    /// Baskets in reading order — the first on the right in Hebrew / Arabic.
    private var basketOrder: [Int] {
        let idx = Array((set?.baskets ?? []).indices)
        return LanguageStore.shared.current.isRightToLeft ? idx.reversed() : idx
    }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: preReader
                                      ? "🧺 " + PreReaderChrome.dots(done: placedCount, total: total)
                                      : "🧺 \(placedCount)/\(total)",
                                      surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    if preReader {
                        PreReaderIntroCard(kind: .sort, cue: cue ?? PreReaderCue(spoken: PreReaderGames.startCue)) { start() }
                    } else {
                        MiniGameIntroCard(kind: .sort) { start() }
                    }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    if preReader {
                        PreReaderEndCard(
                            title: cleanCount == total ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                            detail: summaryLine,
                            tally: "🧺", tallyCount: placedCount, grant: grant, surprise: surprise,
                            againLabel: tr("עוֹד סִבּוּב 🔁"),
                            onAgain: { start() }, onDone: onClose)
                    } else {
                        MiniGameEndCard(
                            title: cleanCount == total ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
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

            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            if preReader, !preDealt { dealPreReader() }
            if (surprise || earn != nil) && phase == .intro { start() }
        }
        .onReceive(ticker) { t in
            // 👶 גן has no clock: the round ends when the last basket is filled.
            guard phase == .playing, !preReader else { return }
            now = t
            if remaining <= 0 { finish() }
        }
    }

    private var summaryLine: String {
        let first: String
        switch placedCount {
        case 0:  first = surprise ? tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") : tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
        case 1:  first = tr("פְּרִיט אֶחָד בַּסַּל")
        default: first = tr("\(placedCount) פְּרִיטִים בַּסַּלִּים")
        }
        guard bestStreak >= 2 else { return first }
        return first + "\n" + tr("הָרֶצֶף הֲכִי אָרֹךְ: \(bestStreak) 🔥")
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            if preReader, let cue {
                // 👶 The baskets themselves ARE the rule on screen; the
                // sentence that names it lives behind the 🔊.
                PreReaderCueCard(cue: cue, compact: isCompact)
            } else {
                VStack(spacing: 10) {
                    Text(isTrueFalse ? tr("נָכוֹן אוֹ לֹא נָכוֹן? גִּרְרוּ לַסַּל") : tr("גִּרְרוּ כָּל פְּרִיט לַסַּל הַמַּתְאִים"))
                        .font(.system(size: isCompact ? 16 : 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    MiniGameTimerBar(remaining: remaining, total: roundSeconds)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .glassPane(radius: 22)
            }

            Text(preReader ? PreReaderChrome.streak(streak) : (streak >= 2 ? tr("🔥 \(streak) בְּרֶצֶף") : " "))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
                .contentTransition(.numericText())

            Spacer(minLength: 0)
            ZStack {
                if let item = current {
                    itemChip(item)
                        .id(item.id)
                        .background(GeometryReader { g in
                            Color.clear.preference(key: FramesKey.self, value: [Self.chipKey: g.frame(in: .named(Self.space))])
                        })
                        .offset(drag)
                        .scaleEffect(dropping != nil ? 0.3 : (drag == .zero ? 1 : 1.06))
                        .opacity(dropping != nil ? 0 : 1)
                        .gesture(
                            DragGesture(coordinateSpace: .named(Self.space))
                                .onChanged { v in drag = v.translation }
                                .onEnded { v in
                                    if let b = frames.first(where: { $0.key >= 0 && $0.value.contains(v.location) })?.key {
                                        drop(into: b)
                                    } else {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { drag = .zero }
                                    }
                                }
                        )
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, minHeight: isCompact ? 120 : 170)
            .zIndex(2)
            Spacer(minLength: 0)

            HStack(spacing: isCompact ? 10 : 18) {
                ForEach(basketOrder, id: \.self) { b in
                    basketView(b)
                }
            }
            .padding(.bottom, AppSpacing.sm)
        }
        .frame(maxWidth: isCompact ? 640 : 820)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(FramesKey.self) { frames = $0 }
        // Laid out left-to-right so the drag follows the finger; the baskets'
        // order is mirrored by hand for Hebrew / Arabic (see `basketOrder`).
        .environment(\.layoutDirection, .leftToRight)
    }

    private var isTrueFalse: Bool { current?.detail != nil }

    private func itemChip(_ item: SortItem) -> some View {
        VStack(spacing: 6) {
            if !item.emoji.isEmpty {
                Text(item.emoji)
                    .font(.system(size: preReader
                                  ? (display.isShort ? 52 : (isCompact ? 76 : 100))
                                  : (isCompact ? 44 : 60)))
            }
            if !item.label.isEmpty {
                Text(MiniGameText.show(item.label))
                    .font(.system(size: item.detail != nil ? (isCompact ? 19 : 24) : (isCompact ? 26 : 34),
                                  weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3).minimumScaleFactor(0.6)
                    .mathLTR(MiniGameText.isMath(item.label))
            }
            if let d = item.detail {
                Text(MiniGameText.show(d))
                    .font(.system(size: isCompact ? 24 : 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .mathLTR(MiniGameText.isMath(d))
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .frame(minWidth: isCompact ? 150 : 210, maxWidth: isCompact ? 300 : 420)
        .miniGameTile(.picked, tint: AppColor.starGold, radius: 24)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
    }

    private func basketView(_ b: Int) -> some View {
        let basket = set?.baskets[b] ?? SortBasket(emoji: "", label: "")
        let tint = Self.tints[b % Self.tints.count]
        let inside = sorted[b] ?? []
        let state: MiniGameTileState = glow.map { $0.basket == b ? ($0.right ? .correct : .wrong) : .normal } ?? .normal
        return Button { drop(into: b) } label: {
            VStack(spacing: 6) {
                // What's in it so far — a little heap of pictures / words.
                HStack(spacing: -6) {
                    ForEach(inside.suffix(5)) { it in
                        Text(it.emoji.isEmpty ? "•" : it.emoji)
                            .font(.system(size: isCompact ? 16 : 22))
                    }
                }
                .frame(height: isCompact ? 22 : 30)
                Text(basket.emoji)
                    .font(.system(size: preReader
                                  ? (display.isShort ? 34 : (isCompact ? 46 : 60))
                                  : (isCompact ? 28 : 38)))
                    .lineLimit(1).minimumScaleFactor(0.5)
                if !basket.label.isEmpty {
                    Text(basket.label)
                        .font(.system(size: isCompact ? 15 : 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.6)
                }
            }
            .padding(.vertical, 12).padding(.horizontal, 6)
            .frame(maxWidth: .infinity,
                   minHeight: preReader
                   ? (display.isShort ? 108 : (isCompact ? 180 : 230))
                   : (isCompact ? 140 : 190))
            .miniGameTile(state, tint: tint, radius: 24)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                    .padding(6)
            )
            .scaleEffect(dropping == b ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: dropping)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
        }
        .buttonStyle(.juicy)
        .background(GeometryReader { g in
            Color.clear.preference(key: FramesKey.self, value: [b: g.frame(in: .named(Self.space))])
        })
        .accessibilityLabel(basket.label.isEmpty ? basket.emoji : basket.label)
    }

    // MARK: - Logic

    private func start() {
        // 👶 גן: picture baskets, six pictures, no words.
        if preReader {
            if !preDealt { dealPreReader() }
            preDealt = false
            sorted = [:]; missedCurrent = false; cleanCount = 0; streak = 0; bestStreak = 0; grant = nil
            drag = .zero; dropping = nil; glow = nil
            startedAt = Date(); now = Date(); shownAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
            return
        }
        cue = nil
        let source = topic
        var made: SortSet?
        if let source { made = SortSets.make(topic: source, grade: grade) ?? SortSets.trueFalse(topic: source, grade: grade) }
        if made == nil { made = SortSets.make(topic: .animals, grade: grade) }
        guard let s = made else { onClose(); return }
        set = s
        queue = s.items.first?.detail != nil ? s.items : SortSets.round(s)
        roundTotal = min(queue.count, SortSets.roundItems)
        sorted = [:]; missedCurrent = false; cleanCount = 0; streak = 0; bestStreak = 0; grant = nil
        drag = .zero; dropping = nil; glow = nil
        startedAt = Date(); now = Date(); shownAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    /// 👶 One גן round's baskets, pictures and spoken rule.
    private func dealPreReader() {
        let round = PreReaderGames.baskets()
        set = round.set
        cue = round.cue
        queue = PreReaderGames.basketRound(round.set)
        roundTotal = queue.count
        preDealt = true
    }

    private func drop(into b: Int) {
        guard phase == .playing, dropping == nil, let item = current, let s = set else { return }
        let right = item.basket == b
        if right {
            if !missedCurrent {
                cleanCount += 1
                streak += 1
                bestStreak = max(bestStreak, streak)
            }
            // An item that found its basket on the second try still pays —
            // exactly what the runner does when it re-asks a missed question.
            MiniGameLedger.record(correct: true, topic: s.topic, responseMs: Date().timeIntervalSince(shownAt) * 1000,
                                  streak: streak, earn: earn, surprise: surprise, retry: missedCurrent)
            burst += 1
            SoundPlayer.shared.play(streak > 0 && streak % 5 == 0 ? .streakUp : .correctSmall)
            Haptic.success()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // Into the basket — wherever the finger let go (or from the top, on a tap).
                if let chip = frames[Self.chipKey], let to = frames[b] {
                    drag = CGSize(width: to.midX - chip.midX, height: to.midY - chip.midY)
                }
                dropping = b
                glow = (b, true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                guard phase == .playing else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    sorted[b, default: []].append(item)
                    queue.removeFirst()
                    drag = .zero
                    dropping = nil
                    glow = nil
                }
                missedCurrent = false
                shownAt = Date()
                if queue.isEmpty { finish() }
            }
        } else {
            // It floats back — the basket glows soft warm for a moment.
            if !missedCurrent {
                missedCurrent = true
                streak = 0
                MiniGameLedger.record(correct: false, topic: s.topic, earn: earn, surprise: surprise)
            }
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            if preReader { SpeechReader.shared.speak(PreReaderGames.almost) }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                drag = .zero
                glow = (b, false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.2)) { if glow?.basket == b { glow = nil } }
            }
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        // Every item that reached a basket pays — `cleanCount` is the headline
        // ("מֻשְׁלָם!"), not the price.
        grant = MiniGameReward.grant(game: "sort", correct: placedCount, starsPer: 1, diamondsPer: 1,
                                     cap: total, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        if placedCount > 0 { confetti += 1 }
        AppAnalytics.log("sort_game_done", ["topic": set?.topic.rawValue ?? "", "clean": "\(cleanCount)",
                                            "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    SortBasketsView(topic: .animals, onClose: {})
}
