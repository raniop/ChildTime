import SwiftUI

/// 🎮 The mini-games that break up the question loop. Each opens from a world
/// screen, and the runner launches one as a ⚡ surprise round.
///
/// Every piece here is built from the app's own glass kit — GlassBackdrop,
/// glassPane / glassInset / glassFill, the runner's glass chips, the answer
/// tiles' mint-for-right / soft-warm-for-a-miss — so a game looks like the
/// rest of Tofy, not like a separate app.
enum MiniGameKind: String, Identifiable, CaseIterable {
    case pairs       // 🔗 חַבְּרוּ אֶת הַזּוּגוֹת
    case balloon     // 🎈 פּוֹצְצוּ אֶת הַבַּלּוֹנִים
    case word        // 🧩 בְּנוּ אֶת הַמִּלָּה
    case crush       // 🧱 מְפַצְּחִים
    case wordSearch  // 🔤 תַּפְזֹרֶת
    case lightning   // ⚡ נָכוֹן אוֹ לֹא נָכוֹן?
    case sort        // 🧺 מִיּוּן לַסַּלִּים
    case pattern     // 🧠 הַתַּבְנִית
    case game2048    // 🔢 2048 שֶׁל טוֹפִּי
    case vault       // 🔐 הַכַּסֶּפֶת
    case grocery     // 🛒 הַמַּכֹּלֶת
    case balance     // ⚖️ מֹאזְנַיִם

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .pairs:      return "🔗"
        case .balloon:    return "🎈"
        case .word:       return "🧩"
        case .crush:      return "🧱"
        case .wordSearch: return "🔤"
        case .lightning:  return "⚡"
        case .sort:       return "🧺"
        case .pattern:    return "🧠"
        case .game2048:   return "🔢"
        case .vault:      return "🔐"
        case .grocery:    return "🛒"
        case .balance:    return "⚖️"
        }
    }

    var title: String {
        switch self {
        case .pairs:      return tr("חַבְּרוּ אֶת הַזּוּגוֹת")
        case .balloon:    return tr("פּוֹצְצוּ אֶת הַבַּלּוֹנִים")
        case .word:       return tr("בְּנוּ אֶת הַמִּלָּה")
        case .crush:      return tr("מְפַצְּחִים")
        case .wordSearch: return tr("תַּפְזֹרֶת")
        case .lightning:  return tr("נָכוֹן אוֹ לֹא נָכוֹן?")
        case .sort:       return tr("מִיּוּן לַסַּלִּים")
        case .pattern:    return tr("הַתַּבְנִית")
        case .game2048:   return tr("2048 שֶׁל טוֹפִּי")
        case .vault:      return tr("הַכַּסֶּפֶת")
        case .grocery:    return tr("הַמַּכֹּלֶת")
        case .balance:    return tr("מֹאזְנַיִם")
        }
    }

    /// Seconds on the clock for the timed games (a surprise round is shorter).
    func seconds(surprise: Bool) -> Int {
        switch self {
        case .balloon:  return 30
        case .crush, .lightning: return surprise ? 45 : 60
        case .sort:     return surprise ? 30 : 40
        case .game2048: return surprise ? 90 : 150
        default:        return 0
        }
    }

    func subtitle(surprise: Bool) -> String {
        switch self {
        case .pairs:      return tr("5 זוּגוֹת — מִצְאוּ לְכָל אֶחָד אֶת הַבֶּן־זוּג שֶׁלּוֹ")
        case .balloon:    return tr("\(seconds(surprise: surprise)) שְׁנִיּוֹת — פּוֹצְצוּ רַק אֶת הַנְּכוֹנִים!")
        case .word:       return tr("5 מִלִּים — לְפִי הַתְּמוּנָה, אוֹת אַחַר אוֹת")
        case .crush:      return tr("\(seconds(surprise: surprise)) שְׁנִיּוֹת — בַּחֲרוּ קֻבִּיּוֹת שֶׁמַּגִּיעוֹת בְּדִיּוּק לַיַּעַד!")
        case .wordSearch: return tr("5 מִלִּים מִסְתַּתְּרוֹת — גִּרְרוּ אֶצְבַּע עַל כָּל מִלָּה")
        case .lightning:  return tr("\(seconds(surprise: surprise)) שְׁנִיּוֹת — כַּמָּה שֶׁיּוֹתֵר תְּשׁוּבוֹת נְכוֹנוֹת!")
        case .sort:       return tr("\(seconds(surprise: surprise)) שְׁנִיּוֹת — גִּרְרוּ כָּל פְּרִיט לַסַּל הַמַּתְאִים")
        case .pattern:    return tr("6 סְדָרוֹת — מָה מַשְׁלִים אֶת הַתַּבְנִית?")
        case .game2048:   return tr("חַבְּרוּ אֲרִיחִים זֵהִים — וְכָל כַּמָּה מַהֲלָכִים מַגִּיעָה שְׁאֵלַת בּוֹנוּס")
        case .vault:      return tr("כָּל תְּשׁוּבָה נְכוֹנָה פּוֹתַחַת רֶמֶז — וְהָרְמָזִים מְגַלִּים אֶת הַקּוֹד הַסּוֹדִי")
        case .grocery:    return surprise ? tr("2 קְנִיּוֹת — קוֹנִים לְפִי הָרְשִׁימָה וּמְחַשְּׁבִים עֹדֶף")
                                          : tr("3 קְנִיּוֹת — קוֹנִים לְפִי הָרְשִׁימָה וּמְחַשְּׁבִים עֹדֶף")
        case .balance:    return tr("5 מֹאזְנַיִם — מָה מֵבִיא אוֹתָם לְאִזּוּן?")
        }
    }

    /// The short name on a world screen's game tile (the emoji sits above it).
    var shortName: String {
        switch self {
        case .pairs:      return tr("זוּגוֹת")
        case .balloon:    return tr("בַּלּוֹנִים")
        case .word:       return tr("בְּנוּ מִלָּה")
        case .crush:      return tr("מְפַצְּחִים")
        case .wordSearch: return tr("תַּפְזֹרֶת")
        case .lightning:  return tr("נָכוֹן אוֹ לֹא")
        case .sort:       return tr("מִיּוּן לַסַּלִּים")
        case .pattern:    return tr("הַתַּבְנִית")
        case .game2048:   return tr("2048 שֶׁל טוֹפִּי")
        case .vault:      return tr("הַכַּסֶּפֶת")
        case .grocery:    return tr("הַמַּכֹּלֶת")
        case .balance:    return tr("מֹאזְנַיִם")
        }
    }

    /// One line under the game's card in the world's chooser.
    var blurb: String {
        switch self {
        case .pairs:      return tr("מְחַבְּרִים כָּל שְׁאֵלָה לַתְּשׁוּבָה שֶׁלָּהּ")
        case .balloon:    return tr("מְפוֹצְצִים רַק אֶת הַנְּכוֹנִים")
        case .word:       return tr("בּוֹנִים מִלָּה אוֹת אַחַר אוֹת")
        case .crush:      return tr("קֻבִּיּוֹת שֶׁמַּגִּיעוֹת בְּדִיּוּק לַיַּעַד")
        case .wordSearch: return tr("מוֹצְאִים מִלִּים מִסְתַּתְּרוֹת")
        case .lightning:  return tr("נָכוֹן אוֹ לֹא — מַהֵר!")
        case .sort:       return tr("כָּל פְּרִיט לַסַּל הַמַּתְאִים")
        case .pattern:    return tr("מָה מַמְשִׁיךְ אֶת הַסִּדְרָה?")
        case .game2048:   return tr("מְחַבְּרִים אֲרִיחִים עַד 2048")
        case .vault:      return tr("רְמָזִים שֶׁמְּגַלִּים קוֹד סוֹדִי")
        case .grocery:    return tr("קוֹנִים, מְחַשְּׁבִים וּמְקַבְּלִים עֹדֶף")
        case .balance:    return tr("מְאַזְּנִים אֶת שְׁתֵּי הַכַּפּוֹת")
        }
    }

    /// Which of the twelve this child gets, grade by grade, is
    /// `MiniGameGradeFit` — the single table behind the chooser, the surprise
    /// round and reports/games/grade-fit.md. 👶 גן now has a roster of its own
    /// there (five games in a text-free, spoken form), so every child has
    /// games; this stays only as the "is there anything at all" question.
    static var availableForActiveChild: Bool {
        !MiniGameGradeFit.roster(grade: ProfileStore.shared.active?.effectiveGrade ?? 1).isEmpty
    }

    /// 👶 Does this game have a גן form — no words, a spoken instruction and
    /// its content from `PreReaderGames`?
    var hasPreReaderForm: Bool { MiniGameGradeFit.preReaderRoster.contains(self) }
}

