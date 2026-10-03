import SwiftUI

/// 🛒 "הַמַּכֹּלֶת" — a budget ("💰 50 ₪"), a short shopping list and a shelf of
/// priced items. Tap the list's items into the cart, then at the till work
/// out the total and the change on a number pad. Sized to the grade: whole
/// shekels and small totals in א׳, 4.50 ₪ from ד׳, "20% הֲנָחָה" from ה׳. In
/// the math / money worlds extra items may go in the cart too — past the
/// budget → "אוֹפְּס, חָרַגְנוּ מֵהַתַּקְצִיב" and something comes out. In the
/// English / Hebrew worlds the list is words only: reading it IS the game.
/// Three trips a round.
///
/// Every sum, every change and every list read right first time is an answer:
/// from a world's chooser it earns like a regular question; a ⚡ surprise
/// round pays ⭐/💎 only.
struct GroceryGameView: View {
    var topic: Topic? = nil
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    private enum Phase { case intro, shopping, total, change, done }
    private enum ListMode { case pictures, english, hebrew }

    @State private var phase: Phase = .intro
    @State private var trip: GroceryTrip?
    @State private var tripIndex = 0
    @State private var cart: [GroceryShelfItem] = []
    @State private var readingMissed = false
    @State private var typed = ""
    @State private var tries = 0
    @State private var wellState: MiniGameTileState = .normal
    @State private var note: String?
    @State private var bounce: UUID?
    @State private var shake: CGFloat = 0
    @State private var clean = 0
    @State private var answered = 0
    @State private var shownAt = Date()
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?

