import SwiftUI

/// 🍎 "שִׂימוּ בַּסַּל" — counting by DOING (Sasha, 2026-10-15: "גרור 4 תפוחים
/// לסל"). A pile of apples (or fish, or stars) at the top, a basket at the
/// bottom wearing the number it wants. The child drags — or taps — items into
/// the basket, taps one in the basket to take it back out, and presses ✅ when
/// they think it is right. Too few or too many is never "wrong": Tofy says
/// how to fix it and the basket stays as it is. Five baskets a round, no clock.
struct BasketCountView: View {
    var topic: Topic? = nil
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc
    @Environment(\.isInertPreview) private var inertPreview

    private enum Phase { case intro, playing, done }
    private struct Item: Identifiable, Hashable { let id: Int }
    private struct FrameKey: PreferenceKey {
        static let defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
    }
    private static let space = "basketSpace"
    static let rounds = 5

    @State private var phase: Phase = .intro
    @State private var roundIndex = 0
    @State private var emoji = "🍎"
    @State private var plural = ""
    @State private var target = 3
    @State private var pile: [Item] = []
    @State private var inBasket: [Item] = []
    @State private var dragging: Item?
    @State private var drag: CGSize = .zero
    @State private var basketFrame: CGRect = .zero
    @State private var wiggle = 0
    @State private var hint: String?
    @State private var missedThisRound = false
    @State private var cleanCount = 0
    @State private var doneCount = 0
    @State private var streak = 0
    @State private var shownAt = Date()
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?

    private var isCompact: Bool { hsc == .compact }
    private var topicForLedger: Topic { .math }
    private var cue: PreReaderCue {
        PreReaderCue(spoken: tr("שִׂימוּ \(PreReaderGames.countPhrase(target, plural)) בַּסַּל!"))
    }