/// The game screen itself, for a cover. `surprise` = launched by the runner's
/// ⚡ surprise round: no intro (the interstitial was it), one round, ×2 ⭐/💎.
/// `earn` = launched from a world's chooser: every right answer earns screen
/// time exactly like a regular question (see MiniGameEarnSession).
struct MiniGameScreen: View {
    let kind: MiniGameKind
    var topic: Topic?
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    var body: some View {
        Group {
            switch kind {
            case .pairs:      PairsGameView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .balloon:    BalloonPopView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .word:       BuildWordView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .crush:      NumberCrushView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .wordSearch: WordSearchView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .lightning:  LightningTrueFalseView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .sort:       SortBasketsView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .pattern:    PatternGameView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .game2048:   Game2048View(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .vault:      VaultGameView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .grocery:    GroceryGameView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            case .balance:    BalanceGameView(topic: topic, surprise: surprise, earn: earn, onClose: onClose)
            }
        }
        .overlay {
            if let earn, !surprise { MiniGameEarnOverlay(earn: earn) }
        }
    }
}

// MARK: - Left-to-right math

/// Math and numbers read left-to-right in every language. "90 ÷ 10" laid out
/// in a Hebrew line came out as "10 ÷ 90" on an iPad (Rani) — a wrong sum on
/// screen. Two locks, because one wasn't enough there: a left-to-right mark on
/// each side of the run (so even text with no letters at all resolves LTR),
/// and `.mathLTR()` on the Text itself.
enum MiniGameText {
    static func ltr(_ s: String) -> String {
        "\u{200E}" + s.replacingOccurrences(of: " ", with: "\u{00A0}") + "\u{200E}"
    }

