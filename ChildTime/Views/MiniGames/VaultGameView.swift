import SwiftUI

/// 🔐 "הַכַּסֶּפֶת" — a secret code of distinct digits (3 up to ג׳, 4 from ד׳)
/// and six tries. Each try lights its digits: green = right digit, right
/// place; orange = in the code, another place; plain = not in the code (a
/// small legend says so). A key card opens one digit for a right answer — in
/// the math worlds a clue to work out ("הַסְּפָרָה הָרִאשׁוֹנָה = 3 × 2"), in any
/// other world one of its own questions. Cracked → coins burst; six tries
/// gone → the code is shown, gently, and another vault is one tap away.
///
/// The key questions and the crack are the answers: from a world's chooser
/// they earn screen time like regular answers; a ⚡ surprise round pays ⭐/💎.
struct VaultGameView: View {
    var topic: Topic? = nil
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    private enum Phase { case intro, playing, done }
    private struct Try: Identifiable { let id = UUID(); let digits: [Int]; let marks: [VaultMark] }

    @State private var phase: Phase = .intro
    @State private var code: [Int] = []
    @State private var revealed: Set<Int> = []
    @State private var input: [Int?] = []
    @State private var tries: [Try] = []
    @State private var key: GameItem?
    @State private var keyFor: Int?
    @State private var keysUsed = 0
    @State private var seen: Set<String> = []
    @State private var keyShownAt = Date()
    @State private var cracked = false
    @State private var shake: CGFloat = 0
    @State private var coins = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?
    @State private var startedAt = Date()

