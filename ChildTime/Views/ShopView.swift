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
    @State private var showSiblingTime = false

    private var isCompact: Bool { hsc == .compact }
    private var avatarSize: CGFloat { isCompact ? 140 : 180 }

    var body: some View {
        ZStack {
            // Magical purple — distinct from the blue leaderboard / world map.
            AppGradient.purpleDream.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FF6B9D")],
                count: 6, maxSize: 280, opacity: 0.30
            )
            SparkleField(count: 22, size: 14)

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        hero
                        if ParentSettings.shared.siblingTransferEnabled && profiles.profiles.count > 1 {
                            siblingTimeEntry
                        }
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
        .fullScreenCover(isPresented: $showSiblingTime) {
            SiblingTimeShopView { showSiblingTime = false }
        }
        .sheet(isPresented: $showStarShop) {
            // No parent gate: the purchase itself is protected by the Apple ID /
            // Face ID payment auth, so the packs can be shown like any app.
            StarShopView()
                .environment(\.layoutDirection, .rightToLeft)
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
    }

    // MARK: - Sibling time entry

    private var siblingTimeEntry: some View {
        Button {
            Haptic.light(); showSiblingTime = true
        } label: {
            HStack(spacing: 14) {
                Text("🛒").font(.system(size: 40))
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(.white.opacity(0.18)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("זְמַן מֵאָח")
                        .font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    Text("קְנֵה דַּקּוֹת מִשְׂחָק 💎 אוֹ תֵּן בְּמַתָּנָה 🎁")
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .heavy)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "06D6A0"), Color(hex: "118AB2")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.juicy)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("חֲנוּת הַדְּמוּיוֹת")
                .font(.system(size: isCompact ? 20 : 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppColor.starGold.opacity(0.7), radius: 8)
                .frame(maxWidth: .infinity)

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

                // Tappable balance → buy more diamonds (parent-gated).
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
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppColor.gemPurple.opacity(0.4)))
                    .overlay(Capsule().stroke(AppColor.gemPurple, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
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

                pillButton(icon: "pencil", title: "עֲרוֹךְ פְּרוֹפִיל") {
                    showingProfileEditor = true
                }
                .padding(.top, 4)
            }
            .padding(.top, AppSpacing.sm)
        } else {
            Text("צוֹר פְּרוֹפִיל כְּדֵי לְהַתְחִיל")
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
            .padding(.vertical, 8)
            .background(.white.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShopView()
        .environmentObject(ProfileStore.shared)
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
