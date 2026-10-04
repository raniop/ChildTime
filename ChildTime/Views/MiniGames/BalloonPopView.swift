import SwiftUI
import Combine

/// 🎈 "פּוֹצְצוּ אֶת הַבַּלּוֹנִים" — a category prompt ("פּוֹצְצוּ אֶת כָּל הַחַיּוֹת
/// שֶׁחַיּוֹת בַּיָּם!") and colourful balloons floating up from the bottom at
/// different speeds, each carrying a word, a number or a picture. Pop the right
/// ones; a wrong one only wobbles (no text, no penalty beyond the streak), and
/// a balloon that floats away just floats away. 30 seconds.
///
/// A world without a category of its own plays it as questions: the prompt
/// is one of the world's questions and the balloons carry its answers — pop
/// the right one and the next question comes.
///
/// 👶 גן plays it with no words at all: the rule is a picture in the gold cue
/// card (one object, one colour, or a row of objects that shows a quantity),
/// read aloud on entry and again on every 🔊. Bigger balloons, fewer of them,
/// no clock — the round ends after six good pops. See `PreReaderGames`.
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser every
/// right pop earns screen time like a regular answer.
struct BalloonPopView: View {
    var topic: Topic? = nil
    /// ⚡ Launched by the runner's surprise round: no intro, one round, ×2.
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    private struct Balloon: Identifiable {
        let id = UUID()
        let item: BalloonItem
        /// Horizontal lane, 0…1 of the field's width.
        let lane: CGFloat
        let spawnedAt: Date
        /// Question mode: which question this balloon answers.
        var round: Int = 0
        /// Seconds to cross the field — varied, so the sky never moves in step.
        let duration: Double
        let color: Color
        let swayPhase: Double
        var poppedAt: Date?
        var wobbledAt: Date?
    }

    private enum Phase { case intro, playing, done }

    /// The balloon palette (the app's own accents).
    private static let palette: [Color] = [Color(hex: "FF6B9D"), Color(hex: "06D6A0"), Color(hex: "FFB84D"),
                                           Color(hex: "48BFE3"), Color(hex: "9B5DE5")]

