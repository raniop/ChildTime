import SwiftUI

/// Shown once, right after sign-in: who is this device for? The answer steers
/// the whole experience — a child's device boots into play, a parent's device
/// boots into the family monitoring view.
struct RolePickerView: View {
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.horizontalSizeClass) private var hsc
    @StateObject private var companion = CompanionController()
    @State private var appeared = false

    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    VStack(spacing: AppSpacing.sm) {
                        CompanionView(controller: companion, size: isCompact ? 124 : 150)
                            .scaleEffect(appeared ? 1 : 0.4)
                        Text("מִי מִשְׁתַּמֵּשׁ בַּמַּכְשִׁיר הַזֶּה?")
                            .font(.system(size: isCompact ? 26 : 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("אֶפְשָׁר לְשַׁנּוֹת מְאוּחָר יוֹתֵר בְּהַגְדָּרוֹת.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.top, AppSpacing.lg)

                    VStack(spacing: AppSpacing.lg) {
                        roleCard(
                            emoji: "🧒",
                            title: "הַמַּכְשִׁיר שֶׁל הַיֶּלֶד",
                            // First-install guidance (Rani): families who start
                            // on the KID's device hit a scan screen with no code
                            // to scan — say up front that the parent goes first.
                            subtitle: "לְשַׂחֵק וְלִלְמוֹד · מַתְחִילִים קֹדֶם בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה",
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
                Text(emoji)
                    .font(.system(size: 38))
                    .frame(width: 64, height: 64)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [glow.opacity(0.55), glow.opacity(0.18)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity)
            .glassPane(radius: AppRadius.large)
        }
        .buttonStyle(.juicy)
    }

    private func choose(_ role: ParentSettings.DeviceRole) {
        Haptic.medium()
        settings.deviceRole = role
        AppAnalytics.roleChosen(role == .parent ? "parent" : "child")
        // NO permission prompts here (E2E test with Rani, 2026-08-30): asking
        // for notifications at role-pick landed the iOS dialog ON the login
        // screen — before the app showed any value, the moment users tap
        // "Don't Allow". The parent dashboard asks when the parent is already
        // inside; a child device asks in its own flow.
    }
}

#Preview {
    RolePickerView()
        .environmentObject(ParentSettings.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