    private var isCompact: Bool { hsc == .compact }
    private var grade: Int { MiniGameLevel.grade(for: mathWorld ? .math : topic) }
    private var digits: Int { code.count }
    /// A numbers world: its keys are clues to work out. Any other world: its questions.
    private var mathWorld: Bool { topic == nil || [.math, .money, .logic, .gifted].contains(topic!) }
    private var maxKeys: Int { max(1, digits - 1) }
    private var recordTopic: Topic { topic ?? .logic }
    private var full: Bool { !input.isEmpty && input.allSatisfy { $0 != nil } }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "🔐 \(min(tries.count + 1, VaultGen.maxTries))/\(VaultGen.maxTries)", surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    MiniGameIntroCard(kind: .vault) { start() }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    MiniGameEndCard(
                        title: cracked ? tr("פִּצַּחְתֶּם אֶת הַכַּסֶּפֶת! 🔓") : tr("כִּמְעַט! 💪"),
                        detail: cracked
                            ? (tries.count == 1 ? tr("בְּנִסָּיוֹן אֶחָד!") : tr("בְּ־\(tries.count) נִסְיוֹנוֹת"))
                            : tr("הַקּוֹד הָיָה \(codeText) — נְנַסֶּה שׁוּב?"),
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד כַּסֶּפֶת 🔁"),
                        onAgain: { start() },
                        onDone: onClose)
                    Spacer()
                }
            }

            if let item = key, phase == .playing {
                Color.black.opacity(0.35).ignoresSafeArea().transition(.opacity)
                MiniGameQuestionCard(item: item, header: tr("🔑 תְּשׁוּבָה נְכוֹנָה פּוֹתַחַת סִפְרָה!")) { right in
                    answerKey(item, right: right)
                }
                .padding(.horizontal, AppSpacing.lg)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            StarBurst(count: 16, color: AppColor.starGold, trigger: coins)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if surprise && phase == .intro { start() } }
    }

    private var codeText: String { MiniGameText.ltr(code.map(String.init).joined()) }

    // MARK: - Playing

    private var playing: some View {
        let slot: CGFloat = isCompact ? (digits >= 4 ? 52 : 58) : 74
        return VStack(spacing: display.isShort ? 8 : 12) {
            if !isCompact && !display.isShort { Spacer(minLength: 0) }
            // The vault door: the code, closed digits as 🔒, opened ones gold.
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(0..<digits, id: \.self) { i in
                        let open = revealed.contains(i) || cracked
                        Text(open ? "\(code[i])" : "🔒")
                            .font(.system(size: slot * (open ? 0.5 : 0.36), weight: .black, design: .rounded))
                            .foregroundStyle(open ? AppColor.starGold : .white)
                            .frame(width: slot, height: slot * 1.1)
                            .miniGameTile(open ? .picked : .normal, tint: AppColor.starGold, radius: 16)
                            .scaleEffect(open ? 1.04 : 1)
                            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: open)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                if keysUsed < maxKeys && !cracked {
                    Button { askKey() } label: {
                        Text(tr("🔑 מַפְתֵּחַ — פּוֹתְחִים סִפְרָה (\(maxKeys - keysUsed))"))
                            .font(.system(size: isCompact ? 15 : 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .glassFill(AppGradient.gold, radius: 18)
                    }
                    .buttonStyle(.juicy)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .glassPane(radius: 24)

            legend

            // The tries so far, newest at the bottom, then the one being typed.
            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(tries) { t in tryRow(t.digits.map { Optional($0) }, marks: t.marks, slot: slot * 0.72) }
                    tryRow(input, marks: nil, slot: slot * 0.72)
                        .modifier(MiniGameShake(animatableData: shake))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: isCompact ? 200 : 320)
            .scrollAnchorBottom()

            MiniGameNumberPad(keyHeight: display.isShort ? 40 : (isCompact ? 46 : 60)) { k in press(k) }
                .frame(maxWidth: isCompact ? 320 : 420)
            MiniGameGoldButton(title: tr("פְּתִיחָה 🔓")) { submit() }
                .frame(maxWidth: isCompact ? 320 : 420)
                .opacity(full ? 1 : 0.5)
                .disabled(!full)
            if !isCompact && !display.isShort { Spacer(minLength: 0) }
        }
        .frame(maxWidth: isCompact ? 600 : 760)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(AppColor.successMint, tr("בַּמָּקוֹם הַנָּכוֹן"))
            legendItem(AppColor.almostWarm, tr("בַּקּוֹד, בְּמָקוֹם אַחֵר"))
            legendItem(.white.opacity(0.25), tr("לֹא בַּקּוֹד"))
        }
        .font(.system(size: isCompact ? 11.5 : 14, weight: .semibold, design: .rounded))
        .foregroundStyle(GlassInk.secondary)
        .lineLimit(1).minimumScaleFactor(0.7)
    }

    private func legendItem(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 10, height: 10)
            Text(s)
        }
    }

    private func tryRow(_ ds: [Int?], marks: [VaultMark]?, slot: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(ds.enumerated()), id: \.offset) { i, d in
                let mark = marks?[i]
                let fill: Color = {
                    switch mark {
                    case .exact?:   return AppColor.successMint.opacity(0.75)
                    case .present?: return AppColor.almostWarm.opacity(0.8)
                    case .absent?:  return .white.opacity(0.08)
                    case nil:       return .white.opacity(0.14)
                    }
                }()
                Text(d.map(String.init) ?? "")
                    .font(.system(size: slot * 0.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(mark == .absent ? 0.6 : 1))
                    .frame(width: slot, height: slot)
                    .background(RoundedRectangle(cornerRadius: slot * 0.24, style: .continuous).fill(fill))
                    .overlay(RoundedRectangle(cornerRadius: slot * 0.24, style: .continuous)
                        .strokeBorder(marks == nil && i == firstEmpty ? AppColor.starGold : .white.opacity(0.25),
                                      lineWidth: marks == nil && i == firstEmpty ? 2 : 1))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var firstEmpty: Int? { input.firstIndex { $0 == nil } }

    // MARK: - Logic

    private func start() {
        code = VaultGen.code(grade: grade)
        revealed = []; tries = []; keysUsed = 0; cracked = false; key = nil; keyFor = nil; grant = nil
        input = Array(repeating: nil, count: code.count)
        startedAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    /// Opened digits sit in the typed row already.
    private func refill() {
        for i in revealed where input.indices.contains(i) { input[i] = code[i] }
    }

    private func press(_ k: String) {
        guard phase == .playing, key == nil, !cracked else { return }
        if k == "⌫" {
            if let i = input.indices.last(where: { input[$0] != nil && !revealed.contains($0) }) { input[i] = nil }
            return
        }
        guard k != ".", let d = Int(k), let slot = firstEmpty else { return }
        // Every digit in the code is different — the same one twice can't fit.
        if input.contains(d) {
            withAnimation(.linear(duration: 0.3)) { shake += 1 }
            Haptic.light()
            return
        }
        input[slot] = d
    }

    private func submit() {
        guard full, phase == .playing, !cracked else { return }
        let guess = input.compactMap { $0 }
        let marks = VaultGen.feedback(guess: guess, code: code)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { tries.append(Try(digits: guess, marks: marks)) }
        if guess == code {
            cracked = true
            coins += 1
            SoundPlayer.shared.play(.levelUp)
            Haptic.success()
            MiniGameLedger.record(correct: true, topic: recordTopic, responseMs: Date().timeIntervalSince(startedAt) * 1000,
                                  earn: earn, surprise: surprise)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { finish() }
            return
        }
        SoundPlayer.shared.play(marks.contains(.exact) ? .correctSmall : .uiTap)
        Haptic.light()
        input = Array(repeating: nil, count: code.count)
        refill()
        if tries.count >= VaultGen.maxTries {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { finish() }
        }
    }

    private func askKey() {
        guard keysUsed < maxKeys, key == nil else { return }
        let closed = (0..<digits).filter { !revealed.contains($0) }
        guard let pos = closed.randomElement() else { return }
        keyFor = pos
        let item: GameItem
        if mathWorld {
            item = VaultGen.clue(code: code, position: pos, grade: grade)
        } else {
            item = GameContent.card(topic: topic, grade: max(1, profiles.active?.effectiveGrade ?? 2), avoiding: &seen)
        }
        keysUsed += 1
        keyShownAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { key = item }
    }

    private func answerKey(_ item: GameItem, right: Bool) {
        MiniGameLedger.record(correct: right, topic: mathWorld ? (topic ?? .math) : item.topic,
                              responseMs: Date().timeIntervalSince(keyShownAt) * 1000, earn: earn, surprise: surprise)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { key = nil }
        if right, let pos = keyFor {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { _ = revealed.insert(pos) }
            refill()
            coins += 1
        } else {
            // No digit this time — the key comes back (it wasn't used up).
            keysUsed = max(0, keysUsed - 1)
        }
        keyFor = nil
    }

    private func finish() {
        guard phase == .playing else { return }
        let left = cracked ? VaultGen.maxTries - tries.count + 1 : 0
        grant = MiniGameReward.grant(game: "vault", correct: cracked ? 2 + left : revealed.count, starsPer: 2, diamondsPer: 1,
                                     cap: 8, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        if cracked { confetti += 1 }
        AppAnalytics.log("vault_done", ["cracked": cracked ? "1" : "0", "tries": "\(tries.count)", "keys": "\(keysUsed)",
                                        "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    VaultGameView(topic: .math, onClose: {})
}
