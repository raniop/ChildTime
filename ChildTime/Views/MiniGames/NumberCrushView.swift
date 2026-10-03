import SwiftUI
import Combine

/// 🧱 "מְפַצְּחִים" — a target at the top ("יַעַד: 10") and a grid of colourful
/// number blocks. Tap blocks whose sum (product in a × round; ½ ⅓ ¼ or 0.1s in
/// ה׳+) makes the target exactly: picked blocks get a gold edge, a hit bursts
/// them and new blocks drop in from above. Going past the target only lets go
/// of the selection with a small shake. The board always holds at least one
/// way to the target. 60 seconds (45 in a surprise round).
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

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var isCompact: Bool { hsc == .compact }
    /// The child's level in math (adaptive), not just the class.
    private var grade: Int { MiniGameLevel.grade(for: .math) }
    /// Hits count in the world they're played in when it is a numbers world.
    private var recordTopic: Topic {
        if let topic, [.math, .money, .logic, .gifted].contains(topic) { return topic }
        return .math
    }
    private var roundSeconds: TimeInterval { TimeInterval(MiniGameKind.crush.seconds(surprise: surprise)) }
    private var remaining: TimeInterval { max(0, roundSeconds - now.timeIntervalSince(startedAt)) }
    /// 4×3 on a phone (and the foldable), 5×4 on an iPad.
    private var colCount: Int { isCompact || display.isShort ? 4 : 5 }
    private var rowCount: Int { isCompact || display.isShort ? 3 : 4 }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "🧱 \(hits)", surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    MiniGameIntroCard(kind: .crush) { start() }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    MiniGameEndCard(
                        title: hits >= 10 ? tr("וָואוּ, מְצֻיָּן! 🏆") : tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: summaryLine,
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד סִבּוּב 🔁"),
                        onAgain: { start() },
                        onDone: onClose)
                    Spacer()
                }
            }

            StarBurst(count: 12, color: AppColor.starGold, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if surprise && phase == .intro { start() } }
        .onReceive(ticker) { t in
            guard phase == .playing else { return }
            now = t
            if remaining <= 0 { finish() }
        }
    }

    private var summaryLine: String {
        switch hits {
        case 0:  return surprise ? tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") : tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
        case 1:  return tr("פִּצַּחְתֶּם אֶת הַיַּעַד פַּעַם אַחַת!")
        default: return tr("פִּצַּחְתֶּם אֶת הַיַּעַד \(hits) פְּעָמִים!")
        }
    }

    // MARK: - Playing

    private var pickedValues: [Int] {
        picked.compactMap { id in columns.joined().first { $0.id == id }?.value }
    }

    private var playing: some View {
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
        rules = CrushBoards.rules(grade: grade, topic: topic)
        var cols: [[Block]] = (0..<colCount).map { _ in (0..<rowCount).map { _ in newBlock() } }
        cols = ensureSolvable(cols, fresh: Set(cols.joined().map(\.id)))
        columns = cols
        picked = []; bursting = []; hits = 0; grant = nil
        startedAt = Date(); now = Date(); pickStartedAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
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
                                     cap: surprise ? 8 : 10, surprise: surprise)
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
