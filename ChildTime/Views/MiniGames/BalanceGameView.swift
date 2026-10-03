import SwiftUI

/// ⚖️ "מֹאזְנַיִם" — two pans on a beam: "7 + 5" on one, "8 + ?" on the other.
/// The beam leans toward the heavier side; pick the missing value (a number
/// pad from ו׳) and the beam swings to it — level when it's right, still
/// leaning when it isn't, so a miss itself says "more" or "less". From
/// "7 + ? | 10" in א׳ to "3x + 2 | 14" and "2x − 5 | x + 3" in ז׳–ח׳, with
/// fractions and decimals on the way. Five per round.
///
/// A world whose questions have numbers for answers ("כַּמָּה רַגְלַיִם…?") plays
/// it as a comparison: "?" against a 🎁 of the right weight.
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser every
/// balance found first time earns screen time like a regular answer.
struct BalanceGameView: View {
    var topic: Topic? = nil
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    private enum Phase { case intro, playing, done }

    @State private var phase: Phase = .intro
    @State private var puzzle: BalancePuzzle?
    @State private var index = 0
    @State private var trial: String?
    @State private var wrongPicks: Set<String> = []
    @State private var solved = false
    @State private var missed = false
    @State private var clean = 0
    @State private var typed = ""
    @State private var bank: [GameItem] = []
    @State private var shake: CGFloat = 0
    @State private var shownAt = Date()
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?

