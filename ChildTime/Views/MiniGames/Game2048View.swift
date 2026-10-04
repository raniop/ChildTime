import SwiftUI
import Combine

/// 🔢 "2048 שֶׁל טוֹפִּי" — the classic 4×4: swipe, equal tiles merge, the
/// numbers climb. Tiles wear the app's palette (blue → purple → pink → gold →
/// mint, then warmer and glowing) on glass empties. Every 5 moves a short
/// bonus question from the world comes up — right → a bonus tile drops onto
/// the board. The round ends at the clock (2½ minutes) or when no move is
/// left; score and this child's best score.
///
/// The bonus questions are the learning here: from a world's chooser each one
/// answered right earns screen time like a regular answer; a ⚡ surprise round
/// pays ⭐/💎 only.
struct Game2048View: View {
    var topic: Topic? = nil
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    private enum Phase { case intro, playing, done }
    static let movesPerBonus = 5

    @State private var phase: Phase = .intro
    @State private var tiles: [Tile2048] = []
    /// Tiles swallowed by a merge: they slide onto their partner, then vanish.
    @State private var ghostIDs: Set<UUID> = []
    @State private var settling = false
    @State private var score = 0
    @State private var best = 0
    @State private var moves = 0
    @State private var bonus: GameItem?
    @State private var seenQuestions: Set<String> = []
    @State private var bonusRight = 0
    @State private var bonusAsked = 0
    @State private var startedAt = Date()
    @State private var now = Date()
    @State private var pausedFor: TimeInterval = 0
    @State private var bonusShownAt = Date()
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?
    @State private var noMoves = false

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var isCompact: Bool { hsc == .compact }
    private var roundSeconds: TimeInterval { TimeInterval(MiniGameKind.game2048.seconds(surprise: surprise)) }
    /// The clock stands still while a bonus question is on screen.
    private var remaining: TimeInterval {
        max(0, roundSeconds - now.timeIntervalSince(startedAt) + pausedFor + (bonus != nil ? now.timeIntervalSince(bonusShownAt) : 0))
    }
    private var maxTile: Int { tiles.map(\.value).max() ?? 2 }
    private var grade: Int { MiniGameLevel.grade(for: topic ?? .math) }
    /// 🎚️ The learning in 2048 is the bonus question, so that is what scales:
    /// ג׳–ד׳ every 5 moves, ה׳–ו׳ every 4, ז׳–ח׳ every 3.
    private var movesPerBonus: Int {
        switch MiniGameBand.of(grade) {
        case .upper: return 4
        case .top:   return 3
        default:     return Self.movesPerBonus
        }
    }
    /// And the reward for a right answer: half the biggest tile for a ג׳ child,
    /// a quarter of it by ז׳ — the board stays a puzzle, not a gift.
    private var bonusTileDivisor: Int { MiniGameBand.of(grade) >= .top ? 4 : 2 }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "🔢 \(score)", surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    MiniGameIntroCard(kind: .game2048) { start() }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    MiniGameEndCard(
                        title: score >= best && score > 0 ? tr("שִׂיא חָדָשׁ! 🏆") : tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: summaryLine,
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד סִבּוּב 🔁"),
                        onAgain: { start() },
                        onDone: onClose)
                    Spacer()
                }
            }

            if let item = bonus, phase == .playing {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .transition(.opacity)
                MiniGameQuestionCard(item: item, header: tr("⭐ שְׁאֵלַת בּוֹנוּס — תְּשׁוּבָה נְכוֹנָה מַפִּילָה אָרִיחַ!")) { right in
                    answerBonus(item, right: right)
                }
                .padding(.horizontal, AppSpacing.lg)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            StarBurst(count: 12, color: AppColor.starGold, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            best = UserDefaults.standard.integer(forKey: Board2048.bestKey())
            if (surprise || earn != nil) && phase == .intro { start() }
        }
        .onReceive(ticker) { t in
            guard phase == .playing else { return }
            now = t
            if remaining <= 0 && bonus == nil { finish() }
        }
    }

    private var summaryLine: String {
        var line = tr("נְקֻדּוֹת: \(score) · הָאָרִיחַ הַגָּדוֹל: \(maxTile)")
        if bonusAsked > 0 { line += "\n" + tr("שְׁאֵלוֹת בּוֹנוּס: \(bonusRight) מִתּוֹךְ \(bonusAsked)") }
        if noMoves { line = tr("הַלּוּחַ הִתְמַלֵּא!") + "\n" + line }
        return line
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            HStack(spacing: 10) {
                scoreBox(tr("נְקֻדּוֹת"), score)
                scoreBox(tr("שִׂיא"), max(best, score))
                VStack(spacing: 4) {
                    Text(tr("בּוֹנוּס בְּעוֹד"))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                    Text("\(Self.movesPerBonus - moves % Self.movesPerBonus)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .glassInset(radius: 14)
            }
            MiniGameTimerBar(remaining: remaining, total: roundSeconds)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .glassPane(radius: 18, shadow: false)
            Spacer(minLength: 0)
            board
            Text(tr("הַחְלִיקוּ לְכָל כִּוּוּן 👆"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.tertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 520 : 680)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    private func scoreBox(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
            Text("\(value)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassInset(radius: 14)
    }

    private var board: some View {
        GeometryReader { geo in
            let n = Board2048.size
            let side = min(geo.size.width, geo.size.height)
            let gap = side * 0.03
            let cell = (side - gap * CGFloat(n + 1)) / CGFloat(n)
            ZStack(alignment: .topLeading) {
                // Glass empties.
                ForEach(0..<(n * n), id: \.self) { i in
                    RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                        .fill(.white.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
                        .frame(width: cell, height: cell)
                        .position(Self.center(i / n, i % n, cell: cell, gap: gap))
                }
                ForEach(tiles) { t in
                    tileView(t, cell: cell, shownValue: settling && t.merged ? t.value / 2 : t.value)
                        .position(Self.center(t.r, t.c, cell: cell, gap: gap))
                        .zIndex(ghostIDs.contains(t.id) ? 0 : 1)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .frame(width: side, height: side)
            .glassPane(radius: side * 0.05)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 18).onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                guard max(abs(dx), abs(dy)) > 18 else { return }
                if abs(dx) > abs(dy) { move(dx > 0 ? .right : .left) } else { move(dy > 0 ? .down : .up) }
            })
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: isCompact ? 420 : 600)
        // The board is geometry, not text: left stays left in every language.
        .environment(\.layoutDirection, .leftToRight)
    }

    private static func center(_ r: Int, _ c: Int, cell: CGFloat, gap: CGFloat) -> CGPoint {
        CGPoint(x: gap + CGFloat(c) * (cell + gap) + cell / 2, y: gap + CGFloat(r) * (cell + gap) + cell / 2)
    }

    private func tileView(_ t: Tile2048, cell: CGFloat, shownValue: Int) -> some View {
        let color = Board2048.color(shownValue)
        let digits = "\(shownValue)".count
        return Text("\(shownValue)")
            .font(.system(size: cell * (digits >= 4 ? 0.28 : (digits == 3 ? 0.34 : 0.42)), weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .frame(width: cell, height: cell)
            .background(
                RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 1.2))
            .glow(color, radius: shownValue >= 64 ? 12 : 0)
            .scaleEffect(!settling && t.merged ? 1.12 : 1)
    }

    // MARK: - Logic

    private func start() {
        tiles = []; ghostIDs = []; score = 0; moves = 0; bonus = nil
        bonusRight = 0; bonusAsked = 0; noMoves = false; grant = nil; pausedFor = 0
        best = UserDefaults.standard.integer(forKey: Board2048.bestKey())
        spawn(); spawn()
        startedAt = Date(); now = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    @discardableResult
    private func spawn(value: Int? = nil) -> Bool {
        guard let (r, c) = Board2048.emptyCells(tiles).randomElement() else { return false }
        let t = Tile2048(id: UUID(), value: value ?? (Int.random(in: 0..<10) == 0 ? 4 : 2), r: r, c: c)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { tiles.append(t) }
        return true
    }

    private func move(_ dir: Move2048) {
        guard phase == .playing, bonus == nil, !settling else { return }
        let result = Board2048.slide(tiles, dir)
        guard result.moved else {
            Haptic.light()
            return
        }
        Haptic.selection()
        settling = true
        ghostIDs = Set(result.consumed.map(\.id))
        withAnimation(.easeOut(duration: 0.12)) {
            tiles = result.tiles + result.consumed
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            tiles.removeAll { ghostIDs.contains($0.id) }
            ghostIDs = []
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { settling = false }
            if result.points > 0 {
                score += result.points
                SoundPlayer.shared.play(result.points >= 64 ? .correctBig : .uiTap)
                if result.tiles.contains(where: { $0.merged && $0.value >= 128 }) { burst += 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    tiles = tiles.map { var t = $0; t.merged = false; return t }
                }
            }
            spawn()
            moves += 1
            if moves % movesPerBonus == 0 {
                askBonus()
            } else if !Board2048.canMove(tiles) {
                noMoves = true
                finish()
            }
        }
    }

    private func askBonus() {
        let item = GameContent.card(topic: topic, grade: grade, avoiding: &seenQuestions)
        bonusShownAt = Date()
        bonusAsked += 1
        SoundPlayer.shared.play(.portalAppear)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { bonus = item }
    }

    private func answerBonus(_ item: GameItem, right: Bool) {
        MiniGameLedger.record(correct: right, topic: item.topic, responseMs: Date().timeIntervalSince(bonusShownAt) * 1000,
                              streak: bonusRight, earn: earn, surprise: surprise)
        pausedFor += Date().timeIntervalSince(bonusShownAt)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { bonus = nil }
        if right {
            bonusRight += 1
            // A bonus tile: half the biggest on the board (4 at least).
            let v = max(4, maxTile / bonusTileDivisor)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if spawn(value: v) {
                    burst += 1
                    Haptic.success()
                }
                if !Board2048.canMove(tiles) { noMoves = true; finish() }
            }
        } else if !Board2048.canMove(tiles) {
            noMoves = true
            finish()
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        bonus = nil
        if score > best {
            best = score
            UserDefaults.standard.set(score, forKey: Board2048.bestKey())
        }
        // Stars by the biggest tile reached (64 → 6 steps), plus the bonus answers.
        let steps = max(0, Int(log2(Double(max(2, maxTile)))) - 1)
        grant = MiniGameReward.grant(game: "2048", correct: steps + bonusRight, starsPer: 1, diamondsPer: 1,
                                     cap: 12, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        confetti += 1
        AppAnalytics.log("g2048_done", ["score": "\(score)", "max": "\(maxTile)", "bonus": "\(bonusRight)/\(bonusAsked)",
                                        "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    Game2048View(topic: .math, onClose: {})
}