    /// No letters at all, and some digits → a number, an expression, a sequence.
    static func isMath(_ s: String) -> Bool {
        let scalars = s.unicodeScalars
        return !scalars.contains { CharacterSet.letters.contains($0) }
            && scalars.contains { CharacterSet.decimalDigits.contains($0) }
    }

    /// `ltr` for math, the text untouched otherwise.
    static func show(_ s: String) -> String { isMath(s) ? ltr(s) : s }
}

private struct MathLTR: ViewModifier {
    let on: Bool
    @Environment(\.layoutDirection) private var current
    func body(content: Content) -> some View {
        content.environment(\.layoutDirection, on ? .leftToRight : current)
    }
}

extension View {
    /// Lay this text out left-to-right when it is math (see `MiniGameText`).
    func mathLTR(_ on: Bool = true) -> some View { modifier(MathLTR(on: on)) }

    /// A scroll view that opens at its bottom (iOS 17+; earlier: the top).
    @ViewBuilder func scrollAnchorBottom() -> some View {
        if #available(iOS 17.0, *) { defaultScrollAnchor(.bottom) } else { self }
    }
}

// MARK: - Backdrop & top bar (the runner's)

/// The runner's backdrop, one to one.
struct MiniGameBackdrop: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 10, size: 11)
        }
    }
}

/// A glass chip — the runner's `quizChip`.
struct MiniGameChip<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.14)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 1))
    }
}

/// The runner's top row: ✕ · 💎 · ⭐ · the game's own chip.
struct MiniGameTopBar<Trailing: View>: View {
    var onClose: () -> Void
    /// From a world's chooser: the runner's earned-time bar under the chips.
    var earn: MiniGameEarnSession? = nil
    @ViewBuilder var gameChip: () -> Trailing
    @ObservedObject private var progress = ProgressStore.shared

    var body: some View {
        VStack(spacing: 8) {
            chips
            if earn != nil { MiniGameEarnBar() }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    private var chips: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                MiniGameChip { Image(systemName: "xmark").font(.system(size: 13, weight: .heavy)) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("סְגֹר"))
            Spacer(minLength: 0)
            MiniGameChip {
                Text("💎 \(progress.diamonds.currencyShort)")
                    .foregroundStyle(AppColor.diamondBlue)
                    .numericTextTransition(Double(progress.diamonds))
            }
            MiniGameChip {
                Text("⭐ \(progress.stars.currencyShort)")
                    .foregroundStyle(AppColor.starGold)
                    .numericTextTransition(Double(progress.stars))
            }
            MiniGameChip { gameChip() }
        }
        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .monospacedDigit()
    }
}

// MARK: - Glass tiles (the answer cards' look)

/// The look of an answer tile (`OptionCard`): a pane of glass with its own
/// colour glowing through; mint when right, soft warm for a miss, a gold edge
/// when picked.
enum MiniGameTileState: Equatable {
    case normal
    case picked
    case correct
    case wrong
}

