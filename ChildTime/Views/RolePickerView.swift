import SwiftUI

/// Shown once, right after sign-in: who is this device for? The answer steers
/// the whole experience — a child's device boots into play, a parent's device
/// boots into the family monitoring view.
struct RolePickerView: View {
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.horizontalSizeClass) private var hsc
    @StateObject private var companion = CompanionController()
    @State private var appeared = false
    /// iPad only: "רגע, האייפד הזה של מי?" before it becomes a parent device.
    @State private var confirmParentOnPad = false

    private var isCompact: Bool { hsc == .compact }
    /// 📱 The DEVICE, not the size class — an iPad in Split View is still the
    /// family iPad. In production 3 of 16 families made the shared iPad their
    /// ONLY parent device (the parent installs there first and picks "parent"),
    /// while the kid is the one actually using it. Steer iPads to "child".
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    VStack(spacing: AppSpacing.sm) {
                        CompanionView(controller: companion, size: isCompact ? 124 : 150)
                            .scaleEffect(appeared ? 1 : 0.4)
                        Text(isPad ? tr("מִי מִשְׁתַּמֵּשׁ בָּאַיְפֵּד הַזֶּה?") : tr("מִי מִשְׁתַּמֵּשׁ בַּמַּכְשִׁיר הַזֶּה?"))
                            .font(.system(size: isCompact ? 26 : 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text(isPad ? tr("אֶת הַמִּשְׁפָּחָה מְנַהֲלִים בְּדֶרֶךְ כְּלָל מֵהָאַיְפוֹן שֶׁלָּכֶם")
                                   : tr("אֶפְשָׁר לְשַׁנּוֹת מְאוּחָר יוֹתֵר בְּהַגְדָּרוֹת."))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppSpacing.lg)

                    VStack(spacing: AppSpacing.lg) {
                        roleCard(
                            emoji: "🧒",
                            title: tr("הַמַּכְשִׁיר שֶׁל הַיֶּלֶד"),
                            // First-install guidance (Rani): families who start
                            // on the KID's device hit a scan screen with no code
                            // to scan — say up front that the parent goes first.
                            subtitle: tr("לְשַׂחֵק וְלִלְמוֹד · מַתְחִילִים קֹדֶם בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה"),
                            glow: AppColor.companionGlow,
                            badge: isPad ? tr("מֻמְלָץ לְאַיְפֵּד") : nil
                        ) { choose(.child) }

                        roleCard(
                            emoji: "👨‍👩‍👧",
                            title: tr("הַמַּכְשִׁיר שֶׁלִּי (הוֹרֶה)"),
                            subtitle: tr("מַעֲקָב, דּוּחוֹת וְנִיהוּל"),
                            glow: AppColor.starGold
                        ) {
                            if isPad {
                                Haptic.light()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { confirmParentOnPad = true }
                            } else {
                                choose(.parent)
                            }
                        }
                    }
                    .frame(maxWidth: 460)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay {
            if confirmParentOnPad { padParentConfirm }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    /// Glass confirmation shown on an iPad before it becomes a PARENT device.
    /// The kid's choice is the primary (gold) button; "it's mine" stays possible.
    private var padParentConfirm: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismissPadConfirm() }
            VStack(spacing: AppSpacing.md) {
                Text("🤔").font(.system(size: 54))
                Text(tr("רֶגַע, הָאַיְפֵּד הַזֶּה שֶׁל מִי?"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(tr("רֹב הַמִּשְׁפָּחוֹת מְנַהֲלוֹת אֶת טוֹפִי מֵהָאַיְפוֹן שֶׁל הַהוֹרֶה, וּמְחַבְּרוֹת אֶת הָאַיְפֵּד כְּמַכְשִׁיר שֶׁל הַיֶּלֶד."))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    confirmParentOnPad = false
                    choose(.child)
                } label: {
                    Text(tr("זֶה הָאַיְפֵּד שֶׁל הַיֶּלֶד"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .glassFill(AppGradient.gold, radius: 16)
                }
                .buttonStyle(.juicy)
                .padding(.top, 4)
                Button {
                    confirmParentOnPad = false
                    choose(.parent)
                } label: {
                    Text(tr("זֶה הָאַיְפֵּד שֶׁלִּי, לְהַמְשִׁיךְ כְּהוֹרֶה"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.juicy)
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 440)
            // Solid backing: the plain glass let the role cards behind read
            // straight through the title (seen live on the iPad).
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(Color(hex: "4A3AB0").opacity(0.97))
            )
            .glassPane(radius: AppRadius.large, strength: 0.2)
            .padding(.horizontal, AppSpacing.lg)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    private func dismissPadConfirm() {
        withAnimation(.easeOut(duration: 0.2)) { confirmParentOnPad = false }
    }

    private func roleCard(emoji: String, title: String, subtitle: String,
                          glow: Color, badge: String? = nil,
                          action: @escaping () -> Void) -> some View {
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
                    if let badge {
                        Text(badge)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "2B1C04"))
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(AppGradient.gold))
                    }
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
        UserDefaults.standard.removeObject(forKey: "device.deliberateReset")
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
        .environment(\.layoutDirection, .app)
}