    var body: some View {
        ZStack {
            MiniGameBackdrop()
            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "🍎 " + PreReaderChrome.dots(done: doneCount, total: Self.rounds), surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    PreReaderIntroCard(kind: .basket, cue: PreReaderCue(spoken: tr("שִׂימוּ בַּסַּל בְּדִיּוּק כַּמָּה שֶׁצָּרִיךְ, וְלַחֲצוּ ✅"))) { start() }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    PreReaderEndCard(
                        title: cleanCount == Self.rounds ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: tr("מִלֵּאתֶם \(Self.rounds) סַלִּים"),
                        tally: "🧺", tallyCount: doneCount, grant: grant, surprise: surprise,
                        againLabel: tr("עוֹד סִבּוּב 🔁"),
                        onAgain: { start() }, onDone: onClose)
                    Spacer()
                }
            }
            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            if (surprise || earn != nil || inertPreview) && phase == .intro { start() }
        }
    }

    // MARK: Playing

    private var playing: some View {
        let itemSide: CGFloat = isCompact ? 54 : 72
        return VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            PreReaderCueCard(cue: cue, compact: isCompact)
                .id(roundIndex)
            Text(hint ?? PreReaderChrome.streak(streak))
                .font(.system(size: hint == nil ? 15 : 19, weight: .heavy, design: .rounded))
                .foregroundStyle(hint == nil ? AppColor.starGold : .white)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: hint)
            // The pile.
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemSide), spacing: 8), count: 5), spacing: 8) {
                ForEach(pile) { item in pileItem(item, side: itemSide) }
            }
            .frame(maxWidth: .infinity, minHeight: itemSide * 2 + 8, alignment: .top)
            .zIndex(1)
            Spacer(minLength: 0)
            basket(itemSide: itemSide)
            Button { check() } label: {
                Text("✅")
                    .font(.system(size: isCompact ? 34 : 44))
                    .frame(maxWidth: isCompact ? 220 : 300)
                    .frame(height: isCompact ? 62 : 78)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                    .shadow(color: AppColor.starGold.opacity(0.4), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(inBasket.isEmpty)
            .opacity(inBasket.isEmpty ? 0.5 : 1)
            .accessibilityLabel(tr("סִיַּמְנוּ"))
        }
        .frame(maxWidth: isCompact ? 560 : 720)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
        .coordinateSpace(name: Self.space)
    }

    private func pileItem(_ item: Item, side: CGFloat) -> some View {
        let isDragging = dragging == item
        return Text(emoji)
            .font(.system(size: side * 0.72))
            .frame(width: side, height: side)
            .scaleEffect(isDragging ? 1.25 : 1)
            .shadow(color: .black.opacity(isDragging ? 0.3 : 0), radius: 10, y: 8)
            .offset(isDragging ? drag : .zero)
            .zIndex(isDragging ? 5 : 0)
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
                    .onChanged { v in dragging = item; drag = v.translation }
                    .onEnded { v in
                        if basketFrame.insetBy(dx: -20, dy: -20).contains(v.location) {
                            put(item)
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { drag = .zero }
                        }
                        dragging = nil
                    }
            )
            .onTapGesture { put(item) }
            .transition(.scale.combined(with: .opacity))
    }

    private func basket(itemSide: CGFloat) -> some View {
        let small = itemSide * 0.78
        return ZStack(alignment: .top) {
            VStack(spacing: 6) {
                // What is in the basket, five to a row — a tap takes one out.
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(small), spacing: 4), count: 5), spacing: 4) {
                    ForEach(inBasket) { item in
                        Text(emoji)
                            .font(.system(size: small * 0.72))
                            .frame(width: small, height: small)
                            .onTapGesture { takeOut(item) }
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(minHeight: small * 2 + 4, alignment: .bottom)
                Text("🧺").font(.system(size: isCompact ? 46 : 60)).padding(.top, -8)
            }
            .padding(.top, 26).padding(.bottom, 8).padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [7, 5])))
            // The number the basket wants — read left to right like every number.
            HStack(spacing: 6) {
                Text("\(target)").font(.system(size: isCompact ? 30 : 38, weight: .black, design: .rounded))
                Text(emoji).font(.system(size: isCompact ? 24 : 30))
            }
            .environment(\.layoutDirection, .leftToRight)
            .foregroundStyle(Color(hex: "3A2700"))
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
            .offset(y: -22)
        }
        .modifier(MiniGameShake(animatableData: CGFloat(wiggle)))
        .animation(.easeInOut(duration: 0.4), value: wiggle)
        .background(GeometryReader { g in
            Color.clear.preference(key: FrameKey.self, value: g.frame(in: .named(Self.space)))
        })
        .onPreferenceChange(FrameKey.self) { basketFrame = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(inBasket.count) / \(target)")
    }

    // MARK: Logic

    private func level() -> Difficulty {
        ProcessInfo.processInfo.environment["DEMO_LEVEL"].flatMap(Difficulty.init(rawValue:))
            ?? MiniGameLevel.difficulty(for: .math)
    }

    private func start() {
        roundIndex = 0; doneCount = 0; cleanCount = 0; streak = 0; grant = nil
        deal()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    private func deal() {
        let item = PreReaderGames.countables.randomElement()!
        emoji = item.emoji; plural = item.plural
        let range: ClosedRange<Int>
        switch level() { case .easy: range = 2...4; case .medium: range = 2...6; case .hard: range = 5...8 }
        target = Int.random(in: range)
        let extra = Int.random(in: 2...4)
        pile = (0..<min(10, target + extra)).map { Item(id: roundIndex * 100 + $0) }
        inBasket = []
        hint = nil; missedThisRound = false; dragging = nil; drag = .zero
        shownAt = Date()
        if !inertPreview { SpeechReader.shared.speak(cue.spoken) }
    }

    private func put(_ item: Item) {
        guard phase == .playing, pile.contains(item) else { return }
        Haptic.light()
        hint = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            pile.removeAll { $0 == item }
            inBasket.append(item)
            drag = .zero
        }
    }

    private func takeOut(_ item: Item) {
        Haptic.light()
        hint = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            inBasket.removeAll { $0 == item }
            pile.append(item)
        }
    }

    private func check() {
        guard phase == .playing, !inBasket.isEmpty else { return }
        if inBasket.count == target {
            let first = !missedThisRound
            if first { cleanCount += 1; streak += 1 }
            doneCount += 1
            MiniGameLedger.record(correct: true, topic: topicForLedger, responseMs: Date().timeIntervalSince(shownAt) * 1000,
                                  streak: streak, earn: earn, surprise: surprise, retry: !first)
            burst += 1; confetti += 1
            SoundPlayer.shared.play(.correctSmall)
            Haptic.success()
            SpeechReader.shared.speak(PreReaderGames.wellDone)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                guard phase == .playing else { return }
                if roundIndex + 1 < Self.rounds {
                    roundIndex += 1
                    withAnimation(.easeInOut(duration: 0.3)) { deal() }
                } else {
                    finish()
                }
            }
        } else {
            if !missedThisRound {
                missedThisRound = true
                streak = 0
                MiniGameLedger.record(correct: false, topic: topicForLedger, earn: earn, surprise: surprise)
            }
            let line = inBasket.count < target ? tr("כִּמְעַט! צָרִיךְ עוֹד.") : tr("כִּמְעַט! יֵשׁ קְצָת יוֹתֵר מִדַּי — הוֹצִיאוּ מֵהַסַּל.")
            hint = line
            wiggle += 1
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            SpeechReader.shared.speak(line)
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        grant = MiniGameReward.grant(game: "basket", correct: doneCount, starsPer: 1, diamondsPer: 1,
                                     cap: Self.rounds, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        AppAnalytics.log("basket_game_done", ["clean": "\(cleanCount)", "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    BasketCountView(onClose: {})
}
