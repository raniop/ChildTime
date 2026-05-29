import SwiftUI

/// The cosmetics shop. Kids spend gems to unlock hats, glasses, shirts,
/// shoes, vehicles, etc., then equip them on their profile.
///
/// Layout: top hero (live avatar preview + gem balance), horizontal
/// category strip, then a grid of items in the selected category.
struct ShopView: View {
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var cosmetics: CosmeticStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc

    @State private var selectedCategory: CosmeticCategory = .hat
    @State private var detailItem: CosmeticItem? = nil
    @State private var purchaseError: String? = nil
    @State private var celebrateTrigger = 0
    @State private var confettiTrigger = 0
    @State private var showingProfileEditor = false

    private var isCompact: Bool { hsc == .compact }
    private var avatarSize: CGFloat { isCompact ? 130 : 170 }
    private var itemsInCategory: [CosmeticItem] {
        CosmeticCatalog.items(in: selectedCategory)
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.gemPurple, AppColor.starGold, AppColor.companionGlow],
                count: 6, maxSize: 280, opacity: 0.35
            )
            SparkleField(count: 22, size: 14)
            StarBurst(count: 14, color: AppColor.starGold, trigger: celebrateTrigger)
            Confetti(trigger: confettiTrigger)

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        hero
                        categoryStrip
                        itemsGrid
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxxl)
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(item: $detailItem) { item in
            ShopItemDetail(item: item) {
                attemptPurchase(item)
            }
            .environmentObject(profiles)
            .environmentObject(progress)
            .environmentObject(cosmetics)
            .environment(\.layoutDirection, .rightToLeft)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingProfileEditor) {
            if let active = profiles.active {
                ProfileEditorView(mode: .edit(active)) { updated in
                    profiles.update(updated)
                } onDelete: { profile in
                    profiles.remove(profile)
                }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .alert("רֶגַע", isPresented: Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })) {
            Button("הֵבַנְתִּי", role: .cancel) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.18), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            }
            .environment(\.layoutDirection, .leftToRight)

            Spacer()

            Text("חֲנוּת הַקֶּסֶם")
                .font(.system(size: isCompact ? 20 : 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppColor.starGold.opacity(0.7), radius: 8)

            Spacer()

            // Star balance — the single currency.
            HStack(spacing: 4) {
                Text("⭐").font(.system(size: 16))
                Text("\(progress.stars)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(progress.stars)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(AppColor.starGold.opacity(0.4)))
            .overlay(Capsule().stroke(AppColor.starGold, lineWidth: 1.5))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        if let profile = profiles.active {
            VStack(spacing: 6) {
                ProfileAvatarView(profile: profile, size: avatarSize)
                Text(profile.name)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("הַלְבִּישׁוּ אֶת \(profile.name)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                // Edit-profile shortcut, right where the avatar lives.
                Button {
                    Haptic.light()
                    showingProfileEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("עֲרֹךְ פְּרוֹפִיל")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.top, AppSpacing.sm)
        } else {
            Text("צְרוּ פְּרוֹפִיל כְּדֵי לְהַתְחִיל")
                .foregroundStyle(.white)
        }
    }

    // MARK: - Category strip

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CosmeticCategory.allCases.sorted { $0.sortOrder < $1.sortOrder }) { cat in
                    categoryChip(cat)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollClipDisabled()
    }

    private func categoryChip(_ cat: CosmeticCategory) -> some View {
        let selected = selectedCategory == cat
        return Button {
            Haptic.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategory = cat
            }
        } label: {
            HStack(spacing: 6) {
                Text(cat.icon).font(.system(size: 18))
                Text(cat.displayName)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(.white.opacity(selected ? 0.28 : 0.12))
            )
            .overlay(
                Capsule().stroke(
                    selected ? AppColor.starGold : .white.opacity(0.2),
                    lineWidth: selected ? 2 : 1
                )
            )
            .glow(selected ? AppColor.starGold : .clear, radius: selected ? 8 : 0)
        }
        .buttonStyle(.juicy)
    }

    // MARK: - Items grid

    private var itemsGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: isCompact ? 130 : 160), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(itemsInCategory) { item in
                itemCard(item)
            }
        }
    }

    private func itemCard(_ item: CosmeticItem) -> some View {
        let owned = cosmetics.owns(item)
        let equipped: Bool = {
            guard let pid = profiles.activeID else { return false }
            return cosmetics.equipped(for: pid, in: item.category)?.id == item.id
        }()
        return Button {
            Haptic.light()
            detailItem = item
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .fill(.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                                .stroke(item.rarity.color.opacity(0.7), lineWidth: 1.5)
                        )
                    Text(item.emoji)
                        .font(.system(size: isCompact ? 50 : 64))
                        .padding(.vertical, 8)
                    if equipped {
                        VStack { HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColor.successMint)
                                .background(Circle().fill(.white).scaleEffect(0.7))
                                .font(.system(size: 22))
                        }; Spacer() }
                        .padding(8)
                    } else if !owned {
                        VStack { HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.white.opacity(0.6))
                                .font(.system(size: 14))
                        }; Spacer() }
                        .padding(10)
                    }
                }
                .frame(height: isCompact ? 90 : 120)

                Text(item.name)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                rarityBadge(item.rarity)

                priceOrStatusFooter(item: item, owned: owned, equipped: equipped)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
        }
        .buttonStyle(.juicy)
    }

    private func rarityBadge(_ rarity: CosmeticRarity) -> some View {
        Text(rarity.label)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(rarity.gradient))
    }

    @ViewBuilder
    private func priceOrStatusFooter(item: CosmeticItem, owned: Bool, equipped: Bool) -> some View {
        if equipped {
            Text("לָבוּשׁ 👤")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.successMint)
        } else if owned {
            Text("בִּרְשׁוּתְךָ")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        } else {
            HStack(spacing: 3) {
                Text("⭐").font(.system(size: 11))
                Text("\(item.price)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(progress.stars >= item.price ? .white : AppColor.almostWarm)
            }
        }
    }

    // MARK: - Purchase

    private func attemptPurchase(_ item: CosmeticItem) {
        guard let pid = profiles.activeID else { return }
        // Already owned → just equip (or un-equip if already wearing).
        if cosmetics.owns(item) {
            if cosmetics.equipped(for: pid, in: item.category)?.id == item.id {
                cosmetics.equip(nil, in: item.category, for: pid)
            } else {
                cosmetics.equip(item, in: item.category, for: pid)
            }
            Haptic.success()
            SoundPlayer.shared.play(.uiTap)
            detailItem = nil
            return
        }
        // Otherwise — try to buy.
        do {
            try cosmetics.purchase(item, for: pid)
            celebrateTrigger += 1
            confettiTrigger += 1
            SoundPlayer.shared.play(.chestOpen)
            Haptic.success()
            detailItem = nil
        } catch let err as CosmeticStore.PurchaseError {
            purchaseError = err.errorDescription
            Haptic.warning()
        } catch {
            purchaseError = error.localizedDescription
            Haptic.warning()
        }
    }
}

