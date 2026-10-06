import SwiftUI
import Combine

/// "אֵיךְ בָּא לְךָ לְשַׂחֵק?" — what a world opens to (Rani, 2026-10-03: the
/// screen with "בואו נתחיל" and the boss button is gone; after choosing a world
/// the child chooses HOW to play it, and goes straight in).
///
/// The world's essentials sit in a compact header — its name, the room it's
/// in, today's minutes, what an answer earns — then:
///   📝 regular questions (the runner, exactly as "בואו נתחיל" started it),
///   the games that make a real round from THIS world's content (WorldGameFit,
///   best fit first, each with a miniature of its screen, the last one played
///   outlined in gold), 🐉 the boss once it's unlocked, and 🎲 "surprise me".
///
/// Every game here earns screen time like the questions do — see
/// MiniGameEarnSession. Paid worlds never reach this screen locked: the home's
/// world card keeps its own ask-a-parent / pack gating before opening it.
struct WorldGameChooserView: View {
    let world: World
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isInertPreview) private var inertPreview
    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore
    @ObservedObject private var display = DisplayGeometry.shared

    private enum Launch: Identifiable {
        case questions, boss, game(MiniGameKind)
        var id: String {
            switch self {
            case .questions:    return "questions"
            case .boss:         return "boss"
            case .game(let k):  return k.rawValue
            }
        }
    }

    @State private var games: [MiniGameKind] = []
    @State private var launch: Launch?
    @State private var lastPick: String?
    @State private var appeared = false

    private var isCompact: Bool { hsc == .compact }
    /// 👶 A גן child can't read this screen on their own, so the question at
    /// the top is also spoken and carries a 🔊 to hear it again. Every word
    /// stays: a parent playing along reads the game names and the mission
    /// lines (Rani: "יכול להיות לדוגמא שההורים עושים עם הילד").
    private var preReader: Bool { PreReaderGames.isPreReader(profiles.active?.effectiveGrade ?? 1) }
    private var currentRoom: Int { progress.progress(in: world.id) }
    /// The boss waits in the world's final room (WorldDetailView's rule).
    private var bossUnlocked: Bool { currentRoom >= world.rooms - 1 }
    /// The bank the games play from (reading → the language the child reads).
    private var contentTopic: Topic? {
        world.isBonusWorld ? nil : (GameContent.sourceTopic(world.topic) ?? world.topic)
    }
    private var lastKey: String { "chooser.last.\(profiles.activeID?.uuidString ?? "none").\(world.id)" }

    /// Should a tap on this world skip the chooser? A parent asked for regular
    /// questions only, or there is nothing else to choose (a גן child, a world
    /// with no game content and no boss yet).
    static func goesStraightToQuestions(_ world: World, profile: Profile?) -> Bool {
        if profile?.onlyRegularQuestions == true { return true }
        let room = ProgressStore.shared.progress(in: world.id)
        let boss = room >= world.rooms - 1
        return !boss && WorldGameFit.games(for: world, grade: profile?.effectiveGrade ?? 1).isEmpty
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 14, size: 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: isCompact ? AppSpacing.md : AppSpacing.lg) {
                    header
                    questionsCard
                    if !games.isEmpty {
                        LazyVGrid(columns: gridColumns, spacing: isCompact ? 12 : 16) {
                            ForEach(Array(games.enumerated()), id: \.element) { i, kind in
                                gameCard(kind, index: i)
                            }
                        }
                    }
                    if bossUnlocked { bossCard }
                    if !games.isEmpty { surpriseCard }
                }
                .frame(maxWidth: isCompact ? .infinity : 1000)
                .padding(.horizontal, isCompact ? AppSpacing.md : AppSpacing.xl)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            games = WorldGameFit.games(for: world, grade: profiles.active?.effectiveGrade ?? 1)
            lastPick = UserDefaults.standard.string(forKey: lastKey)
            // 👶 A גן child can't read "אֵיךְ בָּא לְךָ לְשַׂחֵק?", so they hear it.
            // 🖼 …but a miniature of this screen on a story card says nothing.
            if preReader, !inertPreview {
                SpeechReader.shared.speak(Gendered.g(tr("אֵיךְ בָּא לְךָ לְשַׂחֵק?"), tr("אֵיךְ בָּא לָךְ לְשַׂחֵק?")))
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
        }
        .fullScreenCover(item: $launch) { pick in
            Group {
                switch pick {
                case .questions:
                    QuestionRunnerView(world: world, purpose: .earnTime)
                case .boss:
                    BossBattleView(world: world) { launch = nil }
                case .game(let kind):
                    ChooserGameHost(kind: kind, world: world, topic: contentTopic) { launch = nil }
                }
            }
            .environment(\.layoutDirection, .app)
        }
        // A fullScreenCover doesn't inherit the app root's RTL direction.
        .environment(\.layoutDirection, .app)
    }

    // MARK: - Header

    private var gridColumns: [GridItem] {
        if isCompact { return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2) }
        // An iPad: 3 or 4 across, whatever the count — 4 cards or 12 look even.
        return [GridItem(.adaptive(minimum: display.isShort ? 200 : 220, maximum: 320), spacing: 16)]
    }

    private var header: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    MiniGameChip { Image(systemName: "xmark").font(.system(size: 13, weight: .heavy)) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("סְגֹר"))
                Spacer(minLength: 0)
                MiniGameChip {
                    Text("💎 \(progress.diamonds.currencyShort)")
                        .foregroundStyle(AppColor.diamondBlue)
                }
                MiniGameChip {
                    Text("⭐ \(progress.stars.currencyShort)")
                        .foregroundStyle(AppColor.starGold)
                }
                MiniGameChip { Text(minutesText) }
            }
            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()

            HStack(spacing: isCompact ? 12 : 18) {
                Text(world.emoji)
                    .font(.system(size: isCompact ? 54 : 72))
                    .shadow(color: world.glowColor.opacity(0.8), radius: 16)
                    .float(amplitude: 5)
                    .scaleEffect(appeared ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 6) {
                    Text(world.name)
                        .font(.system(size: isCompact ? 24 : 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    roomBar
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Text(Gendered.g(tr("אֵיךְ בָּא לְךָ לְשַׂחֵק?"), tr("אֵיךְ בָּא לָךְ לְשַׂחֵק?")))
                    .font(.system(size: isCompact ? 22 : 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                // 👶 גן: the same question, out loud, as often as asked for.
                if preReader {
                    PreReaderSpeakButton(spoken: Gendered.g(tr("אֵיךְ בָּא לְךָ לְשַׂחֵק?"), tr("אֵיךְ בָּא לָךְ לְשַׂחֵק?")),
                                         side: isCompact ? 44 : 54)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
        .padding(isCompact ? 14 : 20)
        .glassPane(radius: 26)
    }

    /// "⏱ 12/90 דַּק' הַיּוֹם" — today's minutes against the child's daily cap.
    private var minutesText: String {
        let cap = progress.dailyCap
        let earned = progress.minutesEarnedToday
        return "⏱ " + (cap.enabled ? tr("\(earned)/\(cap.max) דַּק' הַיּוֹם") : tr("\(earned) דַּקּוֹת"))
    }

    /// The room pips as one slim bar, and "חֶדֶר 3 מִתּוֹךְ 10".
    private var roomBar: some View {
        let frac = Double(min(currentRoom, world.rooms)) / Double(max(1, world.rooms))
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(AppGradient.gold)
                        .frame(width: max(8, geo.size.width * frac))
                        .glow(AppColor.starGold, radius: 4)
                }
            }
            .frame(width: isCompact ? 150 : 220, height: 7)
            .environment(\.layoutDirection, .app)
            Text(tr("חֶדֶר \(min(currentRoom + 1, world.rooms)) מִתּוֹךְ \(world.rooms)"))
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
        }
    }

    // MARK: - Cards

    private func outline(_ pickID: String) -> some View {
        let last = lastPick == pickID
        return RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(last ? AppColor.starGold : .clear, lineWidth: 2.5)
            // The tag sits ON the gold outline, in the corner away from the
            // title — inside the card it covered the heading (Rani, 2026-10-06).
            .overlay(alignment: .topTrailing) {
                if last {
                    Text(Gendered.g(tr("שִׂחַקְתָּ לָאַחֲרוֹנָה"), tr("שִׂחַקְתְּ לָאַחֲרוֹנָה")))
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3FBF"))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(AppColor.starGold))
                        .padding(.trailing, 16)
                        .offset(y: -11)
                }
            }
            .allowsHitTesting(false)
    }

    /// 📝 Regular questions — the runner, as "בואו נתחיל" always started it.
    private var questionsCard: some View {
        Button { pick(.questions) } label: {
            HStack(spacing: isCompact ? 12 : 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("📝 שְׁאֵלוֹת רְגִילוֹת"))
                        .font(.system(size: isCompact ? 21 : 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    ForEach(missionLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: isCompact ? 13 : 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                QuestionsPreview()
                    .frame(width: isCompact ? 120 : 190, height: isCompact ? 84 : 120)
                    .padding(8)
                    .glassInset(radius: 16)
            }
            .padding(isCompact ? 14 : 20)
            .frame(maxWidth: .infinity)
            .miniGameTile(.normal, tint: AppColor.starGold, radius: 24)
            .overlay(outline("questions"))
        }
        .buttonStyle(.juicy)
        .multilineTextAlignment(.leading)
    }

    /// What WorldDetailView's mission card said, in two short lines.
    private var missionLines: [String] {
        if world.isBonusWorld {
            return ["💪 " + tr("רַק שְׁאֵלוֹת עֲנָק — קָשׁוֹת בִּמְיוּחָד, מִכָּל הַנּוֹשְׂאִים!"),
                    "🎮 " + tr("דַּקּוֹת כְּפוּלוֹת: כָּל \(max(1, settings.batchAnswers / 2)) נְכוֹנוֹת = \(settings.batchMinutes) דַּקּוֹת מִשְׂחָק")]
        }
        return ["🎁 " + tr("\(settings.questionsPerSession) שְׁאֵלוֹת → קוּפְסַת הַפְתָּעָה"),
                "🎮 " + tr("כָּל \(settings.batchAnswers) נְכוֹנוֹת = \(settings.batchMinutes) דַּקּוֹת מִשְׂחָק")]
    }

    private func gameCard(_ kind: MiniGameKind, index i: Int) -> some View {
        Button { pick(.game(kind)) } label: {
            VStack(spacing: 8) {
                MiniGamePreview(kind: kind, topic: contentTopic)
                    .frame(height: isCompact ? 92 : 124)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .glassInset(radius: 16)
                Text(kind.emoji + " " + kind.shortName)
                    .font(.system(size: isCompact ? 16 : 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(kind.blurb)
                    .font(.system(size: isCompact ? 12 : 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .frame(minHeight: isCompact ? 30 : 36, alignment: .top)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .miniGameTile(.normal, tint: OptionCard.tints[i % OptionCard.tints.count], radius: 24)
            .overlay(outline(kind.rawValue))
            // Rises into place instead of scaling up: SwiftUI rasterizes a
            // scaling view, so animating the card's scale blurred every label
            // on it for the length of the animation.
            .offset(y: appeared ? 0 : 14)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.03 * Double(i)), value: appeared)
        }
        .buttonStyle(.juicy)
        .accessibilityLabel(kind.title)
    }

    private func wideCard(emoji: String, title: String, subtitle: String, tint: Color, pickID: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: isCompact ? 40 : 52))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: isCompact ? 20 : 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: isCompact ? 13 : 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(isCompact ? 14 : 18)
            .frame(maxWidth: .infinity)
            .miniGameTile(.normal, tint: tint, radius: 24)
            .overlay(outline(pickID))
        }
        .buttonStyle(.juicy)
        .multilineTextAlignment(.leading)
    }

    /// 🐉 The world's finale — only once its last room is reached.
    private var bossCard: some View {
        wideCard(emoji: "🐉", title: tr("קְרַב בּוֹס"), subtitle: tr("הָאֶתְגָּר הַגָּדוֹל שֶׁל הָעוֹלָם הַזֶּה"),
                 tint: Color(hex: "EF476F"), pickID: "boss") { pick(.boss) }
    }

    /// 🎲 One of this world's games, picked for the child.
    private var surpriseCard: some View {
        wideCard(emoji: "🎲", title: tr("תַּפְתִּיעוּ אוֹתִי!"), subtitle: tr("מִשְׂחָק אַקְרָאִי מֵהָעוֹלָם הַזֶּה"),
                 tint: Color(hex: "9B5DE5"), pickID: "surprise") {
            var pool = games
            if pool.count > 1, let last = lastPick { pool.removeAll { $0.rawValue == last } }
            if let kind = pool.randomElement() { pick(.game(kind), viaSurprise: true) }
        }
    }

    // MARK: - Launch

    private func pick(_ choice: Launch, viaSurprise: Bool = false) {
        Haptic.light()
        UserDefaults.standard.set(choice.id, forKey: lastKey)
        AppAnalytics.log("world_chooser_pick", ["world": world.id, "pick": choice.id, "surprise": viaSurprise ? "1" : "0"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            launch = choice
            lastPick = choice.id
        }
    }
}

/// What a tapped world opens: the chooser, or — decided ONCE, when it opens —
/// straight into its questions. (Decided once: re-deciding on every redraw
/// would swap a running question session for the chooser the moment the boss
/// unlocked mid-session.)
struct WorldEntryView: View {
    let world: World
    @State private var straight: Bool?

    var body: some View {
        Group {
            switch straight {
            case true?:
                QuestionRunnerView(world: world, purpose: .earnTime)
            case false?:
                WorldGameChooserView(world: world)
            case nil:
                GlassBackdrop()
                    .onAppear {
                        straight = WorldGameChooserView.goesStraightToQuestions(world, profile: ProfileStore.shared.active)
                    }
            }
        }
        .environment(\.layoutDirection, .app)
    }
}

/// A game opened from the chooser, with its own earning session for as long
/// as the game is on screen.
private struct ChooserGameHost: View {
    let kind: MiniGameKind
    let topic: Topic?
    var onClose: () -> Void
    @StateObject private var earn: MiniGameEarnSession

    init(kind: MiniGameKind, world: World, topic: Topic?, onClose: @escaping () -> Void) {
        self.kind = kind
        self.topic = topic
        self.onClose = onClose
        _earn = StateObject(wrappedValue: MiniGameEarnSession(world: world))
    }

    var body: some View {
        MiniGameScreen(kind: kind, topic: topic, earn: earn, onClose: onClose)
    }
}

/// DEMO_SCREEN host: the chooser of the world for `topic`, at DEMO_GRADE.
struct WorldGameChooserDemo: View {
    let topic: Topic

    init(topic: Topic) {
        self.topic = topic
        // Before the chooser counts which games fit — they depend on the grade.
        // 📅 Re-stamp the school year EVERY time, not only when the grade
        // changes: a profile a previous run left at DEMO_GRADE=0 keeps that 0
        // but carries last year's `gradeSchoolYear`, and September's auto
        // advance then makes `effectiveGrade` 1 — so a גן screenshot run on a
        // device that has been used before quietly rendered the reader form.
        if let g = ProcessInfo.processInfo.environment["DEMO_GRADE"].flatMap(Int.init),
           var p = ProfileStore.shared.active,
           p.grade != g || p.gradeSchoolYear != Profile.schoolYear() {
            p.grade = g
            p.gradeSchoolYear = Profile.schoolYear()
            ProfileStore.shared.update(p)
        }
    }

    var body: some View {
        WorldGameChooserView(world: Worlds.all.first { $0.topic == topic && !$0.isBonusWorld } ?? Worlds.all[0])
            .environmentObject(ParentSettings.shared)
            .environmentObject(ProgressStore.shared)
            .environmentObject(ProfileStore.shared)
    }
}

#Preview {
    WorldGameChooserView(world: Worlds.all[0])
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ProfileStore.shared)
}
