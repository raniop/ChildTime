import SwiftUI

/// Pick / change the profile's 3D character. Each card is a live, spinnable
/// preview; tapping selects it (persisted per profile). New characters are added
/// to `Character3DCatalog` over time.
struct Character3DPickerView: View {
    let profileID: UUID
    @ObservedObject private var store = Character3DStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: hsc == .compact ? 150 : 200), spacing: AppSpacing.md)]
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: 0) {
                header
                ScrollView {
                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(Character3DCatalog.all) { character in
                            card(character)
                        }
                    }
                    .padding(AppSpacing.lg)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var header: some View {
        ZStack {
            Text("בְּחַר דְּמוּת")
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

    private func card(_ character: Character3D) -> some View {
        let selected = store.selectedID(for: profileID) == character.id
        return Button {
            Haptic.light()
            store.select(character.id, for: profileID)
            // Brief beat so the gold check registers, then close automatically.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { dismiss() }
        } label: {
            // No character name — the only name in the app is the child's. A
            // character is just a look to pick.
            Character3DView(modelName: character.scn, animated: false, interactive: false)
                .frame(height: 190)
                .allowsHitTesting(false)   // the whole card is the tap target
                .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(selected ? AppColor.starGold.opacity(0.28) : Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(selected ? AppColor.starGold : .white.opacity(0.25),
                            lineWidth: selected ? 3 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(AppColor.starGold)
                        .background(Circle().fill(.white))
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