struct MiniGameTileBackground: ViewModifier {
    let state: MiniGameTileState
    let tint: Color
    var radius: CGFloat = AppRadius.large

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(.white.opacity(state == .picked ? 0.22 : 0.14))
                    if state == .normal || state == .picked {
                        shape.fill(RadialGradient(colors: [tint.opacity(0.55), .clear],
                                                  center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: 220))
                    }
                    shape.fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                              startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.2)))
                    switch state {
                    case .correct:
                        shape.fill(LinearGradient(colors: [Color(hex: "06D6A0").opacity(0.55), Color(hex: "5CFF9D").opacity(0.35)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                    case .wrong:
                        shape.fill(LinearGradient(colors: [Color(hex: "FF6B6B").opacity(0.5), Color(hex: "FF9AA0").opacity(0.3)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                    default:
                        EmptyView()
                    }
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: borderWidth))
            .glow(glowColor, radius: state == .normal ? 0 : 14)
    }

    private var borderColor: Color {
        switch state {
        case .correct: return Color(hex: "8CFFC4").opacity(0.9)
        case .wrong:   return Color(hex: "FF9AA0").opacity(0.9)
        case .picked:  return AppColor.starGold
        case .normal:  return .white.opacity(0.32)
        }
    }
    private var borderWidth: CGFloat { state == .normal ? 1 : (state == .picked ? 2.5 : 2) }
    private var glowColor: Color {
        switch state {
        case .correct: return AppColor.successMint
        case .wrong:   return AppColor.almostWarm
        case .picked:  return AppColor.starGold
        case .normal:  return .clear
        }
    }
}

extension View {
    func miniGameTile(_ state: MiniGameTileState, tint: Color, radius: CGFloat = AppRadius.large) -> some View {
        modifier(MiniGameTileBackground(state: state, tint: tint, radius: radius))
    }
}

/// Small horizontal shake — the only thing a miss does to the screen.
struct MiniGameShake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 4) * 8, y: 0))
    }
}

// MARK: - Buttons

/// The app's gold CTA (the "הַמְשֵׁךְ" buttons): white heavy text on gold glass.
struct MiniGameGoldButton: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button {
            Haptic.medium()
            action()
        } label: {
            Text(title)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .glassFill(AppGradient.gold, radius: 24)
        }
        .buttonStyle(.juicy)
    }
}

/// The quieter second choice — plain glass.
struct MiniGameGlassButton: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button {
            Haptic.light()
            action()
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .glassPane(radius: 24, shadow: false)
        }
        .buttonStyle(.juicy)
    }
}

// MARK: - 👶 גן chrome: pictures first, words beside them

// Rani, after seeing the first wordless version: "אם זה לגן שלא יודעים לקרוא
// זה לא אומר שעדיין לא צריך להיות רשום! יכול להיות לדוגמא שההורים עושים עם
// הילד." — so a גן round carries all three at once:
//
//   🖼️ the PICTURES, largest, so a five-year-old can play on their own;
//   🔊 the SPEECH, on entry and on every tap of the speaker;
//   ✍️ the WORDS, smaller and underneath, so a parent sitting beside the child
//      can read the rule out loud and play it with them.
//
// The text never grows at the pictures' expense: it sits under them at a
// secondary size, and nothing that was enlarged for small fingers shrank to
// make room for it.

/// The 🔊 a גן round always carries. The rule is written too, but a child who
/// cannot read it has to be able to hear it again on demand — so this is big
/// on purpose and sits beside the sentence it speaks.
struct PreReaderSpeakButton: View {
    let spoken: String
    var side: CGFloat = 52

    var body: some View {
        Button {
            Haptic.light()
            SpeechReader.shared.speak(spoken)
        } label: {
            Text("🔊")
                .font(.system(size: side * 0.52))
                .frame(width: side, height: side)
                .background(Circle().fill(.white.opacity(0.16)))
                .overlay(Circle().strokeBorder(.white.opacity(0.40), lineWidth: 1.5))
        }
        .buttonStyle(.juicy)
        .accessibilityLabel(tr("הַקְשִׁיבוּ שׁוּב"))
    }
}

/// The card at the top of a גן round — and the order on it is the point.
///
/// Rani, looking at it on an iPad: "השאלה צריכה להיות ממורכזת, זה נראה מוזר
/// שהיא בצד לא? … למה התשובות כאלה גדולות? נראה לי יותר הגיוני שהשאלה תהיה
/// בגדול יותר וגם הכיתוב." He was describing a hierarchy standing on its
/// head: the question was the smallest thing on screen and pinned to one
/// edge, while the answers filled the rest of it.
///
/// So, top to bottom and all centred: **the question in words** (the biggest
/// text on the screen) with the 🔊 beside it, then **the rule as pictures**
/// under it. The answers below are sized to a hand, not to the screen.
struct PreReaderCueCard: View {
    let cue: PreReaderCue
    var compact: Bool = true
    @Environment(\.isInertPreview) private var inertPreview
    /// 🔄 A short, wide screen (an iPhone on its side) — one rung down, so the
    /// card never eats the board below it.
    @ObservedObject private var display = DisplayGeometry.shared
    private var short: Bool { display.isShort }

