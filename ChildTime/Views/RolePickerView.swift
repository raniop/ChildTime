import SwiftUI

/// Shown once, right after sign-in: who is this device for? The answer steers
/// the whole experience — a child's device boots into play, a parent's device
/// boots into the family monitoring view.
struct RolePickerView: View {
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var appeared = false

    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.companionGlow, AppColor.gemPurple],
                count: 6, maxSize: 280, opacity: 0.4
            )
            SparkleField(count: 22, size: 14)

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    VStack(spacing: AppSpacing.sm) {
                        Text("👋")
                            .font(.system(size: isCompact ? 56 : 72))
                        Text("בְּמִי מִשְׁתַּמְּשִׁים בַּמַּכְשִׁיר הַזֶּה?")
                            .font(.system(size: isCompact ? 26 : 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("אֶפְשָׁר לְשַׁנּוֹת מְאֻחָר יוֹתֵר בְּהַגְדָּרוֹת.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.top, AppSpacing.xl)

                    VStack(spacing: AppSpacing.lg) {
                        roleCard(
                            emoji: "🧒",
                            title: "הַמַּכְשִׁיר שֶׁל הַיֶּלֶד",
                            subtitle: "לְשַׂחֵק וְלִלְמֹד",
                            glow: AppColor.companionGlow
                        ) { choose(.child) }

                        roleCard(
                            emoji: "👨‍👩‍👧",
                            title: "הַמַּכְשִׁיר שֶׁלִּי (הוֹרֶה)",
                            subtitle: "מַעֲקָב, דּוּחוֹת וְנִיהוּל",
                            glow: AppColor.starGold
                        ) { choose(.parent) }
                    }
                    .frame(maxWidth: 460)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    private func roleCard(emoji: String, title: String, subtitle: String,
                          glow: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Text(emoji).font(.system(size: 44))
                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(glow.opacity(0.6), lineWidth: 2))
            )
            .glow(glow, radius: 14)
        }
        .buttonStyle(.juicy)
    }

    private func choose(_ role: ParentSettings.DeviceRole) {
        Haptic.medium()
        settings.deviceRole = role
        // A parent's device wants live events + reports, so ask for notification
        // permission right here (the iOS "Allow Notifications" prompt).
        if role == .parent {
            Task { await PushManager.shared.requestAuthorization() }
        }
    }
}

#Preview {
    RolePickerView()
        .environmentObject(ParentSettings.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
