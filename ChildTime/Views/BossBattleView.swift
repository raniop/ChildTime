import SwiftUI

/// "קְרַב בּוֹס" — the finale of a world. The world's emoji becomes a friendly
/// boss with a hearts bar; each correct (harder) answer lands a hit. The kid has
/// 3 hearts — a wrong answer costs one, but losing isn't failure: it's "almost,
/// let's try again" (keeping the safe, recoverable feel). Winning is a big,
/// celebrated reward moment.
struct BossBattleView: View {
    let world: World
    var onClose: () -> Void

    @ObservedObject private var progress = ProgressStore.shared

    private let bossMaxHP = 5
    private let startHearts = 3

    private enum Phase { case fighting, won, lost }

    @State private var phase: Phase = .fighting
    @State private var bossHP = 5
    @State private var hearts = 3
    @State private var question: Question?
    @State private var picked: Int? = nil
    @State private var locked = false
    @State private var bossHit = false
    @State private var shake = false
    @State private var burst = 0
    @State private var confetti = 0
    @State private var earnedMinutes = 0
    @State private var revealStep = 0
    @State private var shownAt = Date()
    /// What this win actually paid (a same-day replay pays less — the pills
    /// used to show the full 20⭐ 30💎 either way).
    @State private var wonStars = 0
    @State private var wonDiamonds = 0
    /// 🏆 The tier this win completed (0 bronze…2 gold), nil on a replay.
    @State private var completedTier: Int?
    @State private var suggested: World?