    private var isCompact: Bool { hsc == .compact }
    private var count: Int { surprise ? 4 : BalanceGen.roundCount }
    private var numbersWorld: Bool { topic == nil || [.math, .money, .logic, .gifted].contains(topic!) }
    private var grade: Int { MiniGameLevel.grade(for: numbersWorld ? (topic ?? .math) : topic) }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "⚖️ \(min(index + 1, count))/\(count)", surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    MiniGameIntroCard(kind: .balance) { start() }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    MiniGameEndCard(
                        title: clean == count ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: tr("אִזַּנְתֶּם \(count) מֹאזְנַיִם!"),
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד סִבּוּב 🔁"),
                        onAgain: { start() },
                        onDone: onClose)
                    Spacer()
                }
            }

            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if surprise && phase == .intro { start() } }
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            VStack(spacing: 8) {
                Text(tr("מָה מֵבִיא אֶת הַמֹּאזְנַיִם לְאִזּוּן?"))
                    .font(.system(size: isCompact ? 15 : 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                if let q = puzzle?.question {
                    Text(MiniGameText.show(q))
                        .font(.system(size: isCompact ? 21 : 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .glassPane(radius: 22)

            Spacer(minLength: 0)
            scale
                .frame(height: display.isShort ? 190 : (isCompact ? 240 : 340))
                .modifier(MiniGameShake(animatableData: shake))
            Spacer(minLength: 0)

            if puzzle?.numberPad == true {
                MiniGameAnswerWell(text: typed, state: solved ? .correct : (trial != nil && !solved ? .wrong : .normal),
                                   height: isCompact ? 56 : 70)
                MiniGameNumberPad(keyHeight: display.isShort ? 38 : (isCompact ? 44 : 58)) { k in press(k) }
                    .frame(maxWidth: isCompact ? 320 : 420)
                MiniGameGoldButton(title: tr("בְּדִיקָה ✓")) { try_(typed) }
                    .frame(maxWidth: isCompact ? 320 : 420)
                    .opacity(typed.isEmpty ? 0.5 : 1)
                    .disabled(typed.isEmpty || solved)
            } else {
                chips
            }
        }
        .frame(maxWidth: isCompact ? 640 : 820)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
        .id(index)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private var chips: some View {
        let opts = puzzle?.options ?? []
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 2 : 4), spacing: 12) {
            ForEach(Array(opts.enumerated()), id: \.element) { i, opt in
                let state: MiniGameTileState = solved && opt == puzzle?.answer ? .correct : (wrongPicks.contains(opt) ? .wrong : .normal)
                Button { try_(opt) } label: {
                    Text(MiniGameText.ltr(opt))
                        .font(.system(size: isCompact ? 30 : 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, minHeight: isCompact ? 70 : 100)
                        .miniGameTile(state, tint: OptionCard.tints[i % OptionCard.tints.count], radius: 22)
                        .mathLTR()
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
                }
                .buttonStyle(.juicy)
                .disabled(solved || wrongPicks.contains(opt))
            }
        }
    }

    // MARK: - The scale

    /// Degrees, clockwise: the heavier pan goes down.
    private var tilt: Double {
        guard let p = puzzle else { return 0 }
        let v = trial.flatMap { p.value($0) } ?? 0
        let w = p.weigh(v)
        let diff = w.right - w.left
        guard abs(diff) > 0.0001 else { return 0 }
        let rel = abs(diff) / max(1, max(abs(w.left), abs(w.right)))
        return (diff > 0 ? 1 : -1) * min(14, 5 + 12 * rel)
    }

    private var scale: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let pivot = CGPoint(x: w / 2, y: h * 0.22)
            let arm = min(w * 0.36, 300)
            let a = tilt * .pi / 180
            let leftEnd = CGPoint(x: pivot.x - arm * cos(a), y: pivot.y - arm * sin(a))
            let rightEnd = CGPoint(x: pivot.x + arm * cos(a), y: pivot.y + arm * sin(a))
            let string = h * 0.26
            let panW = min(w * 0.4, 260)
            ZStack {
                // Stand.
                Path { p in
                    p.move(to: CGPoint(x: pivot.x, y: pivot.y))
                    p.addLine(to: CGPoint(x: pivot.x, y: h * 0.92))
                }
                .stroke(.white.opacity(0.55), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                Capsule().fill(.white.opacity(0.35))
                    .frame(width: w * 0.32, height: 12)
                    .position(x: pivot.x, y: h * 0.93)
                // Strings.
                Path { p in
                    p.move(to: leftEnd); p.addLine(to: CGPoint(x: leftEnd.x, y: leftEnd.y + string))
                    p.move(to: rightEnd); p.addLine(to: CGPoint(x: rightEnd.x, y: rightEnd.y + string))
                }
                .stroke(.white.opacity(0.5), lineWidth: 1.5)
                // Beam.
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "FFD23F"), Color(hex: "FF9F1C")], startPoint: .top, endPoint: .bottom))
                    .frame(width: arm * 2 + 24, height: 12)
                    .rotationEffect(.degrees(tilt))
                    .position(pivot)
                    .glow(solved ? AppColor.successMint : AppColor.starGold, radius: solved ? 14 : 6)
                Circle().fill(.white).frame(width: 16, height: 16).position(pivot)
                // Pans.
                pan(puzzle?.left ?? "", width: panW).position(x: leftEnd.x, y: leftEnd.y + string + 30)
                pan(puzzle?.right ?? "", width: panW).position(x: rightEnd.x, y: rightEnd.y + string + 30)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.55), value: tilt)
        }
        // Geometry, not text: left stays left in every language.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func pan(_ text: String, width: CGFloat) -> some View {
        // "?" is filled in when found; an equation's x keeps its letter and
        // shows "x = 4" underneath.
        let isX = !text.contains("?") && text.contains("x")
        let hasHole = text.contains("?") || isX
        let mark = isX ? "x" : "?"
        let shown = text.contains("?") && solved ? text.replacingOccurrences(of: "?", with: puzzle?.answer ?? "?") : text
        return VStack(spacing: 4) {
            Text(MiniGameText.ltr(shown))
                .font(.system(size: isCompact ? 26 : 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: width)
                .miniGameTile(hasHole ? (solved ? .correct : .picked) : .normal, tint: AppColor.starGold, radius: 18)
            // The bowl.
            UnevenRoundedPan()
                .fill(.white.opacity(0.22))
                .overlay(UnevenRoundedPan().stroke(.white.opacity(0.4), lineWidth: 1))
                .frame(width: width * 0.9, height: 14)
            if hasHole, let t = trial, !solved {
                Text(MiniGameText.ltr(mark + " = " + t))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.almostWarm)
            } else if isX, solved {
                Text(MiniGameText.ltr("x = " + (puzzle?.answer ?? "")))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(AppColor.successMint)
            }
        }
    }

    // MARK: - Logic

    private func start() {
        index = 0; clean = 0; grant = nil
        bank = numbersWorld ? [] : (topic.map { GameContent.numericItems(topic: $0, grade: grade) } ?? [])
        load()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    private func load() {
        if !numbersWorld, !bank.isEmpty {
            let item = bank[index % bank.count]
            puzzle = BalanceGen.compare(item) ?? BalanceGen.make(grade: grade, topic: .math)
        } else {
            puzzle = BalanceGen.make(grade: grade, topic: topic ?? .math)
        }
        trial = nil; wrongPicks = []; solved = false; missed = false; typed = ""; shownAt = Date()
    }

    private func press(_ k: String) {
        guard !solved else { return }
        if k == "⌫" { if !typed.isEmpty { typed.removeLast() }; return }
        guard k != ".", typed.count < 4 else { return }
        typed += k
        trial = nil
    }

    private func try_(_ opt: String) {
        guard phase == .playing, !solved, let p = puzzle, let v = p.value(opt) else { return }
        let target = p.value(p.answer) ?? .nan
        let right = abs(v - target) < 0.0001
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { trial = opt }
        if right {
            solved = true
            if !missed {
                clean += 1
                MiniGameLedger.record(correct: true, topic: p.topic, responseMs: Date().timeIntervalSince(shownAt) * 1000,
                                      streak: clean, earn: earn, surprise: surprise)
            }
            burst += 1
            SoundPlayer.shared.play(.correctBig)
            Haptic.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
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
                MiniGameLedger.record(correct: false, topic: p.topic, earn: earn, surprise: surprise)
            }
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { _ = wrongPicks.insert(opt) }
            if p.numberPad { typed = "" }
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        grant = MiniGameReward.grant(game: "balance", correct: clean, starsPer: 2, diamondsPer: 1,
                                     cap: BalanceGen.roundCount, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        confetti += 1
        AppAnalytics.log("balance_done", ["clean": "\(clean)", "surprise": surprise ? "1" : "0"])
    }
}

/// A shallow bowl under each pan.
private struct UnevenRoundedPan: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        p.closeSubpath()
        return p
    }
}

#Preview {
    BalanceGameView(topic: .math, onClose: {})
}
