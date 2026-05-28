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
            Text(profiles.isEmpty ? "ברוכים הבאים!" : "מי משחק?")
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
                 ? "צרו פרופיל ראשון כדי להתחיל"
                 : "בחר את הפרופיל שלך")
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

            Text("הוספה")
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

    var body: some View {
        ZStack {
            // Background — photo trumps preset.
            if let data = profile.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                let preset = AvatarPreset.find(profile.avatarPresetID)
                Circle()
                    .fill(LinearGradient(
                        colors: [preset.topColor, preset.bottomColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: size, height: size)
                Text(preset.emoji)
                    .font(.system(size: size * 0.55))
            }
        }
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
}

#Preview {
    ProfilePickerView()
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