    var body: some View {
        VStack(spacing: short ? 6 : (compact ? 9 : 13)) {
            // 1️⃣ The question, centred and the largest text on the screen,
            //    with the 🔊 beside it rather than stranded at the far edge.
            HStack(spacing: compact ? 9 : 13) {
                Text(cue.spoken)
                    .font(.system(size: short ? 16 : (compact ? 19 : 26), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3).minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                PreReaderSpeakButton(spoken: cue.spoken, side: short ? 40 : (compact ? 46 : 58))
            }
            .frame(maxWidth: .infinity)

            // 2️⃣ …and the same rule as pictures under it.
            if !cue.icons.isEmpty {
                HStack(spacing: compact ? 3 : 6) {
                    ForEach(Array(cue.icons.prefix(6).enumerated()), id: \.offset) { _, icon in
                        Text(icon)
                            .font(.system(size: iconSize))
                            .minimumScaleFactor(0.5)
                    }
                }
                .lineLimit(1)
                .glow(AppColor.starGold, radius: 8)
            }
        }
        .padding(.horizontal, compact ? 14 : 20)
        .padding(.vertical, short ? 8 : (compact ? 12 : 16))
        .frame(maxWidth: .infinity)
        .glassPane(radius: 24)
        // 🖼 A miniature on a story card is a picture of this screen, not this
        // screen: it says nothing out loud.
        .onAppear { if !inertPreview { SpeechReader.shared.speak(cue.spoken) } }
        .onChange(of: cue.spoken) { _ in if !inertPreview { SpeechReader.shared.speak(cue.spoken) } }
    }

    /// Six apples in a row still have to fit a phone, so the more there are
    /// the smaller each one gets — but they are the goal, so they stay big.
    private var iconSize: CGFloat {
        let base: CGFloat = short ? 36 : (compact ? 50 : 76)
        switch cue.icons.count {
        case 1:    return base
        case 2, 3: return base * 0.86
        case 4:    return base * 0.74
        default:   return base * 0.62
        }
    }
}

/// 👶 The intro a גן round opens with: the game's own emoji and the rule's
/// pictures, its name, the rule in one sentence, the 🔊 and a ▶️ to begin.
struct PreReaderIntroCard: View {
    let kind: MiniGameKind
    let cue: PreReaderCue
    var onStart: () -> Void
    @Environment(\.isInertPreview) private var inertPreview
    @Environment(\.horizontalSizeClass) private var hsc
    @ObservedObject private var display = DisplayGeometry.shared
    private var big: Bool { hsc == .regular }
    /// 🔄 On its side there is no room for a 96pt emoji above everything else.
    private var short: Bool { display.isShort }

    var body: some View {
        VStack(spacing: short ? 9 : (big ? 16 : 13)) {
            Text(kind.emoji)
                .font(.system(size: short ? 58 : (big ? 118 : 88)))
                .float(amplitude: 6)
                .glow(AppColor.starGold, radius: 14)
            if !cue.icons.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(cue.icons.prefix(6).enumerated()), id: \.offset) { _, icon in
                        Text(icon)
                            .font(.system(size: short ? 32 : (big ? 56 : 42)))
                            .minimumScaleFactor(0.5)
                    }
                }
                .lineLimit(1)
                .glow(AppColor.starGold, radius: 8)
            }
            Text(kind.title)
                .font(.system(size: short ? 22 : (big ? 34 : 27), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
            Text(cue.spoken)
                .font(.system(size: short ? 14 : (big ? 19 : 16), weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PreReaderSpeakButton(spoken: cue.spoken, side: short ? 48 : (big ? 72 : 60))
            MiniGameGoldButton(title: tr("יַאלְלָה! 🚀"), action: onStart)
                .padding(.top, 2)
        }
        .padding(short ? 16 : (big ? 32 : 24))
        .frame(maxWidth: big ? 540 : 410)
        .glassPane(radius: 28)
        .padding(.horizontal, AppSpacing.lg)
        .onAppear {
            if !inertPreview { SpeechReader.shared.speak(PreReaderGames.startCue + " " + cue.spoken) }
        }
    }
}

/// 👶 The end of a גן round: the child's own buddy, what they did drawn as
/// that many pictures AND said in a line, the ⭐/💎 chips, the 🔊 that reads
/// the praise, and the way on. Never framed as a failure, and never a word
/// about a miss.
struct PreReaderEndCard: View {
    let title: String
    let detail: String
    /// What the round produced, as a picture repeated that many times
    /// (capped — ten balloons in a row is a wall, not a reward).
    let tally: String
    let tallyCount: Int
    let grant: MiniGameReward.Grant?
    var surprise: Bool = false
    var againLabel: String = ""
    var onAgain: () -> Void = {}
    var onDone: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @Environment(\.horizontalSizeClass) private var hsc
    @ObservedObject private var display = DisplayGeometry.shared
    @State private var reveal = 0
    private var big: Bool { hsc == .regular }
    /// 🔄 Short and wide: the buddy and the tally come down a rung so the two
    /// buttons at the bottom stay on screen.
    private var short: Bool { display.isShort }

    var body: some View {
        VStack(spacing: short ? 8 : 12) {
            CharacterView(character: profiles.active?.character ?? Character3DCatalog.find(nil))
                .frame(width: short ? 78 : (big ? 140 : 108), height: short ? 78 : (big ? 140 : 108))
                .float(amplitude: 8)
            if tallyCount > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<min(tallyCount, 8), id: \.self) { _ in
                        Text(tally).font(.system(size: short ? 22 : (big ? 34 : 27)))
                    }
                    if tallyCount > 8 {
                        Text("✨").font(.system(size: short ? 22 : (big ? 34 : 27)))
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                .glow(AppColor.starGold, radius: 10)
            }
            Text(title)
                .font(.system(size: short ? 23 : (big ? 36 : 28), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: short ? 14 : (big ? 19 : 16), weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // 👶 No "+0" here either: a round that paid nothing shows no chip.
            if let grant, grant.stars > 0 || grant.diamonds > 0 {
                HStack(spacing: 12) {
                    MiniGameRewardChip(emoji: "⭐", value: grant.stars, color: AppColor.starGold, shown: reveal >= 1)
                    if grant.diamonds > 0 {
                        MiniGameRewardChip(emoji: "💎", value: grant.diamonds, color: AppColor.diamondBlue, shown: reveal >= 2)
                    }
                }
                .padding(.top, 2)
            }
            PreReaderSpeakButton(spoken: spokenPraise, side: short ? 44 : (big ? 62 : 52))
            VStack(spacing: short ? 7 : 10) {
                if surprise {
                    MiniGameGoldButton(title: tr("מַמְשִׁיכִים! 🚀"), action: onDone)
                } else {
                    MiniGameGoldButton(title: againLabel.isEmpty ? tr("עוֹד סִבּוּב 🔁") : againLabel, action: onAgain)
                    MiniGameGlassButton(title: tr("סִיּוּם"), action: onDone)
                }
            }
            .padding(.top, 2)
        }
        .padding(short ? 14 : (big ? 32 : 22))
        .frame(maxWidth: big ? 540 : 410)
        .glassPane(radius: 28)
        .padding(.horizontal, AppSpacing.lg)
        .onAppear {
            SpeechReader.shared.speak(spokenPraise)
            for s in 1...2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(s)) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { reveal = s }
                    SoundPlayer.shared.play(.correctSmall)
                }
            }
        }
    }

