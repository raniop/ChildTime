import SwiftUI
import StoreKit

/// Buy star packs with real money. ALWAYS presented inside `ParentGateView`, so
/// a child can't purchase without a parent entering the PIN / Face ID.
struct StarShopView: View {
    @ObservedObject private var store = StarPackStore.shared
    @ObservedObject private var progress = ProgressStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var celebrate: Int? = nil

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 18, size: 12)

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        balanceCard
                        if store.products.isEmpty {
                            placeholder
                        } else {
                            ForEach(store.products, id: \.id) { product in
                                packRow(product)
                            }
                        }
                        Text("הָרְכִישָׁה דּוֹרֶשֶׁת אִישּׁוּר Apple ID (סִיסְמָה / Face ID). הַכּוֹכָבִים מְשַׁמְּשִׁים לִקְנִיַּת דְּמוּיוֹת בְּתוֹךְ הָאַפְּלִיקַצְיָה בִּלְבַד.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.top, AppSpacing.sm)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                }
            }

            if let amount = celebrate {
                StarGrantCelebration(amount: amount) { celebrate = nil }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: store.lastGrantedStars) { _, new in
            if let new { celebrate = new; store.lastGrantedStars = nil; Haptic.success() }
        }
    }

    private var header: some View {
        ZStack {
            Text("חֲנוּת כּוֹכָבִים")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppColor.starGold.opacity(0.7), radius: 8)
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var balanceCard: some View {
        HStack(spacing: 8) {
            Text("⭐").font(.system(size: 26))
            Text("\(progress.stars)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("כּוֹכָבִים שֶׁלְּךָ")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.12)))
    }

    private func packRow(_ product: Product) -> some View {
        let stars = StarPackStore.stars(for: product.id)
        let best = store.isBestValue(product)
        return Button {
            Task { _ = await store.purchase(product) }
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle().fill(AppColor.starGold.opacity(0.25)).frame(width: 58, height: 58)
                    Text("⭐").font(.system(size: 30))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stars) כּוֹכָבִים")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if best {
                        Text("הֲכִי מִשְׁתַּלֵּם 🔥")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(AppColor.gemPurple))
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(best ? AppColor.starGold : .white.opacity(0.2), lineWidth: best ? 2.5 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
        .opacity(store.isPurchasing ? 0.6 : 1)
    }

    @ViewBuilder
    private var placeholder: some View {
        if !store.didAttemptLoad {
            // Genuinely still loading.
            VStack(spacing: AppSpacing.sm) {
                ProgressView().tint(.white)
                Text("טוֹעֵן חֲבִילוֹת…")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.vertical, AppSpacing.xl)
        } else {
            // Loaded but empty — products aren't configured / available yet.
            VStack(spacing: AppSpacing.md) {
                Text("🛒").font(.system(size: 44))
                Text("הַחֲבִילוֹת אֵינָן זְמִינוֹת כָּרֶגַע")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("נַסּוּ שׁוּב בְּעוֹד רֶגַע.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Button {
                    Task { await store.reload() }
                } label: {
                    Text("נַסּוּ שׁוּב")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Capsule().fill(AppColor.gemPurple))
                }
                if let err = store.lastError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, AppSpacing.xl)
        }
    }
}

/// Brief full-screen celebration when a star pack lands.
private struct StarGrantCelebration: View {
    let amount: Int
    var onDone: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Text("⭐").font(.system(size: 90)).scaleEffect(shown ? 1 : 0.4)
                Text("+\(amount)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
                Text("כּוֹכָבִים נוֹסְפוּ!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .scaleEffect(shown ? 1 : 0.8)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onDone() }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
