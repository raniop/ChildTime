import SwiftUI

/// Netflix-style profile picker. Shows on launch (when there's no active
/// profile) and from a "switch profile" button.
struct ProfilePickerView: View {
    @EnvironmentObject var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var showCreate = false
    @State private var editingProfile: Profile?
    @State private var headerAppear = false

    private var isCompact: Bool { hsc == .compact }
    private var tileSize: CGFloat { isCompact ? 110 : 150 }
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(tileSize + 30), spacing: AppSpacing.lg),
            count: profiles.profiles.count >= 3 ? (isCompact ? 2 : 4) : 2
        )
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.companionGlow, AppColor.gemPurple],
                count: 5, maxSize: 280, opacity: 0.4
            )
            SparkleField(count: 22, size: 14)

            VStack(spacing: AppSpacing.xl) {
                Spacer().frame(height: 30)

                hero

                LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                    ForEach(profiles.profiles) { profile in
                        tile(for: profile)
                    }
                    if profiles.canAddMore {
                        addTile
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .frame(maxWidth: 720)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                headerAppear = true
            }
            // First-time families: jump straight into "create your first
            // profile" instead of making them tap the +. Smoother handoff
            // from the end of onboarding.
            if profiles.isEmpty && !showCreate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    showCreate = true
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            ProfileEditorView(mode: .create) { newProfile in
                profiles.add(newProfile)
                profiles.setActive(newProfile)
                showCreate = false
                dismiss()
            }
            .environmentObject(profiles)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .sheet(item: $editingProfile) { p in
            ProfileEditorView(mode: .edit(p)) { updated in
                profiles.update(updated)
                editingProfile = nil
            } onDelete: { toDelete in
                profiles.remove(toDelete)
                editingProfile = nil
            }
            .environmentObject(profiles)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    // MARK: - Header

    private var hero: some View {
        VStack(spacing: 6) {
            Text(profiles.isEmpty ? "בְּרוּכִים הַבָּאִים!" : "מִי מְשַׂחֵק?")
                .font(.system(size: isCompact ? 36 : 52, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: AppColor.starGold.opacity(0.6), radius: 14)
                .scaleEffect(headerAppear ? 1 : 0.6)
                .opacity(headerAppear ? 1 : 0)

            Text(profiles.isEmpty
                 ? "צְרוּ פְּרוֹפִיל רִאשׁוֹן כְּדֵי לְהַתְחִיל"
                 : "בְּחַר אֶת הַפְּרוֹפִיל שֶׁלְּךָ")
                .font(.system(size: isCompact ? 17 : 21, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.25), radius: 3)
                .opacity(headerAppear ? 1 : 0)
                .offset(y: headerAppear ? 0 : 12)
        }
    }

    // MARK: - Tile

    private func tile(for profile: Profile) -> some View {
        VStack(spacing: 10) {
            ProfileAvatarView(profile: profile, size: tileSize)
                .overlay(alignment: .topLeading) {
                    Button {
                        Haptic.light()
                        editingProfile = profile
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .offset(x: -4, y: -4)
                }

            Text(profile.name)
                .font(.system(size: isCompact ? 18 : 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: tileSize + 30)
        }
        .onTapGesture {
            Haptic.medium()
            SoundPlayer.shared.play(.uiTap)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                profiles.setActive(profile)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }

    private var addTile: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    )
                Image(systemName: "plus")
                    .font(.system(size: tileSize * 0.35, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: tileSize, height: tileSize)

            Text("הוֹסָפָה")
                .font(.system(size: isCompact ? 17 : 21, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .onTapGesture {
            Haptic.light()
            showCreate = true
        }
    }
}

// MARK: - Avatar view

struct ProfileAvatarView: View {
    let profile: Profile
    var size: CGFloat = 110
    /// Set to a non-empty array to render a *preview* loadout (e.g. in the
    /// shop) without touching the profile's persisted equipment.
    var overrideItems: [CosmeticItem]? = nil
    /// On small avatars (e.g. the home top bar) render only head/face items
    /// (hat, glasses, accessory) so the loadout reads cleanly at tiny sizes.
    var headItemsOnly: Bool = false

    @EnvironmentObject private var cosmetics: CosmeticStore

    private var equippedItems: [CosmeticItem] {
        let base = overrideItems ?? cosmetics.equippedItems(for: profile.id)
        let filtered = headItemsOnly
            ? base.filter { [.hat, .glasses, .accessory].contains($0.category) }
            : base
        // Draw back-to-front: body first, glasses over the face, hat on top.
        return filtered.sorted { zIndex($0.category) < zIndex($1.category) }
    }

    /// Paint order — higher draws later (on top).
    private func zIndex(_ c: CosmeticCategory) -> Int {
        switch c {
        case .vehicle:   return 0
        case .backpack:  return 1
        case .shoes:     return 2
        case .pants:     return 3
        case .shirt:     return 4
        case .accessory: return 5
        case .glasses:   return 6
        case .hat:       return 7
        }
    }

    var body: some View {
        // The child's chosen 3D character as a head-and-shoulders portrait —
        // there's no profile photo anymore, only the picked character.
        Character3DView(modelName: profile.character.scn,
                        animated: false, interactive: false, portrait: true)
            .id(profile.character.id)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    LinearGradient(
                        colors: [AppColor.starGold, AppColor.companionGlow],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }

    /// Layered cosmetic — each category sits in a tuned spot around the
    /// avatar circle so a hat goes on top, glasses cover the face, shoes
    /// peek at the bottom, etc.
    @ViewBuilder
    private func cosmeticLayer(for item: CosmeticItem) -> some View {
        let (offset, scale) = position(for: item.category)
        Group {
            switch item.render {
            case .image(let name):
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * scale, height: size * scale)
            case .symbol(let sym):
                // Worn glasses read best as a dark, bold line symbol on the eyes.
                Image(systemName: sym)
                    .font(.system(size: size * scale * 0.72, weight: .semibold))
                    .foregroundStyle(symbolColor(for: item.category))
                    .frame(width: size * scale, height: size * scale)
            case .emoji(let e):
                Text(e)
                    .font(.system(size: size * scale))
            }
        }
        .offset(x: offset.x * size, y: offset.y * size)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }

    private func symbolColor(for category: CosmeticCategory) -> Color {
        switch category {
        case .glasses: return Color.black.opacity(0.82)   // looks like real lenses
        default:       return .primary
        }
    }

    /// Offset (x, y) is in units of `size` (i.e. 0.45 = 45% of avatar diameter).
    /// Tuned so the hat sits ON the head crown and glasses sit ON the eyes —
    /// they read as worn rather than floating.
    private func position(for category: CosmeticCategory) -> (offset: CGPoint, scale: CGFloat) {
        switch category {
        case .hat:       return (CGPoint(x: 0,     y: -0.40), 0.54)  // on the crown, overlapping
        case .glasses:   return (CGPoint(x: 0,     y: -0.05), 0.52)  // across the eyes
        case .shirt:     return (CGPoint(x: 0,     y:  0.34), 0.32)
        case .pants:     return (CGPoint(x: 0,     y:  0.46), 0.24)
        case .shoes:     return (CGPoint(x: 0,     y:  0.52), 0.22)
        case .accessory: return (CGPoint(x:  0.34, y: -0.30), 0.26)
        case .backpack:  return (CGPoint(x: -0.36, y:  0.08), 0.28)
        case .vehicle:   return (CGPoint(x:  0.36, y:  0.38), 0.30)
        }
    }
}

#Preview {
    ProfilePickerView()
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