    /// Read aloud: the headline and what the round produced, so a child who
    /// cannot read the two lines still hears them.
    private var spokenPraise: String {
        detail.isEmpty ? title : title + ". " + detail
    }
}

/// 👶 A גן round's counters: the pictures AND the figure, never one without
/// the other — the child reads the dots, whoever is beside them reads the
/// number (Rani: "לא אומר שעדיין לא צריך להיות רשום").
enum PreReaderChrome {
    static func dots(done: Int, total: Int) -> String {
        let shown = min(total, 6)
        let filled = min(done, shown)
        return String(repeating: "●", count: filled) + String(repeating: "○", count: shown - filled)
            + " \(done)/\(total)"
    }

    /// An open-ended round (🎈): a dot per success, and a ✨ past the sixth.
    static func dots(done: Int) -> String {
        let pips = done > 6 ? String(repeating: "●", count: 6) + "✨" : String(repeating: "●", count: done)
        return pips.isEmpty ? "\(done)" : pips + " \(done)"
    }

    /// 🔥 as a streak — the flames and the figure together.
    static func streak(_ n: Int) -> String {
        guard n >= 2 else { return " " }
        return String(repeating: "🔥", count: min(n, 4)) + " \(n)"
    }
}

// MARK: - Intro / end cards

/// The intro card a game opens with from a world screen — the rules in one
/// line and a start button, so a clock never starts before the child is ready.
struct MiniGameIntroCard: View {
    let kind: MiniGameKind
    var onStart: () -> Void
    @Environment(\.horizontalSizeClass) private var hsc
    /// An iPad gets the card a size up — at 440pt it sat small in a sea of glass.
    private var big: Bool { hsc == .regular }

