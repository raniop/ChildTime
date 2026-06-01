import SwiftUI

/// Pick / change / buy the profile's character. A thin wrapper around the shared
/// `CharacterCollectionView`, with a header + auto-dismiss after picking.
struct Character3DPickerView: View {
    let profileID: UUID
    @ObservedObject private var progress = ProgressStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showStarShop = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: 0) {
                header
                ScrollView {
                    CharacterCollectionView(profileID: profileID,
                                            showStarShop: $showStarShop,
                                            onPicked: {
                        // Brief beat so the gold check registers, then close.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { dismiss() }
                    })
                    .padding(AppSpacing.lg)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showStarShop) {
            // No parent gate: the purchase itself is protected by Apple ID /
            // Face ID payment auth.
            StarShopView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var header: some View {
        ZStack {
            Text("בְּחַר דְּמוּת")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppColor.starGold.opacity(0.7), radius: 8)
            HStack {
                starsChip
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.18), in: Circle())
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var starsChip: some View {
        Button { showStarShop = true } label: {
            HStack(spacing: 4) {
                Text("⭐").font(.system(size: 15))
                Text("\(progress.stars)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.starGold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }
}
