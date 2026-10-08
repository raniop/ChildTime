import SwiftUI

/// 🔐 "הַכַּסֶּפֶת" — a safe with three dials. Every right answer turns the next
/// dial onto its digit with a click; three dials and the door swings open on
/// the treasure.
///
/// Rani, 2026-10-07: "משחק הכספת הוא מסובך מידי! ולא מובן". The version before
/// this one opened a CLUE per answer ("הַסִּפְרָה הָרִאשׁוֹנָה גְּדוֹלָה מֵהַשְּׁנִיָּה")
/// and asked the child to deduce the code from all of them — a logic puzzle
/// stacked on top of the questions, two games at once. Now the loop is one
/// line: a question → a dial → the next question.
///
/// 🎚️ From ה׳ the dial does not set itself: a small exercise whose answer IS
/// the digit appears ("3 × 3 − 2"), and the child turns the dial by tapping
/// that digit. Still one question = one digit, with a little thinking in it.
///
/// A miss is never a failure: the dial simply stays where it is and the next
/// question comes. The questions are the answers: from a world's chooser they
/// earn screen time like regular answers; a ⚡ surprise round pays ⭐/💎.
struct VaultGameView: View {
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

    /// Three dials for every grade — the safe reads the same at every age;
    /// what grows with the grade is the exercise behind each digit.
    static let dials = 3

    /// 📏 DEMO_AUTOTAP (DEBUG): the round plays itself, for screenshots.
    #if DEBUG
    static var autoPlay: Bool { ProcessInfo.processInfo.environment["DEMO_AUTOTAP"] != nil }
    #else
    static let autoPlay = false
    #endif

    @State private var phase: Phase = .intro
    @State private var code: [Int] = []
    /// How many dials are set, left to right in the reading direction.
    @State private var opened = 0
    @State private var question: GameItem?
    /// ה׳+: the exercise for the dial just earned; the child taps its answer.
    @State private var riddle: String?
    @State private var riddleMiss = false
    @State private var missNote = false
    /// The next question is already on its way (after a dial or a miss) —
    /// the "next question" button is only for a child who put one away.
    @State private var nextPending = false
    @State private var seen: Set<String> = []
    @State private var askedAt = Date()
    @State private var cracked = false
    @State private var doorOpen = false
    @State private var shake: CGFloat = 0
    @State private var coins = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?
    @State private var startedAt = Date()