    var body: some View {
        VStack(spacing: big ? 18 : 14) {
            Text(kind.emoji)
                .font(.system(size: big ? 120 : 84))
                .float(amplitude: 6)
                .glow(AppColor.starGold, radius: 14)
            Text(kind.title)
                .font(.system(size: big ? 40 : 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text(kind.subtitle(surprise: false))
                .font(.system(size: big ? 22 : 17, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            MiniGameGoldButton(title: tr("יַאלְלָה! 🚀"), action: onStart)
                .padding(.top, 6)
        }
        .padding(big ? 36 : 24)
        .frame(maxWidth: big ? 580 : 440)
        .glassPane(radius: 28)
        .padding(.horizontal, AppSpacing.lg)
    }
}

/// "+12 ⭐" / "+12 💎" — the runner's chips, a size up.
struct MiniGameRewardChip: View {
    let emoji: String
    let value: Int
    let color: Color
    let shown: Bool

    var body: some View {
        Text("\(emoji) +\(value)")
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .monospacedDigit()
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Capsule().fill(.white.opacity(0.14)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 1))
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
    }
}

/// The shared end screen: the child's own buddy, a headline, a line about the
/// round, the ⭐/💎 just added, and the way on. Never framed as a failure.
/// From a world: "again" + "done". In a surprise round: one "מַמְשִׁיכִים".
struct MiniGameEndCard: View {
    let title: String
    let detail: String
    let grant: MiniGameReward.Grant?
    var surprise: Bool = false
    var againLabel: String = ""
    var onAgain: () -> Void = {}
    var onDone: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var reveal = 0
    private var big: Bool { hsc == .regular }

    var body: some View {
        VStack(spacing: 14) {
            CharacterView(character: profiles.active?.character ?? Character3DCatalog.find(nil))
                .frame(width: big ? 160 : 120, height: big ? 160 : 120)
                .float(amplitude: 8)
            Text(title)
                .font(.system(size: big ? 40 : 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: big ? 21 : 17, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let grant {
                // ⭐ +0 is not a prize and not a message — a round that paid
                // nothing shows no chip at all (Rani saw "⭐ +0" on an end card).
                if grant.stars > 0 || grant.diamonds > 0 {
                    HStack(spacing: 12) {
                        MiniGameRewardChip(emoji: "⭐", value: grant.stars, color: AppColor.starGold, shown: reveal >= 1)
                        if grant.diamonds > 0 {
                            MiniGameRewardChip(emoji: "💎", value: grant.diamonds, color: AppColor.diamondBlue, shown: reveal >= 2)
                        }
                    }
                    .padding(.top, 2)
                }
                if grant.doubled && (grant.stars > 0 || grant.diamonds > 0) {
                    Text(tr("פִּי 2 — סִבּוּב הַפְתָּעָה! ⚡"))
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                } else if !grant.full && grant.stars > 0 {
                    Text(tr("הַפְּרָס הַגָּדוֹל חוֹזֵר מָחָר 🌟"))
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.tertiary)
                }
            }
            VStack(spacing: 10) {
                if surprise {
                    MiniGameGoldButton(title: tr("מַמְשִׁיכִים! 🚀"), action: onDone)
                } else {
                    MiniGameGoldButton(title: againLabel, action: onAgain)
                    MiniGameGlassButton(title: tr("סִיּוּם"), action: onDone)
                }
            }
            .padding(.top, 6)
        }
        .padding(big ? 36 : 24)
        .frame(maxWidth: big ? 580 : 440)
        .glassPane(radius: 28)
        .padding(.horizontal, AppSpacing.lg)
        .onAppear {
            for s in 1...2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(s)) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { reveal = s }
                    SoundPlayer.shared.play(.correctSmall)
                }
            }
        }
    }
}

/// The game chip in a game's top bar, with "×2" during a surprise round.
struct MiniGameChipLabel: View {
    let text: String
    var surprise: Bool = false
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
            if surprise {
                Text("×2").foregroundStyle(AppColor.starGold)
            }
        }
    }
}

// MARK: - ⚡ The surprise round's interstitial

