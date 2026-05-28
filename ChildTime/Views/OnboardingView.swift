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
        case minutes
        case hatching
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            SparkleField(count: 20, size: 14)

            switch step {
            case .welcome: welcomeView
            case .parentInfo: parentInfoView
            case .familyControls: familyControlsView
            case .pinSetup: pinView
            case .minutes: minutesView
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
                        BubbleSpeech(text: "היי! אני קופיקו 💫")
                            .offset(x: welcomeCompanionSize * 0.55, y: -30)
                            .transition(.scale.combined(with: .opacity))
                    }
                    CompanionView(controller: welcomeCompanion, size: welcomeCompanionSize)
                        .scaleEffect(welcomeTitleAppeared ? 1 : 0.3)
                        .opacity(welcomeTitleAppeared ? 1 : 0)
                }
                .frame(height: welcomeCompanionSize * 1.8)

                // Animated title with letter-by-letter reveal feel
                Text("קופיקו")
                    .font(.system(size: welcomeTitleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: AppColor.starGold.opacity(0.7), radius: 18)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 4)
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
                    welcomeCompanion.cheer("יאללה!")
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
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: 60)
                infoIcon(systemName: "person.2.fill")
                Text("שלום, הורה 👋")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("לפני שניתן את האפליקציה לילד, צריך להגדיר כמה דברים:")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)

                bulletItem("📱", "אילו אפליקציות לחסום בלי שאלות")
                bulletItem("⏱", "כמה דקות משחק לכל תשובה נכונה")
                bulletItem("🔒", "קוד 4-ספרות שרק אתה תדע")

                Spacer().frame(height: 20)

                JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                    step = .familyControls
                } label: {
                    Text("המשך")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    // MARK: - Family Controls

    private var familyControlsView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: 40)
                infoIcon(systemName: "app.badge.fill")
                Text("אילו אפליקציות לחסום?")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("בחר את האפליקציות והקטגוריות שיהיו נעולות עד שהילד יענה על שאלות. (YouTube, TikTok, משחקים...)")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)

                // Status badge
                HStack(spacing: 6) {
                    Image(systemName: shields.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    Text("סטטוס: \(shields.authStatusText)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(shields.isAuthorized ? AppColor.successMint : AppColor.almostWarm)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15), in: Capsule())

                if !shields.isAuthorized {
                    Button {
                        Task { await shields.requestAuthorizationIfNeeded() }
                    } label: {
                        Label("אשר Family Controls", systemImage: "checkmark.shield.fill")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppGradient.castle, in: Capsule())
                    }
                    .buttonStyle(.juicy)

                    if let err = shields.authorizationError {
                        VStack(spacing: 6) {
                            Text("⚠️ שגיאה באישור:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Text(err)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.md)
                        }
                        .padding(AppSpacing.md)
                        .background(Color.red.opacity(0.25), in: RoundedRectangle(cornerRadius: AppRadius.medium))
                        .padding(.horizontal, AppSpacing.lg)
                    }

                    // Hint + deep link to Settings (Screen Time)
                    VStack(spacing: AppSpacing.sm) {
                        Text("הדיאלוג לא קופץ? כנראה ש-Screen Time כבוי ב-iPad")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        Button {
                            openSettings()
                        } label: {
                            Label("פתח Settings", systemImage: "arrow.up.right.square")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.sm)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                } else {
                    Button {
                        showPicker = true
                    } label: {
                        Label(
                            selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty
                                ? "בחר אפליקציות"
                                : "ערוך בחירה (\(selection.applicationTokens.count + selection.categoryTokens.count) נבחרו)",
                            systemImage: "app.badge.fill"
                        )
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppGradient.castle, in: Capsule())
                    }
                    .buttonStyle(.juicy)
                }

                if !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty {
                    Text("✓ בחירה נשמרה")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColor.successMint)
                }

                Spacer().frame(height: 20)

                HStack(spacing: AppSpacing.md) {
                    Button {
                        step = .parentInfo
                    } label: {
                        Text("חזור")
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(.white.opacity(0.2), in: Capsule())
                            .foregroundStyle(.white)
                    }

                    JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                        step = .pinSetup
                    } label: {
                        Text("המשך")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
        }
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
            .padding(.horizontal, AppSpacing.lg)

            if let err = pinError {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.system(size: 16, weight: .semibold))
            }

            Spacer()

            HStack(spacing: AppSpacing.md) {
                Button {
                    step = .familyControls
                } label: {
                    Text("חזור")
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .background(.white.opacity(0.2), in: Capsule())
                        .foregroundStyle(.white)
                }
                JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                    savePIN()
                } label: {
                    Text("שמור")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: - Minutes

    private var minutesView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer().frame(height: 60)
            infoIcon(systemName: "clock.fill")
            Text("כמה דקות לכל תשובה נכונה?")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: AppSpacing.sm) {
                Text("\(minutesPerAnswer)")
                    .font(.system(size: bigCounterSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
                    .glow(AppColor.starGold, radius: 18)
                Text("דקות")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }

            HStack(spacing: AppSpacing.xl) {
                stepperButton(symbol: "minus") {
                    if minutesPerAnswer > 1 { minutesPerAnswer -= 1 }
                }
                stepperButton(symbol: "plus") {
                    if minutesPerAnswer < 10 { minutesPerAnswer += 1 }
                }
            }

            Text("טיפ: ניתן לשנות בהמשך מהגדרות ההורה")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                settings.minutesPerCorrectAnswer = minutesPerAnswer
                step = .hatching
            } label: {
                Text("מוכן! יאללה לילד 🎉")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }

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
            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.medium))
        .padding(.horizontal, AppSpacing.lg)
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
        guard newPIN.count == 4, newPIN.allSatisfy(\.isNumber) else {
            pinError = "הקוד חייב להיות 4 ספרות"
            return
        }
        guard newPIN == confirmPIN else {
            pinError = "הקודים לא תואמים"
            return
        }
        pinError = nil
        settings.pin = newPIN
        step = .minutes
    }

    private func complete() {
        settings.onboardingCompleted = true
        if settings.enabledTopics.isEmpty {
            settings.enabledTopics = [.addSub, .hebrewSpelling, .mulDiv]
        }
        // Ensure starter world is unlocked
        if !progress.unlockedWorlds.contains("numbers_kingdom") {
            progress.unlockWorld("numbers_kingdom")
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ShieldManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
