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
    /// "המכשיר של הילד" on a device that has no family at all — the old dead
    /// end (Rani, 2026-10-05): the child's phone went straight to a QR screen
    /// while no code existed anywhere in the world, and the only way out was
    /// deleting the app. Now it asks first, with three ways forward.
    @State private var childNeedsCode = false
    @ObservedObject private var profiles = ProfileStore.shared

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
                        // The line a first-time parent actually needs, instead
                        // of "you can change this later in settings".
                        Text(isPad ? tr("אֶת הַמִּשְׁפָּחָה מְנַהֲלִים בְּדֶרֶךְ כְּלָל מֵהָאַיְפוֹן שֶׁלָּכֶם")
                                   : tr("פַּעַם רִאשׁוֹנָה בַּמִּשְׁפָּחָה? מַתְחִילִים כָּאן — בַּמַּכְשִׁיר שֶׁלָּכֶם"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, AppSpacing.lg)

                    // 📱 On a phone the PARENT goes first and wears the gold
                    // badge — whatever sits on top reads as the default, and a
                    // family that starts on the kid's phone has nothing to scan.
                    // 🖥️ On an iPad it stays the other way round (see `isPad`).
                    VStack(spacing: AppSpacing.lg) {
                        if isPad { childCard; parentCard } else { parentCard; childCard }
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
            if childNeedsCode { childCodeSheet }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    private var childCard: some View {
        roleCard(
            emoji: "🧒",
            title: tr("הַמַּכְשִׁיר שֶׁל הַיֶּלֶד"),
            // Says what this device needs, instead of the old line that told
            // you to start somewhere else from the card asking to be tapped.
            subtitle: tr("לְשַׂחֵק וְלִלְמוֹד · צָרִיךְ קוֹד חִבּוּר מֵהַמַּכְשִׁיר שֶׁל הַהוֹרֶה"),
            glow: AppColor.companionGlow,
            badge: isPad ? tr("מֻמְלָץ לְאַיְפֵּד") : nil
        ) {
            if hasNoFamilyHere {
                Haptic.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { childNeedsCode = true }
            } else {
                choose(.child)
            }
        }
    }

    private var parentCard: some View {
        roleCard(
            emoji: "👨‍👩‍👧",
            title: tr("הַמַּכְשִׁיר שֶׁלִּי (הוֹרֶה)"),
            subtitle: tr("מַעֲקָב, דּוּחוֹת וְנִיהוּל"),
            glow: AppColor.starGold,
            badge: isPad ? nil : tr("מַתְחִילִים כָּאן")
        ) {
            if isPad {
                Haptic.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { confirmParentOnPad = true }
            } else {
                choose(.parent)
            }
        }
    }

    /// Nothing on this device points at a family: no bound child, no profile.
    /// (A device that WAS bound is restored by `healLostChildRoleIfNeeded`
    /// before this screen is ever shown, so it never sees the sheet.)
    private var hasNoFamilyHere: Bool {
        // DEMO_SCREEN=rolepicker shows the sheet; DEMO_HASFAMILY=1 hides it,
        // so both sides are reachable on a simulator that already has a child.
        if AppInfo.isDemoRun { return ProcessInfo.processInfo.environment["DEMO_HASFAMILY"] != "1" }
        return settings.joinedChildID == nil && profiles.profiles.isEmpty
    }

    /// 🔗 The dead end, replaced by three ways forward. Nothing is blocked:
    /// a child who HAS a code pays one extra tap and reaches the very same
    /// scan screen.
    private var childCodeSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismissChildSheet() }
            VStack(spacing: 9) {
                HStack {
                    Spacer()
                    Button { dismissChildSheet() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                Text("🔗").font(.system(size: 42))
                Text(tr("צָרִיךְ קוֹד חִבּוּר מֵהַהוֹרֶה"))
                    .font(.system(size: 23, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(tr("הַמַּכְשִׁיר שֶׁל הַיֶּלֶד מִתְחַבֵּר לְקוֹד שֶׁנּוֹצָר בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה. יֵשׁ לָכֶם כְּבָר קוֹד?"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    childNeedsCode = false
                    choose(.child)
                } label: {
                    Text(tr("יֵשׁ לִי קוֹד — לְהַמְשִׁיךְ"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .glassFill(AppGradient.gold, radius: 16)
                }
                .buttonStyle(.juicy)
                .padding(.top, 4)
                Button {
                    childNeedsCode = false
                    choose(.parent)
                } label: {
                    Text(tr("עוֹד לֹא — נַתְחִיל כָּאן כְּהוֹרֶה"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.juicy)
                ShareLink(item: URL(string: "https://apps.apple.com/app/id6773805449")!) {
                    Text(tr("לִשְׁלֹחַ קִשּׁוּר לַהוֹרֶה"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .underline()
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: 440)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: "4A3AB0").opacity(0.97))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 20, y: -10)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func dismissChildSheet() {
        withAnimation(.easeOut(duration: 0.2)) { childNeedsCode = false }
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