/// "⚡ סִבּוּב הַפְתָּעָה!" — shown in the runner after 12–15 questions. The big
/// theme emoji, the game's name, ×2 ⭐ 💎, a gold "יַאלְלָה! 🚀" and a quiet
/// "דִּלּוּג" that goes straight back to the questions.
struct SurpriseRoundIntro: View {
    let plan: SurprisePlan
    var onStart: () -> Void
    var onSkip: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @ObservedObject private var display = DisplayGeometry.shared
    @State private var appeared = false
    @State private var confetti = 0
    private var isCompact: Bool { hsc == .compact }
    /// 👶 A pre-reader (גן) can't read the game's name or its rules line.
    private var preReader: Bool { PreReaderGames.activeChildIsPreReader }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 24, size: 13)

            VStack(spacing: display.isShort ? 10 : 14) {
                MiniGameChip {
                    Text(tr("⚡ סִבּוּב הַפְתָּעָה!"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                }
                Text(plan.topic.emoji)
                    .font(.system(size: display.isShort ? 84 : (isCompact ? 112 : 140)))
                    .float(amplitude: 8)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .rotationEffect(.degrees(appeared ? 0 : -20))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                Text(SurpriseRound.themeName(plan.topic))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                Text(plan.game.emoji + " " + plan.game.title)
                    .font(.system(size: isCompact ? 28 : 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                Text(plan.game.subtitle(surprise: true))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                MiniGameChip {
                    Text("×2 ⭐ 💎")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                }
                .glow(AppColor.starGold, radius: 8)
                MiniGameGoldButton(title: tr("יַאלְלָה! 🚀"), action: onStart)
                    .padding(.top, 4)
                Button {
                    Haptic.light()
                    onSkip()
                } label: {
                    Text(tr("דִּלּוּג"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .padding(.horizontal, 20).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("דִּלּוּג"))
            }
            .padding(24)
            .frame(maxWidth: 440)
            .glassPane(radius: 28)
            .padding(.horizontal, AppSpacing.lg)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)

            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { confetti += 1 }
            // 👶 A גן child can't read the game's name here, so it is also
            // said out loud — the words stay on screen for whoever is reading.
            if preReader {
                SpeechReader.shared.speak(PreReaderGames.startCue + " " + plan.game.title)
            }
        }
    }
}

/// The whole ⚡ surprise round as the runner presents it: the interstitial,
/// then the game itself (no intro card — the interstitial was it). Skip, ✕ or
/// "מַמְשִׁיכִים" all lead straight back to the questions.
struct SurpriseRoundFlow: View {
    let plan: SurprisePlan
    var onFinish: () -> Void

    @State private var playing = false

    var body: some View {
        ZStack {
            if playing {
                MiniGameScreen(kind: plan.game, topic: plan.topic, surprise: true, onClose: onFinish)
                    .transition(.opacity)
            } else {
                SurpriseRoundIntro(plan: plan, onStart: {
                    withAnimation(.easeInOut(duration: 0.3)) { playing = true }
                }, onSkip: onFinish)
                .transition(.opacity)
            }
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            SoundPlayer.shared.play(.portalAppear)
            Haptic.success()
            AppAnalytics.log("surprise_round_shown", ["game": plan.game.rawValue, "topic": plan.topic.rawValue])
        }
    }
}

/// Every game's timer: the runner's gold bar, a clock icon and the seconds.
struct MiniGameTimerBar: View {
    let remaining: TimeInterval
    let total: TimeInterval

    private var frac: Double { total > 0 ? max(0, min(1, remaining / total)) : 0 }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.9))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "FFD23F"), Color(hex: "FF9F1C")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * frac))
                        .animation(.linear(duration: 0.1), value: frac)
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
}

/// DEMO_SCREEN host for the mini-games (screenshots / review). DEMO_WORLD
/// themes the game, DEMO_GRADE sets the active child's grade, DEMO_SURPRISE=1
/// plays it as a surprise round; "surpriseround" shows the interstitial first.
///
/// 👶 DEMO_GRADE=0 is גן, so the five pre-reader games deal their text-free
/// boards: DEMO_SCREEN=balloongame DEMO_GRADE=0, and the same for sortgame,
/// pairsgame, patterngame and crushgame — plus DEMO_SCREEN=gamechooser
/// DEMO_GRADE=0 for the chooser they appear in.
struct MiniGameDemoHost: View {
    let screen: String

    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private var topic: Topic? { env["DEMO_WORLD"].flatMap(Topic.init(rawValue:)) }

    static func kind(for screen: String) -> MiniGameKind? {
        switch screen {
        case "pairsgame":     return .pairs
        case "balloongame":   return .balloon
        case "wordgame":      return .word
        case "crushgame":     return .crush
        case "wordsearch":    return .wordSearch
        case "lightninggame": return .lightning
        case "sortgame":      return .sort
        case "patterngame":   return .pattern
        case "game2048":      return .game2048
        case "vaultgame":     return .vault
        case "grocerygame":   return .grocery
        case "balancegame":   return .balance
        default:              return nil
        }
    }

    /// DEMO_EARN=1 plays it as if opened from a world's chooser (earns minutes).
    @State private var earn: MiniGameEarnSession?

    var body: some View {
        Group {
            if screen == "surpriseround" {
                SurpriseRoundFlow(plan: SurprisePlan(topic: topic ?? .soccer,
                                                     game: env["DEMO_GAME"].flatMap(MiniGameKind.init(rawValue:)) ?? .balloon)) {}
            } else if let kind = Self.kind(for: screen) {
                MiniGameScreen(kind: kind, topic: GameContent.sourceTopic(topic) ?? topic,
                               surprise: env["DEMO_SURPRISE"] == "1", earn: earn) {}
            }
        }
        .task {
            if env["DEMO_EARN"] == "1", earn == nil {
                let world = Worlds.all.first { $0.topic == (topic ?? .math) } ?? Worlds.all[0]
                earn = MiniGameEarnSession(world: world)
            }
        }
    }

    /// The grade has to be in place BEFORE the game deals its round: a surprise
    /// round deals in its own `onAppear`, which SwiftUI runs before the host's,
    /// so setting it there handed the screenshot a board at the old grade.
    init(screen: String) {
        self.screen = screen
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
}

#Preview("Surprise intro") {
    SurpriseRoundIntro(plan: SurprisePlan(topic: .soccer, game: .balloon), onStart: {}, onSkip: {})
}
