import SwiftUI
import StoreKit

/// "טופי+" paywall — the screen that asks the parent to subscribe.
///
/// Design priorities, in order:
/// 1. Make the value tangible — the parent should know exactly what they're getting.
/// 2. Highlight the year plan (biggest LTV).
/// 3. Be honest about the trial — no dark patterns.
/// 4. Be beautiful — this is the revenue screen, polish converts.
struct PaywallView: View {
    /// Where the parent came from (card, gift_card, child_request, new_world);
    /// a gift push tapped within the hour overrides it as expiring_push.
    var source: String = "card"
    @EnvironmentObject var subs: SubscriptionManager
    @ObservedObject private var household = HouseholdManager.shared
    @ObservedObject private var remote = RemoteSyncManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc

    @State private var selectedID: String = SubscriptionManager.yearlyID  // year highlighted by default
    @StateObject private var companion = CompanionController()
    @State private var headerAppeared = false
    @State private var burst = 0
    @State private var successConfetti = 0

    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        // Family subscription: bought ONCE on a parent's phone, unlocking every
        // child device through the household. A child device therefore never
        // shows prices or StoreKit — it asks a parent instead (Rani; and Kids
        // Category keeps commerce off the child's surface).
        if ParentSettings.shared.deviceRole == .child {
            AskParentView(onClose: { dismiss() })
        } else {
            paywallBody
        }
    }

    private var paywallBody: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            StarBurst(count: 14, color: AppColor.starGold, trigger: burst)
            FancyConfetti(trigger: successConfetti)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    closeRow
                    hero
                    if let pitch { personalCard(pitch) }
                    benefitsCard
                    planPicker
                    primaryCTA
                    if let pitch { freeForeverLine(pitch) }
                    footerLinks
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            AppAnalytics.paywallView()
            let tapped = UserDefaults.standard.double(forKey: "paywall.pushTapAt")
            let fromPush = tapped > 0 && Date().timeIntervalSince1970 - tapped < 3_600
            household.notePaywallSource(fromPush ? "expiring_push" : source)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                headerAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                burst += 1
                companion.cheer()
            }
            // If products haven't loaded yet (e.g. first-launch), try again now
            if subs.products.isEmpty {
                Task { await subs.loadProducts() }
            }
        }
        .onChangeCompat(of: subs.subscriptionState) { _, newState in
            // The moment we detect a successful purchase, celebrate + dismiss.
            if case .active = newState { celebrateAndDismiss() }
            if case .inTrial = newState { celebrateAndDismiss() }
        }
    }

    // MARK: - 🎁 The personal pitch (approved mockup): the child's own data
    // above the prices, shown while the gift is ending or after it ended.

    private struct Pitch {
        let name: String; let girl: Bool
        let favorite: (world: World, questions: Int, accuracy: Int)?
        let others: [World]
        let worlds: Int; let questions: Int; let accuracy: Int
        let ending: String
    }

    private var pitch: Pitch? {
        guard let hh = household.household else { return nil }
        let until = hh.giftUntil ?? hh.premiumUntil
        let giftActive = hh.premiumSource == "gift" && (until.map { $0 > .now } ?? false)
        guard giftActive || hh.giftEndedAt != nil else { return nil }
        let snaps = ProfileStore.shared.profiles.map { p in
            (p, remote.remoteSnapshots[p.id] ?? ProgressVault.shared.snapshot(for: p.id)) }
        guard let star = snaps.max(by: { $0.1.totalAnswered < $1.1.totalAnswered }), star.1.totalAnswered > 0 else { return nil }
        let (p, snap) = star
        let ranked = snap.topicAnswered.filter { $0.value > 0 }.sorted { $0.value > $1.value }
            .compactMap { pair -> (World, Int, Int)? in
                guard let t = Topic(rawValue: pair.key), let w = Worlds.all.first(where: { $0.topic == t }) else { return nil }
                let c = snap.topicCorrect[pair.key] ?? 0
                return (w, pair.value, Int((Double(c) / Double(pair.value) * 100).rounded())) }
        let ending: String
        if giftActive, let until {
            let d = max(0, Int(ceil(until.timeIntervalSinceNow / 86_400)))
            ending = d == 0 ? "הַמַּתָּנָה מִסְתַּיֶּמֶת הַיּוֹם" : d == 1 ? "הַמַּתָּנָה מִסְתַּיֶּמֶת מָחָר"
                : d == 2 ? "הַמַּתָּנָה מִסְתַּיֶּמֶת בְּעוֹד יוֹמַיִם" : "הַמַּתָּנָה מִסְתַּיֶּמֶת בְּעוֹד \(d) יָמִים"
        } else {
            ending = "הַמַּתָּנָה הִסְתַּיְּמָה · הַהִתְקַדְּמוּת שֶׁל \(p.name) שְׁמוּרָה"
        }
        return Pitch(name: p.name, girl: p.gender == .girl,
                     favorite: ranked.first.map { (world: $0.0, questions: $0.1, accuracy: $0.2) },
                     others: ranked.dropFirst().prefix(2).map(\.0),
                     worlds: ranked.count, questions: snap.totalAnswered,
                     accuracy: Int((Double(snap.totalCorrect) / Double(max(1, snap.totalAnswered)) * 100).rounded()),
                     ending: ending)
    }

    private func personalCard(_ p: Pitch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let fav = p.favorite {
                Text("\(fav.world.emoji) \(p.name) \(p.girl ? "מָצְאָה" : "מָצָא") עוֹלָם שֶׁ\(p.girl ? "הִיא אוֹהֶבֶת" : "הוּא אוֹהֵב")")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                Text("\(p.girl ? "הִיא עָנְתָה" : "הוּא עָנָה") בְּ\(fav.world.name) עַל \(fav.questions) שְׁאֵלוֹת, בְּ\(fav.accuracy)% הַצְלָחָה."
                     + (p.others.isEmpty ? "" : " גַּם \(p.others.map(\.name).joined(separator: " וְ")) בִּפְנִים."))
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("🎉 \(p.name) כְּבָר \(p.girl ? "עָנְתָה" : "עָנָה") עַל \(p.questions) שְׁאֵלוֹת בְּטוֹפִי+")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            HStack(spacing: 8) {
                pitchStat("\(p.worlds)", p.worlds == 1 ? "עוֹלָם" : "עוֹלָמוֹת")
                pitchStat("\(p.questions)", "שְׁאֵלוֹת")
                pitchStat("\(p.accuracy)%", "הַצְלָחָה")
            }
            Text(p.ending)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
        }
        .foregroundStyle(GlassInk.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .padding(16)
        .glassPane(radius: 22)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func pitchStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy, design: .rounded)).monospacedDigit()
            Text(label).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(GlassInk.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .glassInset(radius: 12)
    }

    /// What stays free, in one honest line (approved mockup).
    private func freeForeverLine(_ p: Pitch) -> some View {
        Text("טוֹפִי טַיים וְהַזְּמַן שֶׁ\(p.name) \(p.girl ? "מַרְוִיחָה" : "מַרְוִיחַ") נִשְׁאָרִים חִנָּם תָּמִיד. מָה שֶׁנִּסְגָּר: הָעוֹלָמוֹת, הַמִּשְׂחָקִים, הַזִּירָה וְהַמַּטְלוֹת.")
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Sub-views

    private var closeRow: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.22), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
            }
            .environment(\.layoutDirection, .leftToRight)
            Spacer()
        }
        .padding(.top, AppSpacing.md)
    }

    private var hero: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                CompanionView(controller: companion, size: isCompact ? 110 : 140)
                // Crown floating above
                Text("👑")
                    .font(.system(size: isCompact ? 42 : 54))
                    .offset(y: -(isCompact ? 75 : 95))
                    .shadow(color: AppColor.starGold.opacity(0.7), radius: 10)
                    .scaleEffect(headerAppeared ? 1 : 0.3)
                    .rotationEffect(.degrees(headerAppeared ? 0 : -20))
            }
            .padding(.top, isCompact ? 10 : 24)

            Text("טופי+")
                .font(.system(size: isCompact ? 44 : 60, weight: .black, design: .rounded))
                .foregroundStyle(GlassInk.primary)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                .scaleEffect(headerAppeared ? 1 : 0.5)
                .opacity(headerAppeared ? 1 : 0)

            Text("חוויה מלאה — לכל הילדים בבית")
                .font(.system(size: isCompact ? 17 : 20, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : 12)
        }
    }

    private var benefitsCard: some View {
        VStack(spacing: 14) {
            benefitRow("🧠", "כל הנושאים", "מתמטיקה, עברית, אנגלית, הבנת הנקרא, לוגיקה, מדעים, היסטוריה, גיאוגרפיה, חינוך פיננסי")
            divider
            benefitRow("🌍", "כל העולמות — כולל החדשים", "ממלכת המתמטיקה, יער הסיפורים, זירת הענקים, ⚽ עולם הכדורגל וכל עולם חדש שנוסיף")
            divider
            benefitRow("⏱", "זמן פרס על למידה", "כל תשובה נכונה מזכה בזמן משחק — בכל הנושאים")
            divider
            benefitRow("👨‍👩‍👧‍👦", "כל הילדים במשפחה", "פרופיל לכל ילד עם התקדמות נפרדת")
            divider
            benefitRow("📊", "דוחות הורה שבועיים", "בדיוק איפה הילד חזק, איפה צריך עזרה")
            divider
            benefitRow("☁️", "סנכרון בין מכשירים", "iPad + iPhone, אותה התקדמות")
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.md)
        .glassPane(radius: 22)
    }

    private func benefitRow(_ emoji: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(emoji).font(.system(size: 26))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColor.successMint)
                .padding(6)
                .background(AppColor.successMint.opacity(0.20), in: Circle())
        }
        .padding(.horizontal, AppSpacing.sm)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, AppSpacing.sm)
    }

    // MARK: - Plan picker

    @ViewBuilder
    private var planPicker: some View {
        if subs.products.isEmpty {
            // Products haven't loaded yet (or App Store Connect not configured)
            placeholderPlans
        } else {
            VStack(spacing: 10) {
                ForEach(subs.products, id: \.id) { product in
                    planCard(for: product)
                }
            }
        }
    }

    private func planCard(for product: Product) -> some View {
        let isSelected = selectedID == product.id
        let isYearly = product.id == SubscriptionManager.yearlyID

        return Button {
            Haptic.light()
            SoundPlayer.shared.play(.uiTap)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedID = product.id
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Radio
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColor.successMint : .white.opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(AppColor.successMint)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.hebrewName)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        if let badge = product.savingsBadge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColor.successMint, in: Capsule())
                        }
                    }
                    Text(product.pricePerPeriod)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    if isYearly, subs.yearlyIntroEligible {
                        Text("כולל ניסיון 7 ימים חינם")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .glassPane(radius: 22, strength: isSelected ? 0.18 : 0.10, tint: isSelected ? Color(hex: "8CFFC4") : nil)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color(hex: "8CFFC4").opacity(0.9), lineWidth: 2)
                }
            }
        }
        .buttonStyle(.juicy)
    }

    @ViewBuilder
    private var placeholderPlans: some View {
        VStack(spacing: 8) {
            if subs.isLoadingProducts {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, AppSpacing.md)
                Text("טוֹעֵן מַסְלוּלִים…")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                // Finished loading but got nothing — almost always an App Store
                // setup issue, not an app bug. Give the parent a clear nudge.
                Text("הַמַּסְלוּלִים לֹא נִטְעֲנוּ")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("בִּדְקוּ אֶת חִבּוּר הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
                Button {
                    Task { await subs.loadProducts() }
                } label: {
                    Label("נַסּוּ שׁוּב", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.14))).overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .padding(.top, 4)
            }

        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, AppSpacing.sm)
        .glassPane(radius: 22)
    }

    // MARK: - Primary CTA

    private var primaryCTA: some View {
        let isYearlySelected = (selectedID == SubscriptionManager.yearlyID)
        let cta = (isYearlySelected && subs.yearlyIntroEligible) ? "התחל ניסיון 7 ימים חינם" : "המשך לתשלום"
        let isDisabled = subs.products.isEmpty || subs.isPurchasing

        return VStack(spacing: 6) {
            Button {
                if let product = subs.products.first(where: { $0.id == selectedID }) {
                    household.notePurchaseStarted()
                    Task { await subs.purchase(product) }
                }
            } label: {
                HStack(spacing: 8) {
                    if subs.isPurchasing {
                        ProgressView()
                            .tint(Color(hex: "4B3FBF"))
                    } else {
                        Image(systemName: "sparkles")
                        Text(cta)
                    }
                }
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "4B3FBF"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.92)))
                .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
            }
            .buttonStyle(.juicy)
            .frame(maxWidth: 480)
            .opacity(isDisabled ? 0.55 : 1)
            .disabled(isDisabled)

            if isYearlySelected,
               let yearly = subs.products.first(where: { $0.id == SubscriptionManager.yearlyID }) {
                Text(subs.yearlyIntroEligible
                     ? "בתום הניסיון: \(yearly.displayPrice) / שנה — ניתן לבטל בכל עת בהגדרות Apple ID"
                     : "\(yearly.displayPrice) / שנה — ניתן לבטל בכל עת בהגדרות Apple ID")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }

            if let err = subs.lastError, !err.isEmpty {
                Text(err)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "FFD23F"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 12) {
            Button {
                Haptic.light()
                Task { await subs.restorePurchases() }
            } label: {
                Text("שחזר רכישה קיימת")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .underline()
            }

            HStack(spacing: 18) {
                Link("תנאי שימוש",
                     destination: URL(string: "https://tofyapp.com/terms")!)
                Text("•").foregroundStyle(.white.opacity(0.4))
                Link("מדיניות פרטיות",
                     destination: URL(string: "https://tofyapp.com/privacy")!)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, AppSpacing.sm)
    }

    private func celebrateAndDismiss() {
        successConfetti += 1
        burst += 1
        companion.cheer("יששש!")
        SoundPlayer.shared.play(.levelUp)
        Haptic.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            dismiss()
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