    private var isCompact: Bool { hsc == .compact }
    private var trips: Int { surprise ? 2 : 3 }
    private var grade: Int { MiniGameLevel.grade(for: topic == .money ? .money : .math) }
    private var mode: ListMode {
        switch topic {
        case .english?: return .english
        case .hebrew?:  return .hebrew
        default:        return .pictures
        }
    }
    private var mathTopic: Topic { topic == .money ? .money : .math }
    private var cartTotal: Int { cart.map(\.finalPrice).reduce(0, +) }
    private var listDone: Bool {
        guard let trip else { return false }
        return trip.list.allSatisfy { item in cart.contains { $0.id == item.id } }
    }
    private var overBudget: Bool { (trip?.budget ?? .max) < cartTotal }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "🛒 \(min(tripIndex + 1, trips))/\(trips)", surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    MiniGameIntroCard(kind: .grocery) { start() }
                    Spacer()
                case .shopping:
                    shopping
                case .total, .change:
                    till
                case .done:
                    Spacer()
                    MiniGameEndCard(
                        title: clean == answered ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: tr("\(trips) קְנִיּוֹת בַּמַּכֹּלֶת!"),
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

    // MARK: - Names

    private func listName(_ p: GroceryProduct) -> String {
        switch mode {
        case .english:  return p.english
        case .hebrew:   return p.hebrew
        case .pictures: return p.emoji + " " + GroceryGen.localName(p)
        }
    }

    private func price(_ item: GroceryShelfItem) -> String { MiniGameText.ltr(GroceryGen.money(item.price)) }

    // MARK: - Shopping

    private var shopping: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            // The list and the budget, in the runner's question card.
            VStack(spacing: 10) {
                HStack {
                    Text(tr("רְשִׁימַת קְנִיּוֹת"))
                        .font(.system(size: isCompact ? 18 : 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    MiniGameChip {
                        Text("💰 " + MiniGameText.ltr(GroceryGen.money(trip?.budget ?? 0)))
                            .font(.system(size: isCompact ? 16 : 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                    }
                }
                FlowChips(items: trip?.list ?? []) { item in
                    let inCart = cart.contains { $0.id == item.id }
                    HStack(spacing: 6) {
                        Image(systemName: inCart ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(inCart ? AppColor.successMint : .white.opacity(0.7))
                        Text(listName(item.product))
                            .font(.system(size: isCompact ? 17 : 21, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .environment(\.layoutDirection, mode == .english ? .leftToRight : .app)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(inCart ? AppColor.successMint.opacity(0.25) : .white.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(14)
            .glassPane(radius: 22)

            // The shelf.
            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: isCompact ? 3 : 4)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(Array((trip?.shelf ?? []).enumerated()), id: \.element.id) { i, item in
                    shelfItem(item, tint: OptionCard.tints[i % OptionCard.tints.count])
                }
            }

            // The cart.
            HStack(spacing: 8) {
                Text("🛒").font(.system(size: 26))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(cart) { item in
                            Button { remove(item) } label: {
                                Text(item.product.emoji)
                                    .font(.system(size: 24))
                                    .padding(6)
                                    .background(Circle().fill(.white.opacity(0.16)))
                            }
                            .buttonStyle(.juicy)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(minHeight: 54)
            .glassInset(radius: 18)

            if let note {
                Text(note)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.almostWarm)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else if overBudget {
                Text(tr("אוֹפְּס, חָרַגְנוּ מֵהַתַּקְצִיב — מוֹצִיאִים מַשֶּׁהוּ מֵהָעֲגָלָה 🛒"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.almostWarm)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            MiniGameGoldButton(title: tr("לַקֻּפָּה 🧾")) { checkout() }
                .opacity(listDone && !overBudget ? 1 : 0.5)
                .disabled(!listDone || overBudget)
        }
        .frame(maxWidth: isCompact ? 600 : 760)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    private func shelfItem(_ item: GroceryShelfItem, tint: Color) -> some View {
        let inCart = cart.contains { $0.id == item.id }
        return Button { add(item) } label: {
            VStack(spacing: 4) {
                Text(item.product.emoji).font(.system(size: isCompact ? 34 : 46))
                if mode == .pictures {
                    Text(GroceryGen.localName(item.product))
                        .font(.system(size: isCompact ? 12 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Text(price(item))
                    .font(.system(size: isCompact ? 16 : 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .strikethrough(item.discount > 0, color: .white.opacity(0.7))
                    .mathLTR()
                if item.discount > 0 {
                    Text(tr("\(item.discount)% הֲנָחָה"))
                        .font(.system(size: isCompact ? 11.5 : 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: isCompact ? 104 : 136)
            .padding(.vertical, 6)
            .miniGameTile(inCart ? .picked : (bounce == item.id ? .wrong : .normal), tint: tint, radius: 18)
            .opacity(inCart ? 0.55 : 1)
            .modifier(MiniGameShake(animatableData: bounce == item.id ? shake : 0))
        }
        .buttonStyle(.juicy)
        .disabled(inCart)
    }

    // MARK: - Till

    private var till: some View {
        let isTotal = phase == .total
        let budgetText = MiniGameText.ltr(GroceryGen.money(trip?.budget ?? 0))
        return VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            VStack(spacing: 10) {
                Text(isTotal ? tr("כַּמָּה עוֹלֶה הַכֹּל?")
                             : tr("כַּמָּה עֹדֶף נְקַבֵּל מִ־\(budgetText)?"))
                    .font(.system(size: isCompact ? 22 : 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                // The receipt.
                VStack(spacing: 4) {
                    ForEach(cart) { item in
                        HStack {
                            Text(item.product.emoji + " " + GroceryGen.localName(item.product))
                            Spacer()
                            if item.discount > 0 {
                                Text(tr("\(item.discount)% הֲנָחָה"))
                                    .foregroundStyle(AppColor.starGold)
                                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            }
                            Text(price(item)).monospacedDigit().mathLTR()
                        }
                    }
                    if !isTotal {
                        Divider().overlay(.white.opacity(0.3))
                        HStack {
                            Text(tr("סַךְ הַכֹּל"))
                            Spacer()
                            Text(MiniGameText.ltr(GroceryGen.money(cartTotal))).monospacedDigit().mathLTR()
                        }
                        .foregroundStyle(AppColor.starGold)
                    }
                }
                .font(.system(size: isCompact ? 15 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(12)
                .glassInset(radius: 14)
            }
            .padding(14)
            .glassPane(radius: 22)

            MiniGameAnswerWell(text: typed, state: wellState, suffix: Money.answerSuffix, prefix: Money.answerPrefix,
                               height: isCompact ? 60 : 76)
                .modifier(MiniGameShake(animatableData: shake))
            if let note {
                Text(note)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.almostWarm)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            MiniGameNumberPad(decimal: trip?.decimals ?? false, keyHeight: display.isShort ? 40 : (isCompact ? 48 : 62)) { k in press(k) }
                .frame(maxWidth: isCompact ? 340 : 440)
            MiniGameGoldButton(title: tr("בְּדִיקָה ✓")) { check() }
                .frame(maxWidth: isCompact ? 340 : 440)
                .opacity(typed.isEmpty ? 0.5 : 1)
                .disabled(typed.isEmpty || wellState == .correct)
        }
        .frame(maxWidth: isCompact ? 600 : 760)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    // MARK: - Logic

    private func start() {
        tripIndex = 0; clean = 0; answered = 0; grant = nil
        newTrip()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .shopping }
    }

    private func newTrip() {
        trip = GroceryGen.trip(grade: grade)
        cart = []; readingMissed = false; typed = ""; tries = 0; wellState = .normal; note = nil
        shownAt = Date()
    }

    private func add(_ item: GroceryShelfItem) {
        guard phase == .shopping, let trip, !cart.contains(where: { $0.id == item.id }) else { return }
        let onList = trip.list.contains { $0.id == item.id }
        // Reading worlds: the list is the lesson — a word not on it bounces back.
        if mode != .pictures && !onList {
            if !readingMissed {
                readingMissed = true
                MiniGameLedger.record(correct: false, topic: topic ?? .english, earn: earn, surprise: surprise)
            }
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            bounce = item.id
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
            withAnimation { note = tr("זֶה לֹא בָּרְשִׁימָה — קִרְאוּ שׁוּב 📝") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { if bounce == item.id { bounce = nil; note = nil } }
            }
            return
        }
        SoundPlayer.shared.play(.uiTap)
        Haptic.light()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { cart.append(item); note = nil }
    }

    private func remove(_ item: GroceryShelfItem) {
        Haptic.selection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { cart.removeAll { $0.id == item.id } }
    }

    private func checkout() {
        guard listDone, !overBudget else { return }
        if mode != .pictures && !readingMissed {
            MiniGameLedger.record(correct: true, topic: topic ?? .english,
                                  responseMs: Date().timeIntervalSince(shownAt) * 1000, earn: earn, surprise: surprise)
        }
        SoundPlayer.shared.play(.correctSmall)
        typed = ""; tries = 0; wellState = .normal; note = nil; shownAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .total }
    }

    private func press(_ k: String) {
        guard wellState != .correct else { return }
        if k == "⌫" { if !typed.isEmpty { typed.removeLast() }; return }
        if k == "." && (typed.contains(".") || typed.isEmpty) { return }
        if let dot = typed.firstIndex(of: "."), typed.distance(from: dot, to: typed.endIndex) > 2 { return }
        guard typed.count < 7 else { return }
        typed += k
        if wellState == .wrong { wellState = .normal }
    }

    private func check() {
        guard let trip, let value = GroceryGen.cents(typed) else { return }
        let target = phase == .total ? cartTotal : trip.budget - cartTotal
        if value == target {
            if tries == 0 {
                clean += 1
                MiniGameLedger.record(correct: true, topic: mathTopic, responseMs: Date().timeIntervalSince(shownAt) * 1000,
                                      earn: earn, surprise: surprise)
            }
            answered += 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { wellState = .correct; note = nil }
            burst += 1
            SoundPlayer.shared.play(.correctBig)
            Haptic.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { advance() }
            return
        }
        tries += 1
        if tries == 1 {
            MiniGameLedger.record(correct: false, topic: mathTopic, earn: earn, surprise: surprise)
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
            withAnimation { wellState = .wrong; note = tr("כִּמְעַט! נְנַסֶּה שׁוּב 💪") }
        } else {
            // The second miss: the right amount appears, and the trip goes on.
            answered += 1
            let shown = GroceryGen.money(target)
                .replacingOccurrences(of: Money.answerPrefix, with: "")
                .replacingOccurrences(of: Money.answerSuffix, with: "")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                typed = shown
                wellState = .correct
                note = tr("הִנֵּה הַתְּשׁוּבָה — מַמְשִׁיכִים! ✨")
            }
            SoundPlayer.shared.play(.uiTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { advance() }
        }
    }

    private func advance() {
        guard phase == .total || phase == .change else { return }
        typed = ""; tries = 0; wellState = .normal; note = nil; shownAt = Date()
        if phase == .total {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .change }
            return
        }
        if tripIndex + 1 < trips {
            tripIndex += 1
            newTrip()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .shopping }
        } else {
            finish()
        }
    }

    private func finish() {
        grant = MiniGameReward.grant(game: "grocery", correct: clean, starsPer: 2, diamondsPer: 1,
                                     cap: 6, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        confetti += 1
        AppAnalytics.log("grocery_done", ["clean": "\(clean)/\(answered)", "surprise": surprise ? "1" : "0"])
    }
}

/// Chips that wrap onto as many lines as they need.
struct FlowChips<Item: Identifiable, Chip: View>: View {
    let items: [Item]
    @ViewBuilder var chip: (Item) -> Chip

    var body: some View {
        if #available(iOS 16.0, *) {
            FlowLayout(spacing: 8) {
                ForEach(items) { chip($0) }
            }
        }
    }
}

/// A minimal wrapping layout (left/right follows the layout direction).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(maxW, widest), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Rows are measured first so each can be centred.
        var rows: [[(LayoutSubview, CGSize)]] = [[]]
        var x: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > bounds.width { rows.append([]); x = 0 }
            rows[rows.count - 1].append((v, s))
            x += s.width + spacing
        }
        var y = bounds.minY
        for row in rows {
            let w = row.map(\.1.width).reduce(0, +) + spacing * CGFloat(max(0, row.count - 1))
            let h = row.map(\.1.height).max() ?? 0
            var cx = bounds.minX + (bounds.width - w) / 2
            for (v, s) in row {
                v.place(at: CGPoint(x: cx, y: y + (h - s.height) / 2), proposal: ProposedViewSize(s))
                cx += s.width + spacing
            }
            y += h + spacing
        }
    }
}
