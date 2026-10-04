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
        .onAppear { if (surprise || earn != nil) && phase == .intro { start() } }
    }

    // MARK: - Names

    private func listName(_ p: GroceryProduct) -> String {
        switch mode {
        case .english:  return p.english
        case .hebrew:   return p.hebrew
        case .pictures: return p.emoji + " " + GroceryGen.localName(p)
        }
    }

    /// The sticker price on the shelf — struck through when the item is on sale.
    private func price(_ item: GroceryShelfItem) -> String { MiniGameText.ltr(GroceryGen.money(item.price)) }
    /// What the till actually charges. The receipt has to show THIS: a bill that
    /// prints the pre-sale price and then asks for the post-sale total is a
    /// wrong sum on screen (Rani: "the answer was 62.50 and it wrote 60").
    private func tillPrice(_ item: GroceryShelfItem) -> String { MiniGameText.ltr(GroceryGen.money(item.finalPrice)) }

    // MARK: - Shopping

    /// A canvas wider than it is tall — an iPad in landscape, a phone turned on
    /// its side, the foldable held open. One tall column there stacks into the
    /// top third and leaves a void under it (Rani, iPad Pro 13" landscape), so
    /// the board goes side by side and the whole thing centres.
    private var isWideCanvas: Bool {
        let s = display.safeSize
        return s.width > 0 && s.width >= s.height * 1.2
    }

    /// The shelf always holds six, so the grid gets a column count that divides
    /// six evenly — 3 × 2, never the broken-looking 4 + 2 an iPad used to show.
    private var shelfColumns: Int { 3 }

    private var shopping: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            Spacer(minLength: 0)
            if isWideCanvas {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                        listPane
                        shelfGrid
                    }
                    // No Spacer in here: a greedy column would eat the height the
                    // two outer Spacers need to centre the whole board.
                    VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                        cartStrip
                        shoppingNote
                        checkoutButton
                    }
                    .frame(maxWidth: 300)
                }
            } else {
                listPane
                shelfGrid
                cartStrip
                shoppingNote
                checkoutButton
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 600 : (isWideCanvas ? 1100 : 760))
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    // The list and the budget, in the runner's question card.
    private var listPane: some View {
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
            // A chooser or a ⚡ round skips the intro card, so the rule of the
            // game has to be on the board itself (the vault's lesson).
            Text(mode == .pictures
                 ? tr("אוֹסְפִים מֵהַמַּדָּף אֶת כָּל מָה שֶׁבָּרְשִׁימָה וְהוֹלְכִים לַקֻּפָּה")
                 : tr("קוֹרְאִים כָּל מִלָּה, מוֹצְאִים אוֹתָהּ עַל הַמַּדָּף — וְאָז לַקֻּפָּה"))
                .font(.system(size: isCompact ? 13 : 15, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
    }

    private var shelfGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: shelfColumns)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(Array((trip?.shelf ?? []).enumerated()), id: \.element.id) { i, item in
                shelfItem(item, tint: OptionCard.tints[i % OptionCard.tints.count])
            }
        }
    }

    // The cart.
    private var cartStrip: some View {
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
    }

    @ViewBuilder private var shoppingNote: some View {
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
    }

    private var checkoutButton: some View {
        MiniGameGoldButton(title: tr("לַקֻּפָּה 🧾")) { checkout() }
            .opacity(listDone && !overBudget ? 1 : 0.5)
            .disabled(!listDone || overBudget)
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

    /// The bill. Every line says what that item costs at this till — a sale
    /// line shows the sticker price struck through, the discount, and the price
    /// that goes into the sum, in gold.
    private var receipt: some View {
        VStack(spacing: 4) {
            ForEach(cart) { item in
                HStack(spacing: 6) {
                    Text(item.product.emoji + " " + GroceryGen.localName(item.product))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    if item.discount > 0 {
                        Text(tr("\(item.discount)% הֲנָחָה"))
                            .foregroundStyle(AppColor.starGold)
                            .font(.system(size: isCompact ? 11.5 : 13.5, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                        Text(price(item))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.55))
                            .strikethrough(true, color: .white.opacity(0.55))
                            .mathLTR()
                    }
                    Text(tillPrice(item))
                        .monospacedDigit()
                        .foregroundStyle(item.discount > 0 ? AppColor.starGold : .white)
                        .mathLTR()
                }
            }
        }
        .font(.system(size: isCompact ? 15 : 18, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .padding(12)
        .glassInset(radius: 14)
    }

    /// What the change question is actually about: the bill, and the note handed
    /// over the counter.
    private var paid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(tr("🧾 הַקְּנִיּוֹת עָלוּ"))
                Spacer(minLength: 4)
                Text(MiniGameText.ltr(GroceryGen.money(cartTotal))).monospacedDigit().mathLTR()
            }
            HStack(spacing: 6) {
                Text(tr("💰 נָתַנּוּ לַקֻּפָּה"))
                Spacer(minLength: 4)
                Text(MiniGameText.ltr(GroceryGen.money(trip?.budget ?? 0))).monospacedDigit().mathLTR()
            }
            .foregroundStyle(AppColor.starGold)
        }
        .font(.system(size: isCompact ? 16 : 19, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1).minimumScaleFactor(0.7)
        .padding(12)
        .glassInset(radius: 14)
    }

    private var till: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            Spacer(minLength: 0)
            if isWideCanvas {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    tillQuestion.frame(maxWidth: .infinity)
                    tillAnswer.frame(maxWidth: isCompact ? 340 : 440)
                }
            } else {
                tillQuestion
                tillAnswer
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 600 : (isWideCanvas ? 1100 : 760))
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    private var tillQuestion: some View {
        let isTotal = phase == .total
        return VStack(spacing: display.isShort ? 6 : 10) {
            // Two questions at the till, and the child is told which one this
            // is — the change used to arrive with no warning (Rani).
            Text(tr("שְׁאֵלָה \(isTotal ? 1 : 2) מִתּוֹךְ 2"))
                .font(.system(size: isCompact ? 13 : 15, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
            Text(isTotal ? tr("כַּמָּה עוֹלֶה הַכֹּל?") : tr("כַּמָּה עֹדֶף נְקַבֵּל?"))
                .font(.system(size: isCompact ? 22 : 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(isTotal ? tr("מְחַבְּרִים אֶת כָּל הַמְּחִירִים שֶׁבַּקַּבָּלָה")
                         : tr("הָעֹדֶף הוּא מַה שֶׁנָּתַנּוּ פָּחוֹת מַה שֶׁהַקְּנִיּוֹת עָלוּ"))
                .font(.system(size: isCompact ? 13 : 15, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if isTotal { receipt } else { paid }
        }
        .padding(14)
        .glassPane(radius: 22)
    }

    private var tillAnswer: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            MiniGameAnswerWell(text: typed, state: wellState, suffix: Money.answerSuffix, prefix: Money.answerPrefix,
                               height: isCompact ? 60 : 76)
                .modifier(MiniGameShake(animatableData: shake))
            if let note {
                Text(note)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.almostWarm)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
            MiniGameNumberPad(decimal: trip?.decimals ?? false, keyHeight: display.isShort ? 40 : (isCompact ? 48 : 62)) { k in press(k) }
                .frame(maxWidth: isCompact ? 340 : 440)
            MiniGameGoldButton(title: tr("בְּדִיקָה ✓")) { check() }
                .frame(maxWidth: isCompact ? 340 : 440)
                .opacity(typed.isEmpty ? 0.5 : 1)
                .disabled(typed.isEmpty || wellState == .correct)
        }
    }

    // MARK: - Logic

    private func start() {
        tripIndex = 0; clean = 0; answered = 0; grant = nil
        newTrip()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .shopping }
    }

    private func newTrip() {
        trip = GroceryGen.trip(grade: grade, reading: mode != .pictures)
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
            // The well is emptied for the second go: the child retypes instead of
            // editing, and a second tap on ✓ can no longer re-submit the same
            // amount and burn the last try before they have touched the pad.
            withAnimation { typed = ""; wellState = .wrong; note = tr("כִּמְעַט! נְנַסֶּה שׁוּב 💪") }
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
