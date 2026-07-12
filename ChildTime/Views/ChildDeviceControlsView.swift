import SwiftUI
import FamilyControls
import os.log

private let controlsLog = Logger(subsystem: "com.rani.ChildTime", category: "ScreenTime")

/// The ONLY parent-facing screen on a CHILD's device, reached via the gear in
/// the corner and locked behind the family parent code. It holds just the things
/// Apple's Family Controls forces to be device-local — choosing which apps are
/// locked, and manually opening screen time for a while. Everything else (rewards,
/// reports, difficulty, notifications) is managed on the parent's own device.
struct ChildDeviceControlsView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var progress: ProgressStore
    @ObservedObject private var kidMode = KidModeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAppPicker = false
    @State private var removalNote: String?
    @State private var showDisconnect = false
    @State private var selection = FamilyActivitySelection()
    @State private var showAllowPicker = false
    @State private var allowSelection = FamilyActivitySelection()
    @State private var showAlwaysAllowPicker = false
    @State private var alwaysAllowSelection = FamilyActivitySelection()

    private var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
    private var allowCount: Int { allowSelection.applicationTokens.count }
    private var alwaysAllowCount: Int { alwaysAllowSelection.applicationTokens.count }
    private var isUnlocked: Bool { progress.isUnlocked }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 16, size: 12)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    if kidMode.active { exitKidModeButton }
                    statusBanner
                    quickOpenCard
                    perAppAllowCard
                    appLockCard
                    alwaysAllowedCard
                    allowDeleteCard
                    disconnectButton

                    Text("שְׁאָר הַהַגְדָּרוֹת — פְּרָסִים, דּוּחוֹת, רָמַת קוֹשִׁי וְהַתְרָאוֹת — מְנוּהֲלוֹת בְּמַכְשִׁיר הַהוֹרֶה.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)

                    Button {
                        Haptic.light()
                        dismiss()
                    } label: {
                        Text("סְגִירָה")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
        .onChangeCompat(of: selection) { _, new in
            settings.activitySelectionData = SelectionStorage.encode(new)
            // Keep the live shield in sync only when the child isn't mid-unlock.
            if !isUnlocked { shields.applyShield(from: new) }
        }
        .onAppear {
            selection = SelectionStorage.decode(settings.activitySelectionData)
            allowSelection = SelectionStorage.decode(settings.allowExceptionData)
            alwaysAllowSelection = SelectionStorage.decode(settings.alwaysAllowedAppsData)
        }
        .confirmationDialog("לְנַתֵּק אֶת הַמַּכְשִׁיר?",
                            isPresented: $showDisconnect, titleVisibility: .visible) {
            Button("נַתֵּק וְאַפֵּס", role: .destructive) {
                HouseholdManager.shared.resetAsRemovedDevice()
                dismiss()
            }
            Button("בִּטּוּל", role: .cancel) {}
        } message: {
            Text("הַמַּכְשִׁיר יִתְנַתֵּק מֵהַיֶּלֶד וְיַחֲזוֹר לְמַצָּב הַתְחָלָתִי (כְּאִלּוּ הוּתְקַן מֵחָדָשׁ). הַהִתְקַדְּמוּת בֶּעָנָן נִשְׁמֶרֶת — אֶפְשָׁר תָּמִיד לְחַבֵּר שׁוּב בִּסְרִיקַת הַקּוֹד.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.starGold)
                .glow(AppColor.starGold, radius: 12)
            Text("בַּקָּרַת הַמַּכְשִׁיר")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Exit Kid Mode (parent's phone temporarily acting as a kid device)

    /// Shown only while Kid Mode is active. The parent already passed the gate to
    /// reach this screen, so leaving is a single tap from here — replaces the old
    /// floating "exit" button that overlapped the top-bar buttons.
    private var exitKidModeButton: some View {
        Button {
            Haptic.medium()
            kidMode.exit()
            dismiss()
        } label: {
            Label("צֵא מִמַּצַּב יֶלֶד", systemImage: "figure.walk.departure")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AppColor.flameOrange, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .glow(AppColor.flameOrange.opacity(0.6), radius: 8)
        }
        .buttonStyle(.juicy)
    }

    // MARK: - Reusable card + section header

    private func controlCard<Content: View>(tint: Color = .white,
                                            @ViewBuilder _ content: () -> Content) -> some View {
        // RTL: .leading is the RIGHT edge, so headers/text sit flush right.
        VStack(alignment: .leading, spacing: AppSpacing.md) { content() }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(tint.opacity(0.45), lineWidth: 1))
    }

    private func sectionHead(_ title: String, _ subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(title).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            } icon: {
                Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(tint)
            }
            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status banner (one clear place for the current lock state)

    @ViewBuilder private var statusBanner: some View {
        if isUnlocked {
            banner(title: "פָּתוּחַ עַכְשָׁיו",
                   detail: "נִשְׁאֲרוּ כְּ-\(max(1, progress.unlockSecondsRemaining / 60)) דַּקּוֹת",
                   open: true, lock: { Haptic.medium(); lockNow() })
        } else if settings.allowExceptionActive {
            banner(title: "אַפְּלִיקַצְיָה מְסוּיֶּמֶת פְּתוּחָה",
                   detail: "הַשְּׁאָר נְעוּלוֹת\(allowEndText)",
                   open: true, lock: { Haptic.medium(); cancelAllowException() })
        } else {
            banner(title: "הַכֹּל נָעוּל", detail: "הַיֶּלֶד מַרְוִיחַ זְמַן כְּדֵי לִפְתּוֹחַ", open: false, lock: nil)
        }
    }

    private func banner(title: String, detail: String, open: Bool, lock: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            // RTL: first child renders on the RIGHT, so icon + text sit flush
            // right; the Spacer (and Lock button) fall to the left.
            Image(systemName: open ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 22))
                .foregroundStyle(open ? AppColor.successMint : AppColor.starGold)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(detail).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            if let lock {
                Button { lock() } label: {
                    Label("נְעוֹל", systemImage: "lock.fill")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppColor.flameOrange.opacity(0.9), in: Capsule())
                }
                .buttonStyle(.juicy)
            }
        }
        .padding(.horizontal, AppSpacing.lg).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background((open ? AppColor.successMint : AppColor.starGold).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke((open ? AppColor.successMint : AppColor.starGold).opacity(0.5), lineWidth: 1))
    }

    // MARK: - Quick open (manual, all apps)

    private var quickOpenCard: some View {
        controlCard(tint: AppColor.starGold) {
            sectionHead("פְּתִיחָה מְהִירָה",
                        "חַד-פַּעֲמִי · פּוֹתֵחַ אֶת כָּל הָאַפְּלִיקַצְיוֹת. לֹא מֵהַדַּקּוֹת שֶׁהַיֶּלֶד צָבַר.",
                        icon: "hourglass", tint: AppColor.starGold)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                durationPill("חֲצִי שָׁעָה", minutes: 30)
                durationPill("שָׁעָה", minutes: 60)
                durationPill("שְׁעָתַיִם", minutes: 120)
                durationPill("עַד סוֹף הַיּוֹם", minutes: minutesUntilEndOfDay())
            }
        }
    }

    private func durationPill(_ title: String, minutes: Int) -> some View {
        Button {
            Haptic.success()
            grant(minutes: minutes)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.textOnLight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.juicy)
    }

    // MARK: - Per-app temporary allowance

    private var perAppAllowCard: some View {
        controlCard(tint: AppColor.diamondBlue) {
            sectionHead("פְּתִיחַת אַפְּלִיקַצְיָה מְסוּיֶּמֶת",
                        "רַק אַפְּלִיקַצְיָה אַחַת אוֹ כַּמָּה (לְמָשָׁל יוּטְיוּבּ). הַשְּׁאָר נְעוּלוֹת.",
                        icon: "app.badge.checkmark", tint: AppColor.diamondBlue)

            Button {
                Task {
                    await shields.requestAuthorizationIfNeeded()
                    if shields.isAuthorized { showAllowPicker = true }
                }
            } label: {
                Label(allowCount > 0 ? "\(allowCount) אַפְּלִיקַצְיוֹת נִבְחֲרוּ · עֲרִיכָה" : "בְּחִירַת אַפְּלִיקַצְיוֹת",
                      systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(.juicy)

            if allowCount > 0 {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    allowDurationPill("חֲצִי שָׁעָה", minutes: 30)
                    allowDurationPill("שָׁעָה", minutes: 60)
                    allowDurationPill("שְׁעָתַיִם", minutes: 120)
                    allowDurationPill("עַד סוֹף הַיּוֹם", minutes: minutesUntilEndOfDay())
                }
            }
        }
        .familyActivityPicker(isPresented: $showAllowPicker, selection: $allowSelection)
    }

    private func allowDurationPill(_ title: String, minutes: Int) -> some View {
        Button {
            Haptic.success()
            startAllow(minutes: minutes)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [AppColor.successMint, Color(hex: "06A57E")],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.juicy)
    }

    private var allowEndText: String {
        guard let end = settings.allowExceptionEndsAt else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return " עַד \(f.string(from: end))"
    }

    // MARK: - App lock

    private var appLockCard: some View {
        controlCard(tint: AppColor.successMint) {
            sectionHead("אֵילוּ אַפְּלִיקַצְיוֹת נְעוּלוֹת",
                        selectedCount > 0
                            ? "\(selectedCount) אַפְּלִיקַצְיוֹת/קָטֵגוֹרְיוֹת נְעוּלוֹת עַד שֶׁמַּרְוִיחִים זְמַן."
                            : "עֲדַיִן לֹא נִבְחֲרוּ אַפְּלִיקַצְיוֹת לִנְעִילָה.",
                        icon: "lock.app.dashed", tint: AppColor.successMint)
            Button {
                Task {
                    await shields.requestAuthorizationIfNeeded()
                    if shields.isAuthorized { showAppPicker = true }
                }
            } label: {
                Label(selectedCount > 0 ? "עֲרִיכַת הָרְשִׁימָה" : "בְּחִירַת אַפְּלִיקַצְיוֹת",
                      systemImage: "app.badge.fill")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(colors: [AppColor.successMint, Color(hex: "06A57E")],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.juicy)
        }
    }

    // MARK: - Always-allowed apps (permanent whitelist, even under a blocked category)

    /// Apps that are NEVER locked — even when their whole category is blocked. Lets
    /// the parent permanently allow a specific app (e.g. a newly installed app that
    /// fell under a locked category) without unlocking the entire category.
    private var alwaysAllowedCard: some View {
        controlCard(tint: AppColor.companionGlow) {
            sectionHead("אַפְּלִיקַצְיוֹת שֶׁתָּמִיד מוּתָּרוֹת",
                        "אַף פַּעַם לֹא נְעוּלוֹת — גַּם אִם הַקָּטֵגוֹרְיָה שֶׁלָּהֶן חֲסוּמָה. שִׁמּוּשִׁי כְּדֵי לְאַפְשֵׁר אַפְּלִיקַצְיָה חֲדָשָׁה לִצְמִיתוּת.",
                        icon: "checkmark.shield.fill", tint: AppColor.companionGlow)
            Button {
                Task {
                    await shields.requestAuthorizationIfNeeded()
                    if shields.isAuthorized { showAlwaysAllowPicker = true }
                }
            } label: {
                Label(alwaysAllowCount > 0 ? "\(alwaysAllowCount) אַפְּלִיקַצְיוֹת מוּתָּרוֹת · עֲרִיכָה" : "בְּחִירַת אַפְּלִיקַצְיוֹת",
                      systemImage: "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(.juicy)
        }
        .familyActivityPicker(isPresented: $showAlwaysAllowPicker, selection: $alwaysAllowSelection)
        .onChangeCompat(of: alwaysAllowSelection) { _, new in
            settings.alwaysAllowedAppsData = SelectionStorage.encode(new)
            // Re-apply the locked baseline so the whitelist takes effect right away
            // (unless the child is mid-unlock, where everything is already open).
            if !isUnlocked { shields.applyDefaultLock() }
        }
    }

    // MARK: - Allow deleting the app (parent only, temporary window)

    /// A child device blocks app deletion (so the kid can't uninstall to escape
    /// the lock). This lets the PARENT — who's already past the code gate — open a
    /// short window to legitimately uninstall Tofy. It auto-re-locks after 5 min.
    private var allowDeleteCard: some View {
        controlCard(tint: AppColor.flameOrange) {
            sectionHead("מְחִיקַת הָאַפְּלִיקַצְיָה",
                        "בְּמַכְשִׁיר יֶלֶד הַמְּחִיקָה חֲסוּמָה. לִמְחִיקָה אֲמִתִּית — פִּתְחוּ חַלּוֹן קָצָר וְהָסִירוּ אֶת טוֹפִי מִמָּסַךְ הַבַּיִת.",
                        icon: "trash", tint: AppColor.flameOrange)
            Button {
                Haptic.medium()
                settings.appRemovalUnlockedUntil = Date().addingTimeInterval(5 * 60)
                shields.setAppRemovalLocked(false)
                removalNote = "נִפְתַּח חַלּוֹן שֶׁל 5 דַּקּוֹת. צְאוּ לְמָסַךְ הַבַּיִת ← לְחִיצָה אֲרוּכָּה עַל טוֹפִי ← \u{201C}הָסֵר אַפְּלִיקַצְיָה\u{201D}. אַחַר כָּךְ הַנְּעִילָה חוֹזֶרֶת לְבַד."
            } label: {
                Label("אַפְשְׁרוּ מְחִיקָה לְ-5 דַּקּוֹת", systemImage: "trash")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(AppColor.flameOrange.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.juicy)
            if let removalNote {
                Text(removalNote)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Disconnect THIS device from the child and reset to a just-installed state.
    /// (Parent-gated, like everything on this screen.) Cloud progress is kept.
    private var disconnectButton: some View {
        Button { Haptic.medium(); showDisconnect = true } label: {
            Label("הִתְנַתְּקוּ מֵהַמִּשְׁפָּחָה", systemImage: "iphone.slash")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.flameOrange)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColor.flameOrange.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.juicy)
    }

    // MARK: - Actions

    private func grant(minutes: Int) {
        controlsLog.notice("manual quick-open tapped: \(minutes, privacy: .public) min")
        // Set the play window IMMEDIATELY and authoritatively — before any async
        // shield work — so the countdown always reflects exactly the tapped amount
        // and can't be pre-empted by a slow auth hop or a stale earlier window.
        // A ONE-TIME fixed window: it does NOT stack and does NOT touch the
        // play-minutes the child EARNED — tapping again just replaces the window.
        progress.startUnlock(minutes: minutes, manual: true)
        Task {
            await shields.requestAuthorizationIfNeeded()
            shields.cancelScheduledReshield()
            shields.unlock(minutes: minutes)
        }
        dismiss()
    }

    private func lockNow() {
        shields.cancelScheduledReshield()
        progress.endUnlock()
        shields.applyShield(from: SelectionStorage.decode(settings.activitySelectionData))
        dismiss()
    }

    private func startAllow(minutes: Int) {
        Task {
            await shields.requestAuthorizationIfNeeded()
            let blocked = SelectionStorage.decode(settings.activitySelectionData)
            settings.allowExceptionData = SelectionStorage.encode(allowSelection)
            settings.allowExceptionEndsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
            shields.startAllowException(allowed: allowSelection, blocked: blocked, minutes: minutes)
            dismiss()
        }
    }

    private func cancelAllowException() {
        shields.cancelScheduledReshield()
        settings.clearAllowException()
        shields.applyShield(from: SelectionStorage.decode(settings.activitySelectionData))
        dismiss()
    }

    private func minutesUntilEndOfDay() -> Int {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) else { return 120 }
        let endOfDay = cal.startOfDay(for: tomorrow)
        return max(1, Int(endOfDay.timeIntervalSinceNow / 60))
    }
}

#Preview {
    ChildDeviceControlsView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ShieldManager.shared)
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
