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
        case ageSelection
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
            case .ageSelection: ageSelectionView
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
                        BubbleSpeech(text: "היי! אני טופי 💫")
                            .offset(x: welcomeCompanionSize * 0.55, y: -30)
                            .transition(.scale.combined(with: .opacity))
                    }
                    CompanionView(controller: welcomeCompanion, size: welcomeCompanionSize)
                        .scaleEffect(welcomeTitleAppeared ? 1 : 0.3)
                        .opacity(welcomeTitleAppeared ? 1 : 0)
                }
                .frame(height: welcomeCompanionSize * 1.8)

                // Animated title with letter-by-letter reveal feel
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

            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Family Controls

    private var familyControlsView: some View {
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

            // Friendly status pill — only shown when something needs the parent's attention
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

            // Bottom nav — back + continue, sized consistently
            HStack(spacing: AppSpacing.md) {
                Button {
                    step = .parentInfo
                } label: {
                    Text("חזור")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.juicy)

                JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint, maxWidth: 280) {
                    step = .pinSetup
                } label: {
                    Text("המשך")
                }
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        step = .ageSelection
    }

    // MARK: - Age selection

    private var ageSelectionView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: 30)
                infoIcon(systemName: "figure.child")

                Text("בן כמה הילד?")
                    .font(.system(size: isCompact ? 28 : 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("נבחר אוטומטית את הנושאים והקושי. אפשר לשנות הכל.")
                    .font(.system(size: isCompact ? 15 : 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)

                // Compact age picker — segmented chips
                HStack(spacing: AppSpacing.sm) {
                    ForEach(ChildAge.allCases) { age in
                        compactAgeChip(age)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                // Live preview of what was selected
                previewSection
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 10)

                JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                    minutesPerAnswer = settings.minutesPerCorrectAnswer
                    step = .minutes
                } label: {
                    Text("המשך")
                        .font(.system(size: isCompact ? 22 : 26, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    private func compactAgeChip(_ age: ChildAge) -> some View {
        let isSelected = settings.childAge == age
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                settings.applyAgeDefaults(age)
            }
            Haptic.light()
        } label: {
            VStack(spacing: 4) {
                Text(age.emoji)
                    .font(.system(size: isCompact ? 28 : 34))
                Text(age.label)
                    .font(.system(size: isCompact ? 16 : 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.28 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .stroke(
                                isSelected ? AppColor.successMint : .white.opacity(0.2),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
            )
            .glow(isSelected ? AppColor.successMint : .clear, radius: isSelected ? 10 : 0)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.juicy)
    }

    private var previewSection: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.sm) {
            HStack {
                Text("הקושי שיוגדר")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.companionGlow)
                Spacer()
                Text(settings.childAge.description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            ForEach(Topic.allCases) { topic in
                topicPreviewRow(topic)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func topicPreviewRow(_ topic: Topic) -> some View {
        let isEnabled = settings.enabledTopics.contains(topic)
        return HStack(spacing: AppSpacing.sm) {
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    if newValue { settings.enabledTopics.insert(topic) }
                    else { settings.enabledTopics.remove(topic) }
                }
            ))
            .labelsHidden()
            .tint(AppColor.successMint)

            HStack(spacing: 6) {
                Text(topic.emoji).font(.system(size: 22))
                Text(topic.displayName)
                    .font(.system(size: isCompact ? 15 : 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(isEnabled ? 1 : 0.4)
            }

            Spacer()

            if isEnabled {
                Picker("", selection: Binding(
                    get: { settings.difficulty(for: topic) },
                    set: { settings.setDifficulty($0, for: topic) }
                )) {
                    Text("קל").tag(Difficulty.easy)
                    Text("בינוני").tag(Difficulty.medium)
                    Text("קשה").tag(Difficulty.hard)
                }
                .pickerStyle(.menu)
                .tint(.white)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: Capsule())
            }
        }
        .padding(.vertical, 2)
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
        .environment(\.layoutDirection, .rightToLeft)
}
