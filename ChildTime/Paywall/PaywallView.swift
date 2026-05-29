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
    @EnvironmentObject var subs: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc

    @State private var selectedID: String = SubscriptionManager.yearlyID  // year highlighted by default
    @State private var companion = CompanionController()
    @State private var headerAppeared = false
    @State private var burst = 0
    @State private var successConfetti = 0

    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.companionGlow, AppColor.gemPurple],
                count: 6, maxSize: 280, opacity: 0.4
            )
            SparkleField(count: 24, size: 14)
            StarBurst(count: 14, color: AppColor.starGold, trigger: burst)
            Confetti(trigger: successConfetti)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    closeRow
                    hero
                    benefitsCard
                    planPicker
                    primaryCTA
                    footerLinks
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
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
        .onChange(of: subs.subscriptionState) { _, newState in
            // The moment we detect a successful purchase, celebrate + dismiss.
            if case .active = newState { celebrateAndDismiss() }
            if case .inTrial = newState { celebrateAndDismiss() }
        }
    }

    // MARK: - Sub-views

    private var closeRow: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.18), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
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
                .font(.system(size: isCompact ? 52 : 72, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: AppColor.starGold.opacity(0.6), radius: 16)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .scaleEffect(headerAppeared ? 1 : 0.5)
                .opacity(headerAppeared ? 1 : 0)

            Text("חוויה מלאה — לכל הילדים בבית")
                .font(.system(size: isCompact ? 17 : 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.25), radius: 3)
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : 12)
        }
    }

    private var benefitsCard: some View {
        VStack(spacing: 14) {
            benefitRow("🧠", "כל הנושאים", "חשבון, עברית, אנגלית, לוגיקה, מדע, היסטוריה, גיאוגרפיה, כסף")
            divider
            benefitRow("🌍", "כל העולמות", "ממלכת החשבון, שוק הכסף, ועוד")
            divider
            benefitRow("⏱", "זמן פרס ללא הגבלה", "הילד יכול להרוויח כמה דקות שירצה")
            divider
            benefitRow("👨‍👩‍👧‍👦", "כל הילדים במשפחה", "פרופיל לכל ילד עם התקדמות נפרדת")
            divider
            benefitRow("📊", "דוחות הורה שבועיים", "בדיוק איפה הילד חזק, איפה צריך עזרה")
            divider
            benefitRow("☁️", "סנכרון בין מכשירים", "iPad + iPhone, אותה התקדמות")
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
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
                    if isYearly {
                        Text("כולל ניסיון 7 ימים חינם")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.20 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                            .stroke(
                                isSelected ? AppColor.successMint : .white.opacity(0.20),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
            )
            .glow(isSelected ? AppColor.successMint : .clear, radius: isSelected ? 12 : 0)
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
                Text("המַּסְלוּלִים עֲדַיִן לֹא זְמִינִים")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("ודאו שהמנויים ב-App Store Connect במצב \"Ready to Submit\", ושאתם מחוברים לחשבון Sandbox במכשיר.")
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
                        .background(.white.opacity(0.18), in: Capsule())
                }
                .padding(.top, 4)
            }
            if let err = subs.lastError {
                Text(err)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(.white.opacity(0.10))
        )
    }

    // MARK: - Primary CTA

    private var primaryCTA: some View {
        let isYearlySelected = (selectedID == SubscriptionManager.yearlyID)
        let cta = isYearlySelected ? "התחל ניסיון 7 ימים חינם" : "המשך לתשלום"
        let isDisabled = subs.products.isEmpty || subs.isPurchasing

        return VStack(spacing: 6) {
            JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                if let product = subs.products.first(where: { $0.id == selectedID }) {
                    Task { await subs.purchase(product) }
                }
            } label: {
                HStack(spacing: 8) {
                    if subs.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                        Text(cta)
                    }
                }
                .font(.system(size: 22, weight: .heavy, design: .rounded))
            }
            .opacity(isDisabled ? 0.55 : 1)
            .disabled(isDisabled)

            if isYearlySelected,
               let yearly = subs.products.first(where: { $0.id == SubscriptionManager.yearlyID }) {
                Text("בתום הניסיון: \(yearly.displayPrice) / שנה — ניתן לבטל בכל עת בהגדרות Apple ID")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }

            if let err = subs.lastError, !err.isEmpty {
                Text(err)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.red.opacity(0.9))
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
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("•").foregroundStyle(.white.opacity(0.4))
                Link("מדיניות פרטיות",
                     destination: URL(string: "https://github.com/raniop/ChildTime/blob/main/distribution/PRIVACY_POLICY.html")!)
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