// MARK: - Detail sheet

struct ShopItemDetail: View {
    let item: CosmeticItem
    let onPrimary: () -> Void

    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var cosmetics: CosmeticStore
    @Environment(\.dismiss) private var dismiss

    private var profile: Profile? { profiles.active }
    private var owned: Bool { cosmetics.owns(item) }
    private var equipped: Bool {
        guard let pid = profiles.activeID else { return false }
        return cosmetics.equipped(for: pid, in: item.category)?.id == item.id
    }
    private var canAfford: Bool { progress.stars >= item.price }

    /// Preview loadout: take the kid's current outfit but replace this
    /// category with the item being considered, so they see how it looks.
    private var previewItems: [CosmeticItem] {
        guard let pid = profiles.activeID else { return [item] }
        var items = cosmetics.equippedItems(for: pid).filter { $0.category != item.category }
        items.append(item)
        return items
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 14, size: 12)

            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: 12)

                // Live preview on the kid's avatar
                if let profile {
                    ProfileAvatarView(profile: profile, size: 170, overrideItems: previewItems)
                }

                VStack(spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Text(item.category.icon)
                        Text(item.category.displayName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(item.rarity.label)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(item.rarity.gradient))
                }

                Spacer()

                primaryButton

                if !owned && !canAfford {
                    Text("חֲסֵרִים \(item.price - progress.stars) כּוֹכָבִים ⭐")
                        .font(.caption)
                        .foregroundStyle(AppColor.almostWarm)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if equipped {
            JuicyButton(gradient: AppGradient.almost, glowColor: AppColor.almostWarm) {
                onPrimary()
            } label: {
                Label("הָסֵר מֵהַדְּמוּת", systemImage: "xmark.circle")
            }
        } else if owned {
            JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                onPrimary()
            } label: {
                Label("הַלְבֵּשׁ", systemImage: "sparkles")
            }
        } else {
            JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                onPrimary()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                    Text("קְנֵה בְּ-\(item.price) ⭐")
                }
            }
            .opacity(canAfford ? 1 : 0.55)
            .disabled(!canAfford)
        }
    }
}

#Preview {
    ShopView()
        .environmentObject(ProfileStore.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(CosmeticStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
