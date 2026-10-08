import SwiftUI

/// The character shop. Kids browse the collectible characters, buy locked ones
/// with earned stars (or buy more stars with real money, parent-gated), and
/// equip them. The hero shows the currently-equipped character big.
struct ShopView: View {
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc

    @State private var showingProfileEditor = false
    @State private var showStarShop = false
    /// The wider of the two top-bar sides (✕ / 💎 balance). The centred title
    /// keeps clear of BOTH by this much, so it stays centred and never runs
    /// into the balance ("Магазин персонажей" did, on an iPhone — QA round 3).
    @State private var topBarSide: CGFloat = 44
    @ObservedObject private var display = DisplayGeometry.shared

    private var isCompact: Bool { hsc == .compact }
    private var avatarSize: CGFloat { isCompact ? 140 : 180 }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        hero
                        if let active = profiles.active {
                            CharacterCollectionView(profileID: active.id,
                                                    showStarShop: $showStarShop)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxxl)
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $showStarShop) {
            // Kids Category (guideline 1.3): real-money packs MUST sit behind a
            // parental gate. Apple ID / Face ID payment auth is NOT a substitute —
            // that reasoning is exactly what got the app rejected. respectSession:
            // false so an earlier unlock this session can't open the store.
            ParentGateView(allowClose: true,
                           gateTitle: tr("אֵזוֹר הוֹרִים"),
                           gateReason: tr("כְּדֵי לִקְנוֹת יַהֲלוֹמִים — בַּקְּשׁוּ מֵהוֹרֶה לְהַזִּין אֶת הַקּוֹד"),
                           useFaceID: true,
                           respectSession: false) {
                StarShopView()
                    .environment(\.layoutDirection, .app)
            }
            .environmentObject(ParentSettings.shared)
            .environment(\.layoutDirection, .app)
        }
        .sheet(isPresented: $showingProfileEditor) {
            if let active = profiles.active {
                ProfileEditorView(mode: .edit(active)) { updated in
                    profiles.update(updated)
                } onDelete: { profile in
                    profiles.remove(profile)
                }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .app)
            }
        }
    }

    // MARK: - Sibling time entry

    // MARK: - Top bar

    private var topBar: some View {
        Group {
            if display.hasBarStrip {
                // 🖼 The foldable: the title with the 💎 balance under it,
                // centred in the band beside the clock, and the ✕ in the corner
                // away from it. Side by side they did not fit beside the clock.
                VStack(spacing: 8) {
                    title
                    balanceChip
                }
                .frame(maxWidth: .infinity)
                .clearOfBarBothSides()
                .overlay(alignment: .top) {
                    HStack { closeButton; Spacer() }.awayFromBar()
                }
                .fillsTopBand(above: DisplayProbeView.minimumTopMargin + AppSpacing.sm)
            } else {
                ZStack {
                    title
                        .padding(.horizontal, topBarSide + AppSpacing.sm)
                        .frame(maxWidth: .infinity)
                    HStack {
                        closeButton
                        Spacer()
                        balanceChip
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { topBarSide = max(40, $0) }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private var title: some View {
        Text(tr("חֲנוּת הַדְּמוּיוֹת"))
            .font(.system(size: isCompact ? 22 : 28, weight: .black, design: .rounded))
            .foregroundStyle(GlassInk.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .shadow(color: .black.opacity(0.18), radius: 7, y: 2)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.22), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
        }
        .environment(\.layoutDirection, .appMirrored)
    }

    /// Tappable balance → buy more diamonds (parent-gated).
    private var balanceChip: some View {
        Button {
            Haptic.light()
            showStarShop = true
        } label: {
            HStack(spacing: 4) {
                Text("💎").font(.system(size: 16))
                Text(progress.diamonds.currencyShort)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .numericTextTransition(Double(progress.diamonds))
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.30), lineWidth: 1))
            .fixedSize()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero (currently-equipped character)

    @ViewBuilder
    private var hero: some View {
        if let profile = profiles.active {
            VStack(spacing: 6) {
                CharacterView(character: profile.character, animated: true, interactive: true)
                    .id(profile.character.id)
                    .frame(width: avatarSize, height: avatarSize * 1.45)
                Text(profile.name)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                pillButton(icon: "pencil", title: Gendered.g(tr("עֲרוֹךְ פְּרוֹפִיל"), tr("עִרְכִי פְּרוֹפִיל"))) {
                    showingProfileEditor = true
                }
                .padding(.top, 4)
            }
            .padding(.top, AppSpacing.sm)
        } else {
            Text(tr("צוֹר פְּרוֹפִיל כְּדֵי לְהַתְחִיל"))
                .foregroundStyle(.white)
        }
    }

    private func pillButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShopView()
        .environmentObject(ProfileStore.shared)
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .app)
}
