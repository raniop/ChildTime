import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var shields: ShieldManager
    @Environment(\.horizontalSizeClass) private var hsc

    @State private var step: Step = .welcome
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var pinError: String?
    @State private var minutesPerAnswer: Int = 2

    // Welcome animation state
    @State private var welcomeCompanion = CompanionController()
    @State private var welcomeTitleAppeared = false
    @State private var welcomeSubtitleAppeared = false
    @State private var welcomeBubbleVisible = false
    @State private var welcomeButtonAppeared = false
    @State private var welcomeConfettiTrigger = 0
    @State private var welcomeBurstTrigger = 0

    private var isCompact: Bool { hsc == .compact }
    private var welcomeCompanionSize: CGFloat { isCompact ? 140 : 180 }
    private var titleSize: CGFloat { isCompact ? 38 : 56 }
    private var subtitleSize: CGFloat { isCompact ? 18 : 24 }
    private var iconSize: CGFloat { isCompact ? 38 : 50 }
    private var bigCounterSize: CGFloat { isCompact ? 72 : 100 }
    private var welcomeTitleSize: CGFloat { isCompact ? 64 : 96 }

    enum Step {
        case welcome
        case parentInfo
        case familyControls
        case pinSetup
        case hatching
    }

    // NOTE: Two former steps no longer exist:
    //  - `kidIntro` — replaced by the Netflix-style ProfilePicker, which
    //    captures name / gender / age / avatar / photo per kid.
    //  - `accountSync` — replaced by LoginGateView, the very first screen.
    //    By the time the parent reaches onboarding they're already signed
    //    in, so a second account prompt would be confusing.

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            SparkleField(count: 20, size: 14)

            switch step {
            case .welcome: welcomeView
            case .parentInfo: parentInfoView
            case .familyControls: familyControlsView
            case .pinSetup: pinView
            case .hatching: HatchingView { complete() }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { _, new in
            settings.activitySelectionData = SelectionStorage.encode(new)
            shields.applyShield(from: new)
        }
        .onAppear {
            selection = SelectionStorage.decode(settings.activitySelectionData)
            minutesPerAnswer = settings.minutesPerCorrectAnswer
            Task { await shields.requestAuthorizationIfNeeded() }
        }
    }

    private var background: LinearGradient {
        AppGradient.dreamy
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        ZStack {
            // Extra magical background layers
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.companionGlow, AppColor.gemPurple, AppColor.dreamyTeal],
                count: 7,
                maxSize: 300,
                opacity: 0.5
            )
            SparkleField(count: 40, size: 16)
            Confetti(trigger: welcomeConfettiTrigger)
            StarBurst(count: 14, color: AppColor.starGold, trigger: welcomeBurstTrigger)

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Companion hero with bubble
                ZStack(alignment: .topLeading) {
                    if welcomeBubbleVisible {
                        BubbleSpeech(text: "היי! אני טופי 💫")
                            .offset(x: welcomeCompanionSize * 0.55, y: -30)
                            .transition(.scale.combined(with: .opacity))
                    }
                    CompanionView(controller: welcomeCompanion, size: welcomeCompanionSize)
                        .scaleEffect(welcomeTitleAppeared ? 1 : 0.3)
                        .opacity(welcomeTitleAppeared ? 1 : 0)
                }
                .frame(height: welcomeCompanionSize * 1.8)

                // Animated title — "טופי" big & gradient, "וחברים" smaller below
                // (classic logo + subtitle treatment for the full app name).
                VStack(spacing: 0) {
                    Text("טופי")
                        .font(.system(size: welcomeTitleSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: AppColor.starGold.opacity(0.7), radius: 18)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 4)

                    Text("וחברים")
                        .font(.system(size: welcomeTitleSize * 0.42, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: AppColor.starGold.opacity(0.35), radius: 8)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        .offset(y: -welcomeTitleSize * 0.10) // tuck slightly into "טופי"
                }
                .scaleEffect(welcomeTitleAppeared ? 1 : 0.4)
                .rotationEffect(.degrees(welcomeTitleAppeared ? 0 : -8))
                .opacity(welcomeTitleAppeared ? 1 : 0)

                Text("שעת משחק\nשמתחילה בשאלה")
                    .font(.system(size: subtitleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .opacity(welcomeSubtitleAppeared ? 1 : 0)
                    .offset(y: welcomeSubtitleAppeared ? 0 : 20)

                Spacer()

                JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                    welcomeCompanion.cheer("קָדִימָה!")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        step = .parentInfo
                    }
                } label: {
                    HStack {
                        Text("בוא נתחיל!")
                        Image(systemName: "play.fill")
                    }
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
                .pulse(min: 0.92)
                .scaleEffect(welcomeButtonAppeared ? 1 : 0.6)
                .opacity(welcomeButtonAppeared ? 1 : 0)
            }
        }
        .onAppear { runWelcomeSequence() }
    }

    private func runWelcomeSequence() {
        // Title + companion appear with a bounce
        withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.2)) {
            welcomeTitleAppeared = true
        }
        // Burst of stars right when companion appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            welcomeBurstTrigger += 1
            welcomeConfettiTrigger += 1
            welcomeCompanion.cheer()
        }
        // Subtitle fades up
        withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
            welcomeSubtitleAppeared = true
        }
        // Bubble pops in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                welcomeBubbleVisible = true
            }
        }
        // CTA appears last
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.9)) {
            welcomeButtonAppeared = true
        }
    }

    // MARK: - Parent info

    private var parentInfoView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer().frame(height: 60)

            infoIcon(systemName: "person.2.fill")

            Text("שלום, הורה 👋")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("לפני שניתן את האפליקציה לילד,\nצריך להגדיר כמה דברים:")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            // Premium setup card with icon-circles
            VStack(spacing: 6) {
                setupRow(
                    icon: "📱",
                    tint: Color(hex: "5B9BFF"),
                    title: "אפליקציות לחסום",
                    subtitle: "YouTube, TikTok, משחקים…"
                )
                rowDivider
                setupRow(
                    icon: "⏱",
                    tint: AppColor.successMint,
                    title: "דקות לכל תשובה נכונה",
                    subtitle: "כמה זמן משחק הילד מרוויח"
                )
                rowDivider
                setupRow(
                    icon: "🔒",
                    tint: AppColor.gemPurple,
                    title: "קוד הורה",
                    subtitle: "4 ספרות שרק אתה תדע"
                )
            }
            .padding(.vertical, AppSpacing.sm)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 18, y: 6)
            .frame(maxWidth: 560)
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                step = .familyControls
            } label: {
                Text("המשך")
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, AppSpacing.lg)
    }

    private func setupRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Circle icon badge
            ZStack {
                Circle()
                    .fill(tint.opacity(0.22))
                    .overlay(Circle().stroke(tint.opacity(0.55), lineWidth: 1.5))
                Text(icon)
                    .font(.system(size: 26))
            }
            .frame(width: 52, height: 52)
            .glow(tint, radius: 8)

            // In RTL, .leading = right edge — so the title text sits next to the icon
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Family Controls

    private var familyControlsView: some View {
        mainContent
            .overlay(alignment: .topTrailing) {
                backArrowButton { step = .parentInfo }
                    .padding(AppSpacing.lg)
            }
    }

    private var mainContent: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            infoIcon(systemName: "app.badge.fill")

            Text("אילו אפליקציות לחסום?")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("בחר אילו אפליקציות יהיו נעולות עד שהילד יענה על שאלות\n(YouTube, TikTok, משחקים…)")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            // Friendly status pill
            if !shields.isAuthorized {
                statusPill(
                    icon: "exclamationmark.shield.fill",
                    text: "צריך אישור Family Controls",
                    color: AppColor.almostWarm
                )
            } else if !selectionHasItems {
                statusPill(
                    icon: "info.circle.fill",
                    text: "עדיין לא נבחרו אפליקציות",
                    color: AppColor.companionGlow
                )
            } else {
                statusPill(
                    icon: "checkmark.circle.fill",
                    text: "\(selectionCount) אפליקציות נבחרו",
                    color: AppColor.successMint
                )
            }

            // Primary action — either approve, or pick apps
            if !shields.isAuthorized {
                JuicyButton(gradient: AppGradient.castle, glowColor: AppColor.flameOrange) {
                    Task { await shields.requestAuthorizationIfNeeded() }
                } label: {
                    Label("אשר Family Controls", systemImage: "checkmark.shield.fill")
                }

                if let err = shields.authorizationError {
                    errorBubble(message: err)
                }
                Button {
                    openSettings()
                } label: {
                    Label("פתח Settings", systemImage: "arrow.up.right.square")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.18), in: Capsule())
                }
            } else {
                JuicyButton(gradient: AppGradient.castle, glowColor: AppColor.flameOrange) {
                    showPicker = true
                } label: {
                    Label(
                        selectionHasItems ? "ערוך בחירה" : "בחר אפליקציות",
                        systemImage: "app.badge.fill"
                    )
                }
            }

            Spacer()

            JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                step = .pinSetup
            } label: {
                Text("המשך")
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A top-left back arrow button — explicitly placed at top-trailing in RTL
    /// (which is the visual left side of the screen).
    private func backArrowButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.18), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.juicy)
        .environment(\.layoutDirection, .leftToRight)  // keep arrow pointing left regardless
    }

    private var selectionCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    private var selectionHasItems: Bool { selectionCount > 0 }

    private func statusPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 10)
        .background(.white.opacity(0.15), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1.5))
    }

    private func errorBubble(message: String) -> some View {
        VStack(spacing: 6) {
            Text("⚠️ שגיאה")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: 420)
        .background(Color.red.opacity(0.25), in: RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    // MARK: - PIN setup

    private var pinView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer().frame(height: 60)
            infoIcon(systemName: "lock.fill")
            Text("צור קוד הורה")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("רק אתה תדע אותו — הילד לא יוכל לפתוח הגדרות בלעדיו")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            VStack(spacing: AppSpacing.sm) {
                pinField(text: $newPIN, placeholder: "קוד חדש (4 ספרות)")
                pinField(text: $confirmPIN, placeholder: "אמת קוד")
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, AppSpacing.lg)
            // Strip non-digits and cap at 4 chars — important on iPad where
            // .numberPad falls back to the full keyboard.
            .onChange(of: newPIN) { _, new in
                let filtered = String(new.filter(\.isNumber).prefix(4))
                if filtered != new { newPIN = filtered }
                if pinError != nil { pinError = nil }
            }
            .onChange(of: confirmPIN) { _, new in
                let filtered = String(new.filter(\.isNumber).prefix(4))
                if filtered != new { confirmPIN = filtered }
                if pinError != nil { pinError = nil }
            }

            if let err = pinError {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.system(size: 16, weight: .semibold))
            }

            Spacer()

            JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                savePIN()
            } label: {
                Text("שמור")
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            backArrowButton { step = .familyControls }
                .padding(AppSpacing.lg)
        }
    }

    // MARK: - Minutes

    // MARK: - Helpers

    private func infoIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize))
            .foregroundStyle(.white)
            .padding(AppSpacing.md)
            .background(.white.opacity(0.18), in: Circle())
    }

    private func bulletItem(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(emoji).font(.system(size: 28))
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private func pinField(text: Binding<String>, placeholder: String) -> some View {
        SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.5)))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding()
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptic.light()
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.juicy)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func savePIN() {
        // Defensive: re-filter at submit time even though onChange already does it.
        let n = String(newPIN.filter(\.isNumber).prefix(4))
        let c = String(confirmPIN.filter(\.isNumber).prefix(4))
        guard n.count == 4 else {
            pinError = n.isEmpty
                ? "הקלד קוד בן 4 ספרות"
                : "חסרות ספרות — צריך בדיוק 4"
            return
        }
        guard c.count == 4 else {
            pinError = "צריך להקליד גם בשורת האימות"
            return
        }
        guard n == c else {
            pinError = "שני הקודים לא תואמים"
            return
        }
        pinError = nil
        settings.pin = n
        step = .hatching
    }

    private func complete() {
        settings.onboardingCompleted = true
        if settings.enabledTopics.isEmpty {
            settings.enabledTopics = [.math, .english, .logic, .science]
        }
        // Unlock all worlds by default (all open from start)
        for world in Worlds.all {
            progress.unlockWorld(world.id)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ShieldManager.shared)
        .environmentObject(AuthManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
