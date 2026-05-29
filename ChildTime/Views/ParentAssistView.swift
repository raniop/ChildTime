import SwiftUI

/// Shown mid-session when a child is clearly stuck (2 wrong picks). Offers a
/// warm, no-pressure choice: ask a linked parent for help (sends them a push via
/// the events → Cloud Function pipeline) or keep going solo. Never shaming.
struct ParentAssistView: View {
    let onContinue: () -> Void
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sent = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("🤔").font(.system(size: 72))
            Text("רוֹצֶה עֶזְרָה בַּשְּׁאֵלָה הַזּוֹ?")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if sent {
                Text("שָׁלַחְנוּ בַּקָּשַׁת עֶזְרָה 💌")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.successMint)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(parentOptions, id: \.self) { parent in
                        assistButton("👨‍👩‍👧 בַּקֵּשׁ עֶזְרָה מ\(parent)") { askParent() }
                    }
                    if parentOptions.isEmpty {
                        assistButton("💌 בַּקֵּשׁ עֶזְרָה מֵהוֹרֶה") { askParent() }
                    }
                }
            }

            Button {
                onContinue(); dismiss()
            } label: {
                Text("🚀 אַמְשִׁיךְ לְבַד")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.juicy)
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 460)
        .background(AppGradient.dreamy.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private var parentOptions: [String] {
        Array(household.linkedParentSummaries.prefix(2))
    }

    private func assistButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppGradient.gold, in: Capsule())
                .glow(AppColor.starGold, radius: 8)
        }
        .buttonStyle(.juicy)
    }

    private func askParent() {
        Haptic.light()
        LiveEventReporter.report(.assistRequest)
        withAnimation { sent = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            onContinue(); dismiss()
        }
    }
}