    var body: some View {
        ZStack {
            world.gradient.gradient.ignoresSafeArea()
            SparkleField(count: 20, size: 13)

            switch phase {
            case .fighting: fighting
            case .won:      result(win: true)
            case .lost:     result(win: false)
            }

            StarBurst(count: 14, color: AppColor.starGold, trigger: burst)
            FancyConfetti(trigger: confetti)

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.18)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(20)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if question == nil { newQuestion() } }
    }

    // MARK: - Fighting

    private var fighting: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 40)

            // Boss + HP
            VStack(spacing: 10) {
                Text(world.emoji)
                    .font(.system(size: 92))
                    .scaleEffect(bossHit ? 1.18 : 1)
                    .rotationEffect(.degrees(bossHit ? -8 : 0))
                    .shadow(color: world.glowColor.opacity(0.8), radius: 24)
                Text(tr("הַבּוֹס שֶׁל \(world.name)"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                heartsRow(count: bossMaxHP, filled: bossHP, color: Color(hex: "EF476F"), symbol: "bolt.heart.fill")
            }

            Spacer()

            if let q = question {
                // 📖 Reading-world boss: the passage scrolls above the question.
                if let passage = q.passage {
                    ScrollView {
                        Text(passage)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(maxHeight: 150)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 18)
                }
                Text(q.prompt)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .modifier(Shake(animatableData: shake ? 1 : 0))

                VStack(spacing: 10) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                        answerButton(idx: idx, text: opt, correct: idx == q.correctIndex)
                    }
                }
                .padding(.horizontal, 18)
            }

            Spacer()

            // Player hearts
            HStack(spacing: 8) {
                Text(Gendered.g(tr("הַלְּבָבוֹת שֶׁלְּךָ:"), tr("הַלְּבָבוֹת שֶׁלָּךְ:"))).font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                heartsRow(count: startHearts, filled: hearts, color: Color(hex: "FF5E78"), symbol: "heart.fill")
            }
            .padding(.bottom, 24)
        }
    }

    private func heartsRow(count: Int, filled: Int, color: Color, symbol: String) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(i < filled ? color : Color.white.opacity(0.22))
            }
        }
    }

    private func answerButton(idx: Int, text: String, correct: Bool) -> some View {
        let show = picked != nil
        let isPicked = picked == idx
        let bg: Color = show && correct ? AppColor.successMint
            : (show && isPicked && !correct ? Color(hex: "EF476F") : Color.white.opacity(0.14))
        return Button { pick(idx) } label: {
            Text(text)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.juicy)
        .disabled(locked)
    }

    // MARK: - Result

    private func result(win: Bool) -> some View {
        VStack(spacing: 18) {
            CharacterView(character: Character3DCatalog.find("lion"))
                .frame(width: 130, height: 130)
            Text(win ? winTitle : Gendered.g(tr("כִּמְעַט! בּוֹא נְנַסֶּה שׁוּב 💪"), tr("כִּמְעַט! בּוֹאִי נְנַסֶּה שׁוּב 💪")))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).multilineTextAlignment(.center)
            if win {
                HStack(spacing: 14) {
                    if wonStars > 0 { bossRewardPill("⭐", wonStars, AppColor.starGold, step: 1) }
                    if wonDiamonds > 0 { bossRewardPill("💎", wonDiamonds, AppColor.gemPurple, step: 2) }
                    if earnedMinutes > 0 { bossRewardPill("🎮", earnedMinutes, AppColor.successMint, step: 3, suffix: tr(" דק׳")) }
                }
                if let done = completedTier { tierUnlockCard(done: done) }
            }
            VStack(spacing: 12) {
                if !win {
                    Button { restart() } label: { ctaLabel(tr("עוֹד נִסָּיוֹן 🔁"), dark: true) }
                        .buttonStyle(.juicy)
                }
                Button(action: onClose) { ctaLabel(win ? winCTA : tr("חֲזָרָה"), dark: win) }
                    .buttonStyle(.juicy)
                if win, completedTier != nil, let next = suggested {
                    Button {
                        Haptic.light()
                        WorldRouter.shared.pending = next
                    } label: {
                        Text(tr("אוֹ עוֹלָם חָדָשׁ: \(next.name) ✨ +\(ProgressStore.firstVisitDiamonds) 💎"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 10)
                            .background(Capsule().fill(.white.opacity(0.14)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.juicy)
                }
            }
            .padding(.horizontal, 44).padding(.top, 6)
        }
        .padding(28)
    }

    // MARK: - 🏆 Tier completion

    private var winTitle: String {
        guard let done = completedTier else { return Gendered.g(tr("נִצַּחְתָּ אֶת הַבּוֹס! 🏆"), tr("נִצַּחַתְּ אֶת הַבּוֹס! 🏆")) }
        if done >= ProgressStore.worldTierCount - 1 {
            return Gendered.g(tr("אַלּוּף הָעוֹלָם! 👑"), tr("אַלּוּפַת הָעוֹלָם! 👑"))
        }
        return Gendered.g(tr("הִשְׁלַמְתָּ אֶת הַדַּרְגָּה! 🏆"), tr("הִשְׁלַמְתְּ אֶת הַדַּרְגָּה! 🏆"))
    }

    private var winCTA: String {
        guard let done = completedTier, done < ProgressStore.worldTierCount - 1 else { return tr("יֵשׁ! 🎉") }
        return tr("לְדַרְגָּה \(done + 2) 🚀")
    }

    /// "⭐⭐ דַּרְגַּת כֶּסֶף נִפְתְּחָה!" — or, after gold, the world is done.
    private func tierUnlockCard(done: Int) -> some View {
        let next = done + 1
        let title: String
        let line: String
        switch next {
        case 1:
            title = tr("⭐⭐ דַּרְגַּת כֶּסֶף נִפְתְּחָה!")
            line = tr("שְׁאֵלוֹת קָשׁוֹת יוֹתֵר, פְּרָסִים גְּדוֹלִים יוֹתֵר")
        case 2:
            title = tr("⭐⭐⭐ דַּרְגַּת זָהָב נִפְתְּחָה!")
            line = tr("הַדַּרְגָּה הָאַחֲרוֹנָה — וְהִיא הַכִּי קָשָׁה")
        default:
            title = tr("👑 הָעוֹלָם הֻשְׁלַם")
            line = Gendered.g(tr("עָבַרְתָּ אֶת כָּל הַדַּרְגּוֹת! אֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק כָּאן תָּמִיד"),
                              tr("עָבַרְתְּ אֶת כָּל הַדַּרְגּוֹת! אֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק כָּאן תָּמִיד"))
        }
        return VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(line)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(WorldTiers.color(tier: next).opacity(0.9), lineWidth: 1.5))
        .padding(.horizontal, 20)
    }

    private func bossRewardPill(_ emoji: String, _ value: Int, _ color: Color, step: Int, suffix: String = "") -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 26))
            Text("+\(value)\(suffix)").font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(minWidth: 76).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color, lineWidth: 1.5))
        .glow(color, radius: revealStep >= step ? 10 : 0)
        .scaleEffect(revealStep >= step ? 1 : 0.3)
        .opacity(revealStep >= step ? 1 : 0)
    }

    private func ctaLabel(_ t: String, dark: Bool) -> some View {
        Text(t)
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(dark ? AppColor.textOnLight : .white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(dark ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.16)), in: Capsule())
    }

    // MARK: - Logic

    private func newQuestion() {
        // Pre-readers (גן, effectiveGrade < 1) can't read — route them to the
        // text-free visual path, exactly like the main runner does. Without this
        // the boss served reading-dependent bank questions to a child who can't
        // read (the math-world boss was already safe via symbolic generation).
        if (ProfileStore.shared.active?.effectiveGrade ?? 1) < 1 {
            question = PreReaderContent.generate(topic: world.topic)
            picked = nil
            locked = false
            return
        }
        if world.isBonusWorld {
            // 💫 Arena boss: extra-hard bonus questions across ALL enabled topics.
            let pool = Array(ProfileStore.shared.active?.playableTopics ?? Set(Topic.core))
            question = QuestionGenerator.generateBonus(topic: pool.randomElement() ?? .logic,
                                                       grade: ProfileStore.shared.active?.effectiveGrade)
        } else {
            // A boss must BITE. Curriculum content stays within the child's
            // grade, so a kid whose adaptive level already maxed the topic
            // (Dan, end of grade 1) breezed through "hard". When the adaptive
            // engine says they're at the top band (level ≥ 1.75 of 0–2), the
            // boss draws from ONE GRADE UP (the generators cap the range).
            let profile = ProfileStore.shared.active
            let base = profile?.difficulty(for: world.topic) ?? .easy
            let level = ProgressStore.shared.adaptiveLevel(for: world.topic, base: base)
            var grade = profile?.effectiveGrade
            // 🏆 Silver/gold bosses start one/two grades up, like their rooms.
            if let g = grade { grade = g + ProgressStore.shared.tierGradeOffset(in: world.id) }
            if let g = grade, level >= 1.75 { grade = g + 1 }
            if let g = grade { grade = min(CurriculumMath.topGrade, g) }
            question = QuestionGenerator.generate(topic: world.topic, difficulty: .hard,
                                                  grade: grade)
        }
        picked = nil
        locked = false
        shownAt = Date()
    }

    private func pick(_ idx: Int) {
        guard !locked, let q = question else { return }
        locked = true
        picked = idx
        let correct = idx == q.correctIndex
        // Every boss answer is a real question: it counts in the parent's
        // reports, today's total and the admin panel — without paying minutes
        // per answer (the win pays the boss prize).
        progress.recordBossAnswer(correct: correct)
        LearningHistoryStore.shared.recordAnswer(
            topic: q.topic, correct: correct,
            responseMs: Date().timeIntervalSince(shownAt) * 1000,
            earnedMinutes: 0, streak: progress.currentStreak
        )
        if correct {
            SoundPlayer.shared.play(.correctBig)
            Haptic.success()
            burst += 1
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bossHit = true }
            bossHP = max(0, bossHP - 1)
        } else {
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            withAnimation(.default) { shake = true }
            hearts = max(0, hearts - 1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            bossHit = false; shake = false
            if bossHP == 0 { win() }
            else if hearts == 0 { phase = .lost }
            else { newQuestion() }
        }
    }

    private func win() {
        phase = .won
        // Full jackpot only ONCE per boss per day — otherwise "עוד סיבוב 🔁"
        // farmed 20⭐+30💎 endlessly. Replays give a small practice reward.
        let dayKey = "boss.won.\(world.id)"
        let alreadyToday: Bool = {
            return DayGate.usedToday(UserDefaults.standard.object(forKey: dayKey) as? Date)
        }()
        if alreadyToday {
            earnedMinutes = 0; wonStars = 2; wonDiamonds = 0
            progress.applyChestReward(ChestReward(stars: 2, diamonds: 0, minutes: 0))
        } else {
            earnedMinutes = 5; wonStars = 20; wonDiamonds = 30
            progress.applyChestReward(ChestReward(stars: 20, diamonds: 30, minutes: earnedMinutes))
            UserDefaults.standard.set(Date(), forKey: dayKey)
        }
        // 🏆 Beaten in the last room → the tier is complete (+100 💎, next tier
        // a grade up). Not for the arena — it has no tiers.
        if !world.isBonusWorld, let done = progress.completeTier(in: world.id) {
            completedTier = done
            wonDiamonds += ProgressStore.tierCompleteDiamonds
            suggested = WorldTiers.suggestedNewWorld(excluding: world.id)
        }
        SoundPlayer.shared.play(.worldUnlock)
        Haptic.success()
        confetti += 1
        AppAnalytics.log("boss_battle_won", ["world": world.id])
        for s in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(s)) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { revealStep = s }
                SoundPlayer.shared.play(.correctSmall)
            }
        }
    }

    private func restart() {
        bossHP = bossMaxHP; hearts = startHearts; phase = .fighting; revealStep = 0
        completedTier = nil; suggested = nil
        newQuestion()
    }
}

/// Small horizontal shake for a wrong answer.
private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = sin(animatableData * .pi * 4) * 9
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}
