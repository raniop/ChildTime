import SwiftUI

/// The collectible-character grid + buy/equip flow, shared by the character
/// picker and the shop. Renders every character as a card with its rarity tier
/// (color + badge), 💎 price for locked ones, and a check on the equipped one.
/// Tapping an owned character equips it; a locked one runs a buy-and-equip
/// confirmation (or routes to the diamond shop when short on diamonds).
struct CharacterCollectionView: View {
    let profileID: UUID
    /// Parent owns the (parent-gated) star-shop sheet; we flip this to open it.
    @Binding var showStarShop: Bool
    /// Called after a character is equipped (e.g. the picker dismisses itself).
    var onPicked: (() -> Void)? = nil

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var characters = CharacterStore.shared
    @ObservedObject private var progress = ProgressStore.shared
    @Environment(\.horizontalSizeClass) private var hsc

    @State private var pendingPurchase: Character3D?
    @State private var shortBy: Int?

    private var selectedID: String {
        profiles.profiles.first { $0.id == profileID }?.character3DID ?? Character3DCatalog.defaultID
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: hsc == .compact ? 150 : 200), spacing: AppSpacing.md)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.md) {
            ForEach(Character3DCatalog.all) { character in
                card(character)
            }
        }
        .confirmationDialog(
            pendingPurchase.map { "\($0.name) — \($0.priceDiamonds) 💎" } ?? "",
            isPresented: Binding(get: { pendingPurchase != nil },
                                 set: { if !$0 { pendingPurchase = nil } }),
            titleVisibility: .visible,
            presenting: pendingPurchase
        ) { character in
            Button("קְנֵה וְהַחֲלֵף") { buy(character) }
            Button("בִּטּוּל", role: .cancel) {}
        }
        .alert("חֲסֵרִים יַהֲלוֹמִים 💎",
               isPresented: Binding(get: { shortBy != nil },
                                    set: { if !$0 { shortBy = nil } })) {
            Button("קְנֵה יַהֲלוֹמִים") { showStarShop = true }
            Button("הֲבַנְתִּי", role: .cancel) {}
        } message: {
            if let s = shortBy { Text("צָרִיךְ עוֹד \(s) יַהֲלוֹמִים. תַּמְשִׁיךְ לִלְמוֹד וְתַרְוִיחַ — אוֹ הוֹרֶה יָכוֹל לִקְנוֹת.") }
        }
    }

    private func tierColor(_ tier: CharacterTier) -> Color {
        let c = tier.rgb
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    private func card(_ character: Character3D) -> some View {
        let selected = selectedID == character.id
        let owned = characters.owns(character)
        let affordable = progress.diamonds >= character.priceDiamonds
        let tColor = tierColor(character.tier)
        return Button {
            tap(character)
        } label: {
            CharacterView(character: character)
                .frame(height: 190)
                .opacity(owned ? 1 : 0.6)
                .saturation(owned ? 1 : 0.65)
                .allowsHitTesting(false)
                .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            // Glass tile with the tier colour glowing through; the equipped one
            // wears gold (same vocabulary as the home's world tiles).
            .glassPane(radius: 22, tint: selected ? Color(hex: "FFD23F") : tColor)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AppColor.starGold.opacity(0.9), lineWidth: 2)
                }
            }
            .overlay(alignment: .topLeading) { tierBadge(character.tier, color: tColor) }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(AppColor.starGold)
                        .background(Circle().fill(.white))
                        .padding(8)
                }
            }
            .overlay(alignment: .bottom) {
                if !owned { priceBadge(character.priceDiamonds, affordable: affordable) }
            }
        }
        .buttonStyle(.plain)
    }

    private func tierBadge(_ tier: CharacterTier, color: Color) -> some View {
        Text(tier.label)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.75)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 1))
            .padding(8)
    }

    private func priceBadge(_ price: Int, affordable: Bool) -> some View {
        // A price tag, never a lock (Rani: no lock language for the child).
        HStack(spacing: 4) {
            Text("\(price)").font(.system(size: 15, weight: .heavy, design: .rounded))
            Text("💎").font(.system(size: 12))
        }
        .foregroundStyle(affordable ? Color(hex: "4B3FBF") : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(affordable ? .white.opacity(0.92) : .white.opacity(0.18)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .padding(.bottom, 12)
    }

    // MARK: - Actions

    private func tap(_ character: Character3D) {
        if characters.owns(character) {
            select(character)
        } else if progress.diamonds >= character.priceDiamonds {
            Haptic.light()
            pendingPurchase = character
        } else {
            Haptic.light()
            shortBy = character.priceDiamonds - progress.diamonds
        }
    }

    private func buy(_ character: Character3D) {
        guard (try? characters.purchase(character)) != nil else { return }
        Haptic.success()
        select(character)
    }

    private func select(_ character: Character3D) {
        Haptic.light()
        if var p = profiles.profiles.first(where: { $0.id == profileID }) {
            p.character3DID = character.id
            p.characterUpdatedAt = .now   // freshness stamp — merges keep the newer pick
            profiles.update(p)   // syncs to co-parents
        }
        onPicked?()
    }
}
