import SwiftUI

/// 🔐 "הַכַּסֶּפֶת" — a secret code of distinct digits 1–9 (3 up to ג׳, 4 from ד׳)
/// that the child **works out**, never guesses (Rani, 2026-10-04, after playing
/// the old Mastermind version: "הכספת זה לא טוב, המשחק הזה הוא סתם ניחושים!
/// תעשה את הכספת שיהיה שכל פתרון מקרב אותך לקוד").
///
/// So solving IS the lock-pick. The loop is: a question appears → the child
/// answers it → **one more clue about the code opens, and stays on screen** in
/// a growing list. The clue set is proven in `VaultGen.round` to leave exactly
/// one possible code, so the vault can always be opened by reasoning alone —
/// and at least one clue is slack, so a child who gets there early opens it
/// with questions to spare and earns more ⭐/💎 for it.
///
/// 🎚️ What scales is the KIND of clue: א׳–ב׳ reads the digits off the clues
/// ("הַסִּפְרָה הָרִאשׁוֹנָה הִיא 3"), ג׳–ד׳ compares and counts, ה׳–ו׳ gets
/// arithmetic relations between positions, ז׳–ח׳ gets fewer and tighter ones
/// (sums, differences, multiples, how many digits are prime). See `VaultClue`.
///
/// A wrong attempt is never the engine and never a failure: the screen simply
/// points at the one revealed clue the attempt disagrees with ("💡 כִּמְעַט!"),
/// which is itself a deduction lesson. There are no colour marks and no limit
/// on attempts.
///
/// The questions and the crack are the answers: from a world's chooser they
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

    /// What the screen is saying under the door. Never a failure — always the
    /// next thing to do.
    private enum Hint: Equatable { case idle, broke(Int), consistent, already, retry }

    @State private var phase: Phase = .intro
    @State private var round = VaultGen.Round(code: [], clues: [], needed: 0)
    /// How many clues are open. The list is shuffled, so these are the first
    /// `revealed` entries of `round.clues`.
    @State private var revealed = 0
    @State private var input: [Int?] = []
    @State private var attempts: [[Int]] = []
    @State private var question: GameItem?
    @State private var hint: Hint = .idle
    /// The clue an attempt just disagreed with — pulsed warm for a moment.
    @State private var flagged: Int?
    @State private var seen: Set<String> = []
    @State private var askedAt = Date()
    @State private var cracked = false
    @State private var shake: CGFloat = 0
    @State private var coins = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?
    @State private var startedAt = Date()

    private var isCompact: Bool { hsc == .compact }
    private var grade: Int { MiniGameLevel.grade(for: mathWorld ? .math : topic) }
    private var digits: Int { round.code.count }
    private var total: Int { round.clues.count }
    /// Clues the child never had to open — the "we worked it out early" bonus.
    private var spare: Int { max(0, total - revealed) }
    /// 🚪 Before the first clue there is no board at all — just the loop and
    /// the opening question. An idle board of locked rows is what Rani could
    /// not read: "זה לא מובן מה אמורים לעשות? איפה השאלה?".
    private var opening: Bool { revealed == 0 && !cracked }
    /// A numbers world asks the lock's own dial exercises as well as its bank.
    private var mathWorld: Bool { topic == nil || [.math, .money, .logic, .gifted].contains(topic!) }
    private var recordTopic: Topic { topic ?? .logic }
    private var full: Bool { !input.isEmpty && input.allSatisfy { $0 != nil } }
    private var firstEmpty: Int? { input.firstIndex { $0 == nil } }
    /// Every clue is open and a couple of attempts have gone by — the gentle
    /// way out, so nobody is ever stuck in front of a closed vault.
    private var offerReveal: Bool { !cracked && revealed >= total && attempts.count >= 2 }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: total > 0 ? "🔑 \(revealed)/\(total)" : "🔐", surprise: surprise)
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
                        title: cracked ? tr("פִּצַּחְתֶּם אֶת הַכַּסֶּפֶת! 🔓") : tr("עֲבוֹדָה יָפָה! 💪"),
                        detail: endDetail,
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד כַּסֶּפֶת 🔁"),
                        onAgain: { start() },
                        onDone: onClose)
                    Spacer()
                }
            }
            // Pin to the top: the VStack hugs its content, and on a tall screen a
            // centred stack dragged the ✕ and the chips into the middle.
            .frame(maxHeight: .infinity, alignment: .top)

            if let item = question, phase == .playing {
                // Tapping outside closes it — the ✕ sits behind this layer, and a
                // child who can't answer must still be able to leave. Nothing is
                // spent by putting a question away; the clue stays locked.
                Color.black.opacity(0.35).ignoresSafeArea().transition(.opacity)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { question = nil } }
                MiniGameQuestionCard(item: item, header: tr("🔑 תְּשׁוּבָה נְכוֹנָה פּוֹתַחַת רֶמֶז!")) { right in
                    answered(item, right: right)
                }
                .padding(.horizontal, AppSpacing.lg)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            StarBurst(count: 16, color: AppColor.starGold, trigger: coins)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if (surprise || earn != nil || inertPreview) && phase == .intro { start() } }
    }

    private var codeText: String { MiniGameText.ltr(round.code.map(String.init).joined()) }

    private var endDetail: String {
        guard cracked else { return tr("הַקּוֹד הָיָה \(codeText) — נְנַסֶּה שׁוּב?") }
        guard spare > 0 else { return tr("פְּתַרְתֶּם אֶת כָּל הָרְמָזִים וּפִצַּחְתֶּם אֶת הַקּוֹד!") }
        return tr("פִּצַּחְתֶּם אֶת הַקּוֹד וְעוֹד נִשְׁאֲרוּ רְמָזִים סְגוּרִים — הַסָּקָה מְשֻׁבַּחַת! 🧠")
    }

    // MARK: - Playing

    @ViewBuilder
    private var playing: some View {
        if opening { openingState } else { board }
    }

    /// 🚪 The first frame of a round: the loop in one line and the question
    /// itself, nothing else. The board only exists once there is a clue to
    /// put on it. (The button is the way back if the child dismisses the
    /// card — normally they never see it, because `start` asks at once.)
    private var openingState: some View {
        VStack(spacing: 18) {
            // The banner stays at the top so the question card — which the
            // ZStack centres — never lands on top of it.
            loopBanner
            if question == nil {
                Text(MiniGameKind.vault.emoji)
                    .font(.system(size: isCompact ? 76 : 110))
                    .float(amplitude: 6)
                    .glow(AppColor.starGold, radius: 14)
                    .padding(.top, 20)
                MiniGameGoldButton(title: tr("🔑 לַשְּׁאֵלָה הָרִאשׁוֹנָה")) { ask() }
                    .frame(maxWidth: isCompact ? 320 : 420)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 560 : 720, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, AppSpacing.lg)
    }

    private var board: some View {
        let slot: CGFloat = isCompact ? (digits >= 4 ? 48 : 56) : 68
        return VStack(spacing: display.isShort ? 7 : 10) {
            loopBanner
            door(slot: slot)
            hintLine
            clueBoard
            if offerReveal {
                MiniGameGlassButton(title: tr("✨ לִפְתֹּחַ אֶת הַכַּסֶּפֶת יַחַד")) { giveTheCode() }
                    .frame(maxWidth: isCompact ? 320 : 420)
            }
            MiniGameNumberPad(keyHeight: display.isShort ? 38 : (isCompact ? 44 : 58)) { press($0) }
                .frame(maxWidth: isCompact ? 320 : 420)
            MiniGameGoldButton(title: tr("פְּתִיחָה 🔓")) { submit() }
                .frame(maxWidth: isCompact ? 320 : 420)
                .opacity(full && !cracked ? 1 : 0.5)
                .disabled(!full || cracked)
        }
        .frame(maxWidth: isCompact ? 600 : 760)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    /// 🧭 The whole game in one line, above everything — three steps with
    /// arrows beat a sentence, and a child who has never seen the vault knows
    /// what the screen is for before reading anything else.
    private var loopBanner: some View {
        Text(tr("🔑 עוֹנִים עַל שְׁאֵלָה ← 💡 נִפְתָּח רֶמֶז ← 🔓 פּוֹתְחִים אֶת הַכַּסֶּפֶת"))
            .font(.system(size: isCompact ? 14 : 18, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12).padding(.vertical, isCompact ? 7 : 10)
            .glassPane(radius: 18, shadow: false)
    }

    /// The vault door: a captioned row of "?" slots, so it reads as the field
    /// the child types the code into and not as decoration, plus the codes
    /// already tried so nobody repeats one by accident.
    private func door(slot: CGFloat) -> some View {
        VStack(spacing: 7) {
            Text(cracked ? tr("הַכַּסֶּפֶת נִפְתְּחָה! 🔓") : tr("🔐 הַקּוֹד הַסּוֹדִי — הַקִּישׁוּ אוֹתוֹ כָּאן"))
                .font(.system(size: isCompact ? 12.5 : 15, weight: .heavy, design: .rounded))
                .foregroundStyle(cracked ? AppColor.successMint : AppColor.starGold)
                .lineLimit(1).minimumScaleFactor(0.65)
            HStack(spacing: 9) {
                ForEach(0..<max(digits, 1), id: \.self) { i in
                    let d = cracked ? round.code[i] : (input.indices.contains(i) ? input[i] : nil)
                    Text(d.map(String.init) ?? "?")
                        .font(.system(size: slot * (d == nil ? 0.46 : 0.52), weight: .black, design: .rounded))
                        .foregroundStyle(cracked ? AppColor.starGold : (d == nil ? .white.opacity(0.45) : .white))
                        .frame(width: slot, height: slot * 1.1)
                        .miniGameTile(cracked ? .correct : (i == firstEmpty ? .picked : .normal),
                                      tint: AppColor.starGold, radius: 16)
                }
            }
            // The code reads in the language's direction, like the number
            // sequences: in Hebrew the FIRST digit is on the right.
            .environment(\.layoutDirection, codeRTL ? .rightToLeft : .leftToRight)
            .modifier(MiniGameShake(animatableData: shake))
            if !attempts.isEmpty { triedStrip }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .glassPane(radius: 22)
    }

    private var codeRTL: Bool { LanguageStore.shared.current.isRightToLeft }

    private var triedStrip: some View {
        HStack(spacing: 6) {
            Text(tr("נִסִּינוּ:"))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.tertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(attempts.enumerated()), id: \.offset) { _, a in
                        Text((codeRTL ? a.reversed() : a).map(String.init).joined())
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .frame(height: 22)
    }

    private var hintLine: some View {
        Text(hintText)
            .font(.system(size: isCompact ? 13 : 15, weight: .heavy, design: .rounded))
            .foregroundStyle(hint == .idle ? GlassInk.secondary : .white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeOut(duration: 0.2), value: hintText)
    }

    private var hintText: String {
        switch hint {
        case .idle:
            if revealed < total {
                return tr("יוֹדְעִים אֶת הַקּוֹד? הַקִּישׁוּ אוֹתוֹ! וְאִם לֹא — פִּתְחוּ עוֹד רֶמֶז")
            }
            return tr("כָּל הָרְמָזִים כָּאן — וְיֵשׁ רַק קוֹד אֶחָד שֶׁמַּתְאִים לְכֻלָּם! 🧠")
        case .broke:
            return tr("💡 כִּמְעַט! הַקּוֹד הַזֶּה לֹא מַסְכִּים עִם הָרֶמֶז הַמְּסֻמָּן")
        case .consistent:
            return tr("✨ מַתְאִים לְכָל הָרְמָזִים שֶׁכָּאן — אֲבָל צָרִיךְ עוֹד רֶמֶז")
        case .already:
            return tr("אֶת הַקּוֹד הַזֶּה כְּבָר נִסִּינוּ — בּוֹאוּ נְנַסֶּה אַחֵר")
        case .retry:
            return tr("💡 כִּמְעַט! אֶפְשָׁר לְבַקֵּשׁ שְׁאֵלָה חֲדָשָׁה")
        }
    }

    /// The clue list — the heart of the screen. The lock's own rule sits on
    /// top, then every clue that is open (the round GIVES the first one or
    /// two, so row ① always holds a real sentence), then the key button right
    /// where the next clue will appear, then the clues still shut — numbered,
    /// so they read as rewards waiting rather than as rows that failed to load.
    private var clueBoard: some View {
        let askRow = revealed < total && !cracked
        return ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 5) {
                    row(badge: "🔐", text: tr("בַּקּוֹד \(digits) סְפָרוֹת שׁוֹנוֹת, מִ־1 עַד 9"),
                        tone: .rule)
                    ForEach(Array(round.clues.enumerated()), id: \.element.id) { i, clue in
                        if i < revealed {
                            row(badge: "\(i + 1)", text: clue.text, tone: flagged == i ? .flagged : .open)
                                .id(i)
                        } else if i == revealed && askRow {
                            nextClueButton
                        } else {
                            lockedRow(i)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(10)
            }
            // Tall enough for the rows it holds and no taller, so the panel
            // visibly GROWS as clues open instead of starting as a sea of
            // glass (an open clue is a taller row than a locked one).
            .frame(maxHeight: CGFloat(revealed + 1 + (askRow ? 1 : 0)) * (isCompact ? 46 : 54)
                            + CGFloat(total - revealed - (askRow ? 1 : 0)) * (isCompact ? 32 : 36) + 24)
            .glassPane(radius: 20)
            .onChangeCompat(of: revealed) { _, v in
                guard v > 0 else { return }
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(v - 1, anchor: .bottom) }
            }
        }
    }

    /// 🔑 The one thing to press — and it sits exactly where the clue it buys
    /// will appear, so "press this" and "that row opens" are the same place.
    private var nextClueButton: some View {
        Button { ask() } label: {
            HStack(spacing: 8) {
                Text("🔑")
                    .font(.system(size: 13))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.white.opacity(0.28)))
                Text(tr("עֲנוּ עַל שְׁאֵלָה וְיִפָּתַח רֶמֶז \(revealed + 1)"))
                    .font(.system(size: isCompact ? 14 : 16.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, isCompact ? 8 : 11)
            .frame(maxWidth: .infinity)
            .glassFill(AppGradient.gold, radius: 13)
        }
        .buttonStyle(.juicy)
    }

    private enum Tone { case rule, open, flagged }

    private func row(badge: String, text: String, tone: Tone) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(badge)
                .font(.system(size: 12.5, weight: .black, design: .rounded))
                .foregroundStyle(tone == .rule ? GlassInk.secondary : .white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(tone == .flagged ? AppColor.almostWarm.opacity(0.9)
                                                           : .white.opacity(tone == .rule ? 0.10 : 0.20)))
            Text(text)
                .font(.system(size: isCompact ? 14 : 16.5, weight: tone == .rule ? .semibold : .heavy, design: .rounded))
                .foregroundStyle(tone == .rule ? GlassInk.secondary : .white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(.white.opacity(tone == .rule ? 0.05 : 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(tone == .flagged ? AppColor.almostWarm : .clear, lineWidth: 2))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// A clue still shut. It carries its NUMBER, so the row reads as "רֶמֶז 3,
    /// waiting for you" and not as a line that failed to load.
    private func lockedRow(_ i: Int) -> some View {
        HStack(spacing: 8) {
            Text("🔒")
                .font(.system(size: 12))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(0.08)))
            Text(tr("רֶמֶז \(i + 1)"))
                .font(.system(size: isCompact ? 13 : 15, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.tertiary)
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.05)))
    }

    // MARK: - Logic

    private func start() {
        // ⚡ A surprise round is a short deduction: three digits, four clues.
        round = VaultGen.round(grade: grade, digits: surprise ? 3 : nil, clues: surprise ? 4 : nil)
        revealed = 0
        input = Array(repeating: nil, count: round.code.count)
        attempts = []
        question = nil
        hint = .idle
        flagged = nil
        seen = []
        cracked = false
        grant = nil
        startedAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
        // 🚪 The round OPENS with a question. The child answers, clue ① flips
        // open, and only then does the board appear — already holding a real
        // sentence, with the loop lived through once. A board of locked rows
        // and no question was the thing Rani could not read.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { ask() }
    }

    private func press(_ k: String) {
        guard phase == .playing, question == nil, !cracked else { return }
        if k == "⌫" {
            if let i = input.indices.last(where: { input[$0] != nil }) { input[i] = nil }
            return
        }
        guard k != ".", let d = Int(k), let slot = firstEmpty else { return }
        // The lock's own two rules, shown at the top of the clue list: every
        // digit is different, and 0 is not one of them.
        guard d != 0, !input.contains(d) else {
            withAnimation(.linear(duration: 0.3)) { shake += 1 }
            Haptic.light()
            return
        }
        input[slot] = d
    }

    private func submit() {
        guard full, phase == .playing, !cracked else { return }
        let guess = input.compactMap { $0 }
        if guess == round.code { crack(); return }
        if attempts.contains(guess) {
            hint = .already
            withAnimation(.linear(duration: 0.3)) { shake += 1 }
            Haptic.light()
            return
        }
        attempts.append(guess)
        // The one piece of feedback a miss gives: WHICH clue it disagrees with.
        if let i = (0..<revealed).first(where: { !round.clues[$0].holds(guess) }) {
            hint = .broke(i)
            flagged = i
        } else {
            hint = .consistent
            flagged = nil
        }
        SoundPlayer.shared.play(.uiTap)
        Haptic.light()
        withAnimation(.linear(duration: 0.3)) { shake += 1 }
        input = Array(repeating: nil, count: round.code.count)
    }

    private func crack() {
        cracked = true
        coins += 1
        SoundPlayer.shared.play(.levelUp)
        Haptic.success()
        MiniGameLedger.record(correct: true, topic: recordTopic,
                              responseMs: Date().timeIntervalSince(startedAt) * 1000,
                              earn: earn, surprise: surprise)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { finish() }
    }

    private func ask() {
        guard revealed < total, question == nil, !cracked else { return }
        let item: GameItem
        if mathWorld && Bool.random() {
            item = VaultGen.dialQuestion(grade: grade)
        } else {
            item = GameContent.card(topic: topic, grade: max(1, profiles.active?.effectiveGrade ?? 2),
                                    avoiding: &seen)
        }
        askedAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { question = item }
    }

    private func answered(_ item: GameItem, right: Bool) {
        MiniGameLedger.record(correct: right, topic: item.topic,
                              responseMs: Date().timeIntervalSince(askedAt) * 1000,
                              earn: earn, surprise: surprise)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { question = nil }
        guard right else {
            // Nothing is lost — the clue stays shut and a new question is a tap
            // away. Before the first clue there is no board to go back to, so
            // the next question comes by itself rather than leaving a bare screen.
            hint = .retry
            if opening { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { ask() } }
            return
        }
        flagged = nil
        hint = .idle
        coins += 1
        SoundPlayer.shared.play(.chestOpen)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { revealed += 1 }
    }

    /// The gentle way out once every clue is open: the code is shown and the
    /// round ends on the clues the child did earn. Never framed as losing.
    private func giveTheCode() {
        guard !cracked, phase == .playing else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { input = round.code.map { Optional($0) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { finish() }
    }

    private func finish() {
        guard phase == .playing else { return }
        // 🧠 Opening it with clues to spare is the big win: every clue the
        // child DIDN'T need is worth double one they did.
        let score = cracked ? 3 + 2 * spare + revealed : revealed
        grant = MiniGameReward.grant(game: "vault", correct: score, starsPer: 2, diamondsPer: 1,
                                     cap: 10, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        if cracked { confetti += 1 }
        AppAnalytics.log("vault_done", ["cracked": cracked ? "1" : "0",
                                        "clues": "\(revealed)/\(total)",
                                        "needed": "\(round.needed)",
                                        "tries": "\(attempts.count)",
                                        "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    VaultGameView(topic: .math, onClose: {})
}