    @State private var phase: Phase = .intro
    @State private var set: BalloonSet?
    @State private var balloons: [Balloon] = []
    @State private var startedAt = Date()
    @State private var now = Date()
    @State private var nextSpawnAt = Date()
    @State private var targetQueue: [BalloonItem] = []
    @State private var otherQueue: [BalloonItem] = []
    @State private var lastLane: CGFloat = 0.5
    @State private var popped = 0
    @State private var misses = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?
    /// 👶 גן: the spoken rule and the pictures that show it (nil for a reader).
    @State private var cue: PreReaderCue?
    /// 👶 A גן round is dealt before its intro card, so the card shows and
    /// speaks the rule the child is about to play; ▶️ then consumes it.
    @State private var preDealt = false
    /// Question mode — the world's questions, the one on screen, and whether
    /// it already took a miss (one answer per question in the reports).
    @State private var questions: [GameItem] = []
    @State private var qIndex = 0
    @State private var qMissed = false
    @State private var qQueue: [String] = []
    @State private var sinceCorrect = 0
    @State private var qShownAt = Date()
    private var questionMode: Bool { !questions.isEmpty }
    private var currentQuestion: GameItem? { questionMode ? questions[qIndex % questions.count] : nil }

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var isCompact: Bool { hsc == .compact }
    private var roundSeconds: TimeInterval { TimeInterval(MiniGameKind.balloon.seconds(surprise: surprise)) }
    private var remaining: TimeInterval { max(0, roundSeconds - now.timeIntervalSince(startedAt)) }
    private var timeFrac: Double { remaining / roundSeconds }
    private var grade: Int { max(1, profiles.active?.effectiveGrade ?? 2) }
    /// 👶 A pre-reader (גן): no words on screen, and no clock to lose to.
    private var preReader: Bool { PreReaderGames.isPreReader(profiles.active?.effectiveGrade ?? 1) }
    /// 👶 Bigger balloons — a five-year-old's finger, not a ten-year-old's.
    private var balloonSize: CGSize {
        if preReader {
            // 🔄 On its side the field is only ~230pt tall: a 150pt balloon
            // would fill it, so a short screen gets the smaller one.
            if display.isShort { return CGSize(width: 100, height: 120) }
            return isCompact ? CGSize(width: 126, height: 150) : CGSize(width: 158, height: 186)
        }
        return isCompact ? CGSize(width: 96, height: 114) : CGSize(width: 124, height: 146)
    }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: preReader
                                      ? "🎈 " + PreReaderChrome.dots(done: popped, total: PreReaderGames.roundItems)
                                      : "🎈 \(popped)",
                                      surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    if preReader {
                        PreReaderIntroCard(kind: .balloon,
                                           cue: cue ?? PreReaderCue(spoken: PreReaderGames.startCue)) { start() }
                    } else {
                        MiniGameIntroCard(kind: .balloon) { start() }
                    }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    if preReader {
                        PreReaderEndCard(tally: "🎈", tallyCount: popped, grant: grant, surprise: surprise,
                                         onAgain: { start() }, onDone: onClose)
                    } else {
                        MiniGameEndCard(
                            title: popped >= 12 ? tr("וָואוּ, מְצֻיָּן! 🏆") : tr("כָּל הַכָּבוֹד! 🎉"),
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

            StarBurst(color: AppColor.starGold, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            if preReader, !preDealt { dealPreReader() }
            if (surprise || earn != nil) && phase == .intro { start() }
        }
        .onReceive(ticker) { t in tick(t) }
    }

    private var summaryLine: String {
        let first: String
        switch popped {
        case 0:  first = surprise ? tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") : tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
        case 1:  first = tr("בַּלּוֹן נָכוֹן אֶחָד")
        default: first = tr("\(popped) בַּלּוֹנִים נְכוֹנִים")
        }
        guard bestStreak >= 2 else { return first }
        return first + "\n" + tr("הָרֶצֶף הֲכִי אָרֹךְ: \(bestStreak) 🔥")
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: AppSpacing.sm) {
            // 👶 גן: the rule as pictures and a 🔊 — nothing to read, no clock.
            if preReader, let cue {
                PreReaderCueCard(cue: cue, compact: isCompact)
                    .padding(.horizontal, AppSpacing.md)
            } else {
            // The prompt, in the runner's question card.
            VStack(spacing: 10) {
                if let q = currentQuestion {
                    Text(tr("פּוֹצְצוּ אֶת הַתְּשׁוּבָה הַנְּכוֹנָה!"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                    Text(MiniGameText.show(q.prompt))
                        .font(.system(size: isCompact ? 22 : 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .mathLTR(MiniGameText.isMath(q.prompt))
                        .id(qIndex)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    Text(set?.prompt ?? "")
                        .font(.system(size: isCompact ? 22 : 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                timerBar
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .glassPane(radius: 22)
            .padding(.horizontal, AppSpacing.md)
            }

            Text(preReader ? PreReaderChrome.streak(streak)
                           : (streak >= 2 ? tr("🔥 \(streak) בְּרֶצֶף") : " "))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
                .contentTransition(.numericText())

            GeometryReader { geo in
                ZStack {
                    ForEach(balloons) { b in
                        balloonView(b, in: geo.size)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .clipped()
        }
        .frame(maxWidth: isCompact ? 700 : 900)
    }

    private var timerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.9))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "FFD23F"), Color(hex: "FF9F1C")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * timeFrac))
                        .animation(.linear(duration: 0.1), value: timeFrac)
                }
            }
            .frame(height: 8)
            Text("\(Int(remaining.rounded(.up)))″")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(minWidth: 30)
        }
    }

    @ViewBuilder
    private func balloonView(_ b: Balloon, in field: CGSize) -> some View {
        let size = balloonSize
        let age = now.timeIntervalSince(b.spawnedAt)
        let progress = age / b.duration
        let y = field.height + size.height / 2 - CGFloat(progress) * (field.height + size.height * 1.4)
        let sway = CGFloat(sin(age * 1.6 + b.swayPhase)) * 10
        let usable = max(1, field.width - size.width)
        let x = size.width / 2 + b.lane * usable + sway
        let wobble: Double = {
            guard let w = b.wobbledAt else { return 0 }
            let dt = now.timeIntervalSince(w)
            guard dt < 0.6 else { return 0 }
            return sin(dt * 28) * 14 * (1 - dt / 0.6)
        }()
        let popT = b.poppedAt.map { now.timeIntervalSince($0) } ?? -1

        Group {
            if popT >= 0 {
                // Popped: a mint ring and a sparkle, gone in a moment.
                ZStack {
                    Circle()
                        .strokeBorder(Color(hex: "8CFFC4"), lineWidth: 4)
                        .frame(width: size.width * (0.6 + popT * 2), height: size.width * (0.6 + popT * 2))
                    Text("✨").font(.system(size: 34))
                }
                .glow(AppColor.successMint, radius: 10)
                .opacity(max(0, 1 - popT / 0.35))
            } else {
                BalloonShape(item: b.item, color: b.item.colorHex.map { Color(hex: $0) } ?? b.color,
                             size: size, tried: b.wobbledAt != nil)
                    .rotationEffect(.degrees(wobble), anchor: .bottom)
                    .contentShape(Ellipse())
                    .onTapGesture { tap(b.id) }
            }
        }
        .position(x: x, y: y)
        .allowsHitTesting(popT < 0)
    }

    // MARK: - Logic

    private func start() {
        // 👶 גן never plays the world's bank: its board is pictures only.
        if preReader {
            if !preDealt { dealPreReader() }
            preDealt = false
            targetQueue = []; otherQueue = []
            balloons = []
            popped = 0; misses = 0; streak = 0; bestStreak = 0; grant = nil
            startedAt = Date(); now = Date(); nextSpawnAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
            return
        }
        cue = nil
        // A world with a category of its own pops that; any other world pops
        // the answers to its own questions.
        if let topic, !BalloonSets.hasCategory(topic, grade: grade) {
            questions = GameContent.items(topic: topic, grade: grade, maxPrompt: 70, maxAnswer: 16)
        } else {
            questions = []
        }
        qIndex = 0; qMissed = false; qQueue = []; sinceCorrect = 0; qShownAt = Date()
        let s = BalloonSets.make(for: topic, grade: grade)
        set = questionMode ? BalloonSet(prompt: "", topic: topic ?? s.topic, targets: [], others: []) : s
        targetQueue = []; otherQueue = []
        balloons = []
        popped = 0; misses = 0; streak = 0; bestStreak = 0; grant = nil
        startedAt = Date(); now = Date(); nextSpawnAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    /// 👶 One גן round's rule and balloons, from `PreReaderGames`.
    private func dealPreReader() {
        let round = PreReaderGames.balloons()
        questions = []
        qIndex = 0; qMissed = false; qQueue = []; sinceCorrect = 0; qShownAt = Date()
        set = round.set
        cue = round.cue
        preDealt = true
    }

    private func nextItem() -> BalloonItem? {
        if let q = currentQuestion {
            // Its answers in turn — the right one never more than 3 balloons apart.
            if sinceCorrect >= 2 {
                sinceCorrect = 0
                return BalloonItem(emoji: "", label: q.answer, correct: true)
            }
            if qQueue.isEmpty { qQueue = q.shuffledOptions }
            let label = qQueue.removeLast()
            let right = label == q.answer
            sinceCorrect = right ? 0 : sinceCorrect + 1
            return BalloonItem(emoji: "", label: label, correct: right)
        }
        guard let s = set else { return nil }
        // 🎚️ The younger the child, the more of the balloons are the right
        // ones; by ז׳–ח׳ most of what floats up is a distractor.
        let share: Double
        switch MiniGameBand.of(preReader ? 0 : grade) {
        case .preReader:         share = 0.70
        case .lower:             share = 0.65
        case .middle:            share = 0.55
        case .upper:             share = 0.48
        case .top:               share = 0.42
        }
        let wantTarget = Double.random(in: 0...1) < share
        if wantTarget {
            if targetQueue.isEmpty { targetQueue = s.targets.shuffled() }
            return targetQueue.popLast()
        }
        if otherQueue.isEmpty { otherQueue = s.others.shuffled() }
        return otherQueue.popLast()
    }

    private func tick(_ t: Date) {
        guard phase == .playing else { return }
        now = t
        // Tidy up: balloons that floated away, pops that finished.
        balloons.removeAll { b in
            if let p = b.poppedAt { return t.timeIntervalSince(p) > 0.4 }
            return t.timeIntervalSince(b.spawnedAt) > b.duration
        }
        // 👶 גן has no clock on screen and nothing to lose to: the round ends
        // on six good pops. A long backstop still closes it, so a child who
        // never finds the right balloon isn't left in an endless sky — and it
        // ends the same celebrating way, with whatever they did pop.
        if preReader {
            if popped >= PreReaderGames.roundItems || t.timeIntervalSince(startedAt) > 120 {
                finish()
                return
            }
        } else if remaining <= 0 {
            finish()
            return
        }
        if t >= nextSpawnAt, balloons.count < (preReader ? 4 : 9), let item = nextItem() {
            // A lane away from the last one, so two balloons never stack.
            var lane = CGFloat.random(in: 0...1)
            if abs(lane - lastLane) < 0.25 { lane = lane > 0.5 ? lane - 0.35 : lane + 0.35 }
            lastLane = lane
            // 🎚️ And they rise faster: a ח׳ child has less time to decide.
            let slow: Double
            switch MiniGameBand.of(preReader ? 0 : grade) {
            case .preReader:         slow = 1.9
            case .lower:             slow = grade <= 1 ? 1.25 : 1.1
            case .middle:            slow = 1.0
            case .upper:             slow = 0.88
            case .top:               slow = 0.78
            }
            balloons.append(Balloon(item: item, lane: lane, spawnedAt: t, round: qIndex,
                                    duration: Double.random(in: 4.6...7.0) * slow,
                                    color: Self.palette.randomElement()!,
                                    swayPhase: Double.random(in: 0...(2 * .pi))))
            nextSpawnAt = t.addingTimeInterval(Double.random(in: 0.55...0.95) * slow)
        }
    }

    private func tap(_ id: UUID) {
        guard phase == .playing, let i = balloons.firstIndex(where: { $0.id == id }),
              balloons[i].poppedAt == nil, balloons[i].wobbledAt == nil, let s = set else { return }
        let b = balloons[i]
        if questionMode, b.round != qIndex { return }   // an earlier question's balloon
        if b.item.correct {
            balloons[i].poppedAt = Date()
            popped += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            burst += 1
            SoundPlayer.shared.play(streak % 5 == 0 ? .streakUp : .correctSmall)
            Haptic.success()
        } else {
            // A gentle wobble — the balloon stays and floats on; no word about it.
            balloons[i].wobbledAt = Date()
            misses += 1
            streak = 0
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
        }
        if let q = currentQuestion {
            // One answer per question: a miss once, or right first time.
            if !b.item.correct {
                if !qMissed {
                    qMissed = true
                    MiniGameLedger.record(correct: false, topic: q.topic, earn: earn, surprise: surprise)
                }
                return
            }
            if !qMissed {
                MiniGameLedger.record(correct: true, topic: q.topic,
                                      responseMs: Date().timeIntervalSince(qShownAt) * 1000,
                                      streak: streak, earn: earn, surprise: surprise)
            }
            // The next question: this one's other balloons drift off.
            let old = qIndex
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { qIndex += 1 }
            qMissed = false; qQueue = []; sinceCorrect = 0; qShownAt = Date()
            balloons.removeAll { $0.round == old && $0.poppedAt == nil }
            nextSpawnAt = Date().addingTimeInterval(0.3)
            return
        }
        // Every tap is an answer in the parent's reports.
        MiniGameLedger.record(correct: b.item.correct, topic: s.topic, streak: streak, earn: earn, surprise: surprise)
    }

    private func finish() {
        guard phase == .playing else { return }
        balloons = []
        grant = MiniGameReward.grant(game: "balloon", correct: popped, starsPer: 1, diamondsPer: 1,
                                     cap: surprise ? 12 : 15, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        if popped > 0 { confetti += 1 }
        AppAnalytics.log("balloon_pop_done", ["topic": set?.topic.rawValue ?? "", "popped": "\(popped)",
                                              "surprise": surprise ? "1" : "0"])
    }
}

/// One balloon: a glossy oval in its colour, a knot and a string, the word /
/// number / picture riding on it.
private struct BalloonShape: View {
    let item: BalloonItem
    let color: Color
    let size: CGSize
    let tried: Bool

    /// One picture fills the balloon; a row of them shrinks to fit.
    private var pictureScale: CGFloat {
        switch item.emoji.count {
        case ...1: return 0.52
        case 2:    return 0.34
        case 3:    return 0.26
        case 4:    return 0.21
        default:   return 0.17
        }
    }

    var body: some View {
        let body = CGSize(width: size.width, height: size.height * 0.82)
        VStack(spacing: 0) {
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [color.opacity(0.95), color.opacity(0.78)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: body.width))
                Ellipse()
                    .fill(.white.opacity(0.35))
                    .frame(width: body.width * 0.22, height: body.height * 0.16)
                    .offset(x: -body.width * 0.2, y: -body.height * 0.26)
                Ellipse().strokeBorder(.white.opacity(0.45), lineWidth: 1.2)
                VStack(spacing: 1) {
                    if !item.emoji.isEmpty {
                        // 👶 A גן balloon carries ONLY pictures — so when there
                        // is no word under them they get the whole balloon, and
                        // a row of three apples still has to fit inside it.
                        Text(item.emoji)
                            .font(.system(size: body.width * (item.label.isEmpty ? pictureScale : 0.3)))
                            .lineLimit(1).minimumScaleFactor(0.4)
                            .padding(.horizontal, body.width * 0.1)
                    }
                    if !item.label.isEmpty {
                        Text(MiniGameText.show(item.label))
                            .font(.system(size: item.emoji.isEmpty ? body.width * (item.label.count > 6 ? 0.2 : 0.26) : body.width * 0.15,
                                          weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .lineLimit(2).minimumScaleFactor(0.45)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .mathLTR(MiniGameText.isMath(item.label))
                    }
                }
            }
            .frame(width: body.width, height: body.height)
            .opacity(tried ? 0.75 : 1)
            // Knot + string.
            Triangle()
                .fill(color.opacity(0.9))
                .frame(width: 10, height: 7)
            Rectangle()
                .fill(.white.opacity(0.55))
                .frame(width: 1.2, height: size.height * 0.18 - 7)
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 4)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    BalloonPopView(topic: .sea, onClose: {})
}