    private var isCompact: Bool { hsc == .compact }
    private var grade: Int { MiniGameLevel.grade(for: mathWorld ? .math : topic) }
    /// ה׳ and up work the digit out themselves.
    private var solvesDigits: Bool { grade >= 5 }
    /// A numbers world asks the lock's own dial exercises as well as its bank.
    private var mathWorld: Bool { topic == nil || [.math, .money, .logic, .gifted].contains(topic!) }
    private var recordTopic: Topic { topic ?? .logic }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: code.isEmpty ? "🔐" : "🔐 \(opened)/\(Self.dials)", surprise: surprise)
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
                        title: tr("פְּתַחְתֶּם אֶת הַכַּסֶּפֶת! 🔓"),
                        detail: tr("שָׁלֹשׁ תְּשׁוּבוֹת נְכוֹנוֹת — וְהָאוֹצָר שֶׁלָּכֶם! 💎"),
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד כַּסֶּפֶת 🔁"),
                        onAgain: { start() },
                        onDone: onClose)
                    Spacer()
                }
            }
            // Pin to the top: on a tall screen a centred stack dragged the ✕ and
            // the chips into the middle.
            .frame(maxHeight: .infinity, alignment: .top)

            if let item = question, phase == .playing {
                // Tapping outside puts the question away — a child who can't
                // answer must still be able to reach the ✕. Nothing is lost.
                Color.black.opacity(0.35).ignoresSafeArea().transition(.opacity)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { question = nil } }
                MiniGameQuestionCard(item: item, header: tr("🔑 תְּשׁוּבָה נְכוֹנָה מְסוֹבֶבֶת גַּלְגַּל!")) { right in
                    answered(item, right: right)
                }
                .padding(.horizontal, AppSpacing.lg)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            StarBurst(count: 16, color: AppColor.starGold, trigger: coins)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if (surprise || earn != nil || inertPreview || Self.autoPlay) && phase == .intro { start() } }
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: display.isShort ? 10 : 16) {
            loopLine
            safe
            if let riddle { riddlePanel(riddle) }
            else if !cracked && question == nil && !nextPending {
                // The way back to the question if the child put it away.
                MiniGameGoldButton(title: tr("🔑 לַשְּׁאֵלָה הַבָּאָה")) { ask() }
                    .frame(maxWidth: isCompact ? 320 : 420)
            }
            if missNote && riddle == nil && !cracked {
                Text(tr("לֹא נוֹרָא! הַגַּלְגַּל מְחַכֶּה לַשְּׁאֵלָה הַבָּאָה 💪"))
                    .font(.system(size: isCompact ? 14 : 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 560 : 680, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, AppSpacing.lg)
    }

    /// 🧭 The whole game in one line.
    private var loopLine: some View {
        Text(tr("🔑 עוֹנִים נָכוֹן ← 🎡 גַּלְגַּל מִסְתּוֹבֵב ← 🔓 הַכַּסֶּפֶת נִפְתַּחַת"))
            .font(.system(size: isCompact ? 14 : 18, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12).padding(.vertical, isCompact ? 7 : 10)
            .glassPane(radius: 16, shadow: false)
    }

    /// The safe: a steel door with the three dials and a handle. When the last
    /// dial clicks in, the door swings open on the treasure behind it.
    private var safe: some View {
        let dial: CGFloat = isCompact ? 76 : 104
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return ZStack {
            // Behind the door: the treasure.
            shape.fill(LinearGradient(colors: [Color(hex: "2A1F5C"), Color(hex: "1A1240")],
                                      startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text("💎⭐💰")
                        .font(.system(size: isCompact ? 46 : 62))
                        .scaleEffect(doorOpen ? 1 : 0.6)
                        .opacity(doorOpen ? 1 : 0)
                )
            // The door.
            VStack(spacing: isCompact ? 14 : 20) {
                HStack(spacing: isCompact ? 12 : 18) {
                    ForEach(0..<Self.dials, id: \.self) { i in dialView(i, size: dial) }
                }
                // A number reads left to right in every language (Rani): the
                // first dial is on the LEFT, in Hebrew as in English.
                .environment(\.layoutDirection, .leftToRight)
                .modifier(MiniGameShake(animatableData: shake))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "E9E4FF"), Color(hex: "9A93C9")],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: isCompact ? 90 : 120, height: 14)
                    .rotationEffect(.degrees(cracked ? -35 : 0))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            }
            .padding(.vertical, isCompact ? 26 : 34)
            .frame(maxWidth: .infinity)
            .background(shape.fill(LinearGradient(colors: [Color(hex: "8E86C9"), Color(hex: "5B5196")],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(shape.strokeBorder(.white.opacity(0.4), lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            .rotation3DEffect(.degrees(doorOpen ? -75 : 0),
                              axis: (x: 0, y: 1, z: 0),
                              anchor: .leading,
                              perspective: 0.5)
        }
        .frame(height: dial * 1.25 + (isCompact ? 80 : 110))
    }

    private func dialView(_ i: Int, size: CGFloat) -> some View {
        let set = i < opened
        let next = i == opened && !cracked
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "FFFFFF").opacity(set ? 0.95 : 0.35),
                                              Color(hex: "C9C3F0").opacity(set ? 0.9 : 0.2)],
                                     center: .topLeading, startRadius: 2, endRadius: size))
            Circle().strokeBorder(set ? AppColor.starGold : .white.opacity(next ? 0.9 : 0.4),
                                  lineWidth: set || next ? 3 : 1.5)
            if set, code.indices.contains(i) {
                Text("\(code[i])")
                    .font(.system(size: size * 0.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "3B2F86"))
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity))
                    .id("d\(i)-\(code[i])")
            } else {
                Text("?")
                    .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(next ? 0.85 : 0.45))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .rotationEffect(.degrees(set ? 360 : 0))
        .glow(set ? AppColor.starGold : (next ? .white : .clear), radius: set || next ? 10 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.7), value: opened)
    }

    /// ה׳+: the exercise for the dial just earned, and the nine digits.
    private func riddlePanel(_ text: String) -> some View {
        VStack(spacing: 10) {
            Text(tr("🎡 סוֹבְבוּ אֶת הַגַּלְגַּל לַתְּשׁוּבָה:"))
                .font(.system(size: isCompact ? 14 : 17, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
            Text(MiniGameText.ltr(text + " = ?"))
                .font(.system(size: isCompact ? 26 : 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...9, id: \.self) { d in
                    Button { pickDigit(d) } label: {
                        Text("\(d)")
                            .font(.system(size: isCompact ? 22 : 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: isCompact ? 44 : 56)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
                    }
                    .buttonStyle(.juicy)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .frame(maxWidth: isCompact ? 300 : 380)
            if riddleMiss {
                Text(tr("כִּמְעַט! בִּדְקוּ שׁוּב אֶת הַתַּרְגִּיל 🔍"))
                    .font(.system(size: isCompact ? 13.5 : 15.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glassPane(radius: 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Logic

    private func start() {
        code = Array((1...9).shuffled().prefix(Self.dials))
        opened = 0
        question = nil
        riddle = nil
        riddleMiss = false
        missNote = false
        nextPending = true   // `start` asks the first question itself
        seen = []
        cracked = false
        doorOpen = false
        grant = nil
        startedAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
        // The round opens with a question: the loop is lived, not explained.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { ask() }
    }

    private func ask() {
        nextPending = false
        guard phase == .playing, opened < Self.dials, question == nil, riddle == nil, !cracked else { return }
        let item: GameItem
        if mathWorld && Bool.random() {
            item = VaultGen.dialQuestion(grade: grade)
        } else {
            item = GameContent.card(topic: topic, grade: max(1, profiles.active?.effectiveGrade ?? 2),
                                    avoiding: &seen)
        }
        askedAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { question = item }
        #if DEBUG
        // 📏 DEMO_AUTOTAP: play the round by itself (screenshots / flow checks).
        if ProcessInfo.processInfo.environment["DEMO_AUTOTAP"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                answered(item, right: true)
                if riddle != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { pickDigit(code[opened]) }
                }
            }
        }
        #endif
    }

    private func answered(_ item: GameItem, right: Bool) {
        MiniGameLedger.record(correct: right, topic: item.topic,
                              responseMs: Date().timeIntervalSince(askedAt) * 1000,
                              earn: earn, surprise: surprise)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { question = nil }
        guard right else {
            // The dial just stays put; the next question comes by itself.
            withAnimation(.easeOut(duration: 0.2)) { missNote = true }
            nextPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { ask() }
            return
        }
        withAnimation(.easeOut(duration: 0.2)) { missNote = false }
        coins += 1
        if solvesDigits {
            // ה׳+: the digit hides in an exercise; the child turns the dial.
            riddleMiss = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                riddle = VaultGen.expression(for: code[opened], grade: grade)
            }
        } else {
            turnDial()
        }
    }

    private func pickDigit(_ d: Int) {
        guard riddle != nil, opened < code.count else { return }
        guard d == code[opened] else {
            Haptic.light()
            withAnimation(.linear(duration: 0.3)) { shake += 1 }
            withAnimation(.easeOut(duration: 0.2)) { riddleMiss = true }
            return
        }
        withAnimation(.easeOut(duration: 0.2)) { riddle = nil; riddleMiss = false }
        turnDial()
    }

    /// Click — the next dial lands on its digit.
    private func turnDial() {
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        opened += 1
        if opened >= Self.dials {
            crack()
        } else {
            nextPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { ask() }
        }
    }

    private func crack() {
        cracked = true
        SoundPlayer.shared.play(.levelUp)
        MiniGameLedger.record(correct: true, topic: recordTopic,
                              responseMs: Date().timeIntervalSince(startedAt) * 1000,
                              earn: earn, surprise: surprise)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) { doorOpen = true }
            confetti += 1
            coins += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { finish() }
    }

    private func finish() {
        guard phase == .playing else { return }
        grant = MiniGameReward.grant(game: "vault", correct: 3 + opened, starsPer: 2, diamondsPer: 1,
                                     cap: 10, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        Haptic.success()
        AppAnalytics.log("vault_done", ["dials": "\(opened)", "solved": solvesDigits ? "1" : "0",
                                        "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    VaultGameView(topic: .math, onClose: {})
}
