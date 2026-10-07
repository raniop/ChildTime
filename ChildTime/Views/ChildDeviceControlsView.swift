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
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var kidMode = KidModeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showAppPicker = false
    @State private var showDisconnect = false
    @State private var selection = SelectionStorage.empty()
    @State private var showAllowPicker = false
    @State private var allowSelection = SelectionStorage.empty()
    @State private var showOpenPicker = false
    @State private var openSelection = SelectionStorage.empty()
    @State private var diagnostic: String?
    /// 🧪 "מה נעול בפועל" is a tool for US, not something to show a family —
    /// Rani: "אי אפשר להציג דבר כזה במכשיר אמיתי של אנשים! תשאיר את זה אולי
    /// רק על המשפחה שלי בשביל הבדיקות". A child device has no account to
    /// recognise the team by, so it is a switch on the device itself: a
    /// three-second press on the icon at the top of this screen (which is
    /// already behind the parent code). Per device, off by default.
    @AppStorage("tofy.team.lockDiagnostics") private var teamDiagnostics = false

    private var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
    private var allowCount: Int { allowSelection.applicationTokens.count }
    /// Apps that stay open on a locked device. This is the list that ARMS the
    /// "new apps are locked too" model — only apps count, not categories
    /// (see `ShieldPolicy.swift`).
    private var openCount: Int { openSelection.applicationTokens.count }
    /// Every child device is fully locked with no setup (see
    /// `ShieldInputs.newAppLockArmed`) — "what stays open" is optional.
    private var newAppsLocked: Bool { settings.newAppLockArmed }
    /// Apps the block-list names individually. A list of CATEGORIES with zero
    /// apps cannot reach Safari, Photos or Messages — see SelectionStorage.
    private var isUnlocked: Bool { progress.isUnlocked }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    if kidMode.active { exitKidModeButton }
                    statusBanner
                    quickOpenCard
                    appsCard
                    appleScreenTimeCard
                    if teamDiagnostics { lockDiagnosticsCard }
                    allowDeleteCard
                    disconnectButton

                    Text(tr("שְׁאָר הַהַגְדָּרוֹת — פְּרָסִים, דּוּחוֹת, רָמַת קוֹשִׁי וְהַתְרָאוֹת — מְנוּהֲלוֹת בְּמַכְשִׁיר הַהוֹרֶה."))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)

                    Button {
                        Haptic.light()
                        dismiss()
                    } label: {
                        Text(tr("סְגִירָה"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(Capsule().fill(.white.opacity(0.14)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            selection = SelectionStorage.decode(settings.activitySelectionData)
            allowSelection = SelectionStorage.decode(settings.allowExceptionData)
            openSelection = SelectionStorage.decode(settings.allowedAppsData)
            foldIntoOneList()
        }
        .confirmationDialog(tr("לְנַתֵּק אֶת הַמַּכְשִׁיר?"),
                            isPresented: $showDisconnect, titleVisibility: .visible) {
            Button(tr("נַתֵּק וְאַפֵּס"), role: .destructive) {
                HouseholdManager.shared.resetAsRemovedDevice()
                dismiss()
            }
            Button(tr("בִּטּוּל"), role: .cancel) {}
        } message: {
            Text(tr("הַמַּכְשִׁיר יִתְנַתֵּק מֵהַיֶּלֶד וְיַחֲזוֹר לְמַצָּב הַתְחָלָתִי (כְּאִלּוּ הוּתְקַן מֵחָדָשׁ). הַהִתְקַדְּמוּת בֶּעָנָן נִשְׁמֶרֶת — אֶפְשָׁר תָּמִיד לְחַבֵּר שׁוּב בִּסְרִיקַת הַקּוֹד."))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                // 🧪 The team's switch for "מה נעול בפועל" — see `teamDiagnostics`.
                .onLongPressGesture(minimumDuration: 3) {
                    teamDiagnostics.toggle()
                    Haptic.success()
                }
            Text(tr("בַּקָּרַת הַמַּכְשִׁיר"))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(GlassInk.primary)
                .shadow(color: .black.opacity(0.18), radius: 7, y: 2)
        }
        // On the foldable the header fills the band beside the clock, so the
        // first card starts below it at the glass's full width.
        .fillsTopBand(above: DisplayProbeView.minimumTopMargin + AppSpacing.md)
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
            // The same words as the button on the child's home — one action,
            // one name everywhere.
            Label(tr("יְצִיאָה מִמַּצַּב יֶלֶד וְשִׁחְרוּר נְעִילַת הַמַּכְשִׁיר"), systemImage: "lock.open.fill")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .ctaGlass(AppColor.flameOrange, Color(hex: "FF9F1C"), colour: 0.7)
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
            .glassPane(radius: 22, tint: tint == .white ? nil : tint)
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
            banner(title: tr("פָּתוּחַ עַכְשָׁיו"),
                   detail: tr("נִשְׁאֲרוּ כְּ-\(max(1, progress.unlockSecondsRemaining / 60)) דַּקּוֹת"),
                   open: true, lock: { Haptic.medium(); lockNow() })
        } else if settings.allowExceptionActive {
            banner(title: tr("אַפְּלִיקַצְיָה מְסוּיֶּמֶת פְּתוּחָה"),
                   detail: tr("הַשְּׁאָר נְעוּלוֹת\(allowEndText)"),
                   open: true, lock: { Haptic.medium(); cancelAllowException() })
        } else {
            banner(title: tr("הַכֹּל נָעוּל"),
                   detail: newAppsLocked
                       ? tr("כּוֹלֵל אַפְּלִיקַצְיוֹת חֲדָשׁוֹת")
                       : tr("אַפְּלִיקַצְיוֹת חֲדָשׁוֹת לֹא נְעוּלוֹת"),
                   open: false, lock: nil)
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
                    Label(tr("נְעַל"), systemImage: "lock.fill")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(AppColor.flameOrange.opacity(0.55)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.juicy)
            }
        }
        .padding(.horizontal, AppSpacing.lg).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .glassPane(radius: 18, tint: open ? AppColor.successMint : Color(hex: "FFD23F"))
    }

    // MARK: - Quick open (manual, all apps)

    private var quickOpenCard: some View {
        // Same rule as the parent dashboard: a parent GIVES 💝 minutes into the
        // child's synced gift pocket — never a surprise unlock. The child opens
        // them when they choose (from any device). Each give is capped at what's
        // left until midnight (no daily accumulator — see giftAllowance).
        let capLeft = ProgressStore.minutesUntilMidnight()
        return controlCard(tint: AppColor.starGold) {
            sectionHead(tr("תֵּן דַּקּוֹת מַתָּנָה 💝"),
                        capLeft > 0
                            ? tr("נִכְנָס לַכִּיס 💝 שֶׁל הַיֶּלֶד — \(profileName) \(isGirl ? tr("פּוֹתַחַת") : tr("פּוֹתֵחַ")) מָתַי שֶׁ\(isGirl ? tr("תִּרְצֶה") : tr("יִרְצֶה")), מִכָּל מַכְשִׁיר. אֶפְשָׁר לָתֵת עוֹד עַד \(capLeft) דַּקּוֹת הַיּוֹם (עַד חֲצוֹת).")
                            : tr("עוֹד רֶגַע חֲצוֹת — מִיָּד אַחֲרֵי חֲצוֹת אֶפְשָׁר לָתֵת שׁוּב."),
                        icon: "gift.fill", tint: AppColor.starGold)
            // Same five as the parent's own menu — "רבע שעה" was missing here.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                durationPill(tr("רֶבַע שָׁעָה"), minutes: 15, capLeft: capLeft)
                durationPill(tr("חֲצִי שָׁעָה"), minutes: 30, capLeft: capLeft)
                durationPill(tr("שָׁעָה"), minutes: 60, capLeft: capLeft)
                durationPill(tr("שְׁעָתַיִם"), minutes: 120, capLeft: capLeft)
                durationPill(tr("4 שָׁעוֹת"), minutes: 240, capLeft: capLeft)
            }
            if progress.parentGiftMinutes > 0 {
                Text(tr("בַּכִּיס עַכְשָׁיו: 💝 \(progress.parentGiftMinutes) דַּקּוֹת"))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.textOnLight.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var profileName: String { profiles.active?.name ?? tr("הַיֶּלֶד") }
    private var isGirl: Bool { profiles.active?.gender == .girl }

    private func durationPill(_ title: String, minutes: Int, capLeft: Int) -> some View {
        let allowed = min(minutes, capLeft)
        return Button {
            Haptic.success()
            gift(minutes: allowed)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "4B3FBF"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.92)))
        }
        .buttonStyle(.juicy)
        .disabled(allowed <= 0)
        .opacity(allowed <= 0 ? 0.45 : 1)
    }

    // MARK: - 📱 Apps: ONE place

    /// Everything about which apps open, in ONE card.
    ///
    /// Rani, on his daughter's device: "בחר מה נשאר פתוח הוא ריק… באילו
    /// אפליקציות נעולות עשיתי הכל וזה לא שינה כלום… למה צריך 4 שונים במקום
    /// שיהיה 1 ששולט". This screen had four cards, four of Apple's pickers and
    /// a switch — "locked apps", "always allowed", "lock new apps too" and
    /// "open one app" — that all fed the same shield and contradicted each
    /// other. Now there is one decision and it is stated as one:
    ///
    /// 1️⃣ **What stays open.** Everything else is locked, an app installed
    ///    tomorrow included. This is the list that matters, so it is the big
    ///    white button. ("Always allowed" was the same list under a second
    ///    name; it is folded in by `foldIntoOneList`.)
    /// 2️⃣ **Every app on the device, once.** Not a second list to curate: the
    ///    one-time step that hands us a token for each app, because iOS will
    ///    only lock an app by name — Safari, Photos and Messages have no
    ///    category and were never covered without it (build 190's "nothing
    ///    changed"). It shows a ✓ once done and is only loud while missing.
    /// 3️⃣ **Open for a while** — an action, not a list: pick an app, pick how
    ///    long, it locks again by itself.
    private var appsCard: some View {
        controlCard(tint: newAppsLocked ? AppColor.successMint : AppColor.flameOrange) {
            sectionHead(tr("מָה פָּתוּחַ וּמָה נָעוּל"),
                        newAppsLocked
                            ? tr("הַכֹּל נָעוּל עַד שֶׁמַּרְוִיחִים זְמַן — גַּם אַפְּלִיקַצְיָה שֶׁתֻּתְקַן מָחָר. טוֹפִי תָּמִיד פָּתוּחַ. רוֹצִים שֶׁעוֹד מַשֶּׁהוּ יִשָּׁאֵר פָּתוּחַ? בַּחֲרוּ אוֹתוֹ כָּאן.")
                            : tr("בַּחֲרוּ מָה נִשְׁאָר פָּתוּחַ וְסַמְּנוּ גַּם אֶת טוֹפִי. כָּל הַשְּׁאָר יִנָּעֵל — גַּם אַפְּלִיקַצְיָה שֶׁתֻּתְקַן מָחָר."),
                        icon: newAppsLocked ? "lock.shield.fill" : "exclamationmark.triangle.fill",
                        tint: newAppsLocked ? AppColor.successMint : AppColor.flameOrange)

            // 1️⃣ The one button, straight to "what stays open" (Rani: "רק מקום
            // אחד שפותח ונועל"). It used to run a "tick every app on the
            // device" step first; that list was 119 apps, iOS drops any set
            // over 50 (`shieldTokenLimit`), so the step did nothing at all.
            Button {
                openPicker { showOpenPicker = true }
            } label: {
                Label(openCount > 0
                      ? tr("פְּתוּחוֹת תָּמִיד: \(openCount) · עֲרִיכָה")
                      : tr("בַּחֲרוּ מָה נִשְׁאָר פָּתוּחַ"),
                      systemImage: "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "4B3FBF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.92)))
            }
            .buttonStyle(.juicy)

            Rectangle().fill(.white.opacity(0.18)).frame(height: 1).padding(.vertical, 2)

            // 3️⃣ Open for a while.
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("פְּתִיחָה זְמַנִּית"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(tr("אַפְּלִיקַצְיָה אַחַת אוֹ כַּמָּה, לִזְמַן קָצוּב. בְּסוֹפוֹ הֵן נִנְעָלוֹת לְבַד."))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                openPicker { showAllowPicker = true }
            } label: {
                Label(allowCount > 0
                      ? tr("נִבְחֲרוּ: \(allowCount) · עֲרִיכָה")
                      : tr("בְּחִירַת אַפְּלִיקַצְיוֹת לִפְתִּיחָה"),
                      systemImage: "timer")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.juicy)

            if allowCount > 0 {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    allowDurationPill(tr("חֲצִי שָׁעָה"), minutes: 30)
                    allowDurationPill(tr("שָׁעָה"), minutes: 60)
                    allowDurationPill(tr("שְׁעָתַיִם"), minutes: 120)
                    allowDurationPill(tr("עַד סוֹף הַיּוֹם"), minutes: minutesUntilEndOfDay())
                }
            }
        }
        .tofyActivityPicker(title: PickerCopy.allowList.title, header: PickerCopy.allowList.header, footer: PickerCopy.allowList.footer, isPresented: $showOpenPicker, selection: $openSelection)
        .tofyActivityPicker(title: PickerCopy.blocked.title, header: PickerCopy.blocked.header, footer: PickerCopy.blocked.footer, isPresented: $showAppPicker, selection: $selection)
        .tofyActivityPicker(title: PickerCopy.temporaryAllow.title, header: PickerCopy.temporaryAllow.header, footer: PickerCopy.temporaryAllow.footer, isPresented: $showAllowPicker, selection: $allowSelection)
        // Every change takes effect at once — no relaunch. Not while the child
        // is mid-window: everything is open then, and the baseline comes back
        // when the window closes.
        .onChangeCompat(of: openSelection) { _, new in
            settings.allowedAppsData = SelectionStorage.encode(new)
            if !isUnlocked { shields.applyDefaultLock() }
        }
        .onChangeCompat(of: selection) { _, new in
            settings.activitySelectionData = SelectionStorage.encode(new)
            if !isUnlocked { shields.applyDefaultLock() }
        }
    }

    /// Ask for Screen Time first (a no-op once granted), then open the picker.
    private func openPicker(_ show: @escaping () -> Void) {
        Task {
            await shields.requestAuthorizationIfNeeded(userInitiated: true)
            if shields.isAuthorized { show() }
        }
    }

    /// The four lists became one, so an install that still holds the old pieces
    /// is folded into it once: "always allowed" joins "what stays open" (the
    /// policy already treated them the same), and "lock new apps too" — a
    /// switch that no longer exists on screen — is on, the allow-list model
    /// Rani chose. Nothing that was open is closed by this.
    private func foldIntoOneList() {
        if !settings.lockNewApps { settings.lockNewApps = true }
        let always = SelectionStorage.decode(settings.alwaysAllowedAppsData)
        guard !always.applicationTokens.isEmpty || !always.webDomainTokens.isEmpty else { return }
        var merged = openSelection
        merged.applicationTokens.formUnion(always.applicationTokens)
        merged.webDomainTokens.formUnion(always.webDomainTokens)
        // Saved HERE, before the old list is emptied — not left to an onChange
        // that may or may not fire for a change made inside onAppear. An app a
        // parent had kept open must land somewhere they can see and edit it.
        settings.allowedAppsData = SelectionStorage.encode(merged)
        settings.alwaysAllowedAppsData = SelectionStorage.encode(SelectionStorage.empty())
        openSelection = merged
        if !isUnlocked { shields.applyDefaultLock() }
    }

    private func allowDurationPill(_ title: String, minutes: Int) -> some View {
        Button {
            Haptic.success()
            startAllow(minutes: minutes)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "4B3FBF"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.92)))
        }
        .buttonStyle(.juicy)
    }

    private var allowEndText: String {
        guard let end = settings.allowExceptionEndsAt else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return tr(" עַד \(f.string(from: end))")
    }

    // MARK: - 🩺 What is really locked right now

    /// The screen that turns "I pressed it and nothing happened" into facts.
    ///
    /// Everything above describes what the parent CHOSE. This says what iOS was
    /// actually told, which is a different thing in three ways that have all
    /// bitten us: Screen Time may never have been granted (every write is then
    /// silently ignored), the picker may have handed back categories and zero
    /// app tokens (so Apple's own apps are untouched), and the allow-list may be
    /// empty (so new apps are not covered).
    private var lockDiagnosticsCard: some View {
        controlCard(tint: AppColor.companionGlow) {
            sectionHead(tr("מָה נָעוּל בְּפֹעַל"),
                        tr("זֶה מָה שֶׁ-iOS קִבֵּל מֵאִתָּנוּ בָּרֶגַע זֶה."),
                        icon: "stethoscope", tint: AppColor.companionGlow)

            diagnosticRow(tr("הַרְשָׁאַת זְמַן מָסָךְ"),
                          shields.isAuthorized ? tr("יֵשׁ") : tr("אֵין — שׁוּם נְעִילָה לֹא תַּעֲבֹד"),
                          ok: shields.isAuthorized)
            diagnosticRow(tr("פְּתוּחוֹת תָּמִיד"), "\(openCount)", ok: true)
            // Read BACK from iOS, not what we think we sent — the lesson of
            // builds 190–191, where everything we "sent" by name was dropped.
            diagnosticRow(tr("הַנְּעִילָה בָּאַיְפוֹן"),
                          TofyShield.categoryLockHeld ? tr("פְּעִילָה") : tr("כְּבוּיָה"),
                          ok: TofyShield.categoryLockHeld || isUnlocked)
            diagnosticRow(tr("אַפְּלִיקַצְיָה חֲדָשָׁה"),
                          newAppsLocked ? tr("נְעוּלָה") : tr("פְּתוּחָה"),
                          ok: newAppsLocked)

            Button {
                openPicker { showAppPicker = true }
            } label: {
                Label(tr("סִמּוּן מֵחָדָשׁ שֶׁל כָּל הָאַפְּלִיקַצְיוֹת"), systemImage: "square.grid.3x3.fill")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.juicy)

            Button {
                Haptic.light()
                diagnostic = shields.applyAndReport()
            } label: {
                Label(tr("הַחִילוּ עַכְשָׁו וּבִדְקוּ"), systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.juicy)

            if let diagnostic {
                // The same line the device writes to Console.app. Tappable to
                // copy, so it can be pasted into a message to us.
                Text(diagnostic)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        UIPasteboard.general.string = diagnostic
                        Haptic.success()
                    }
            }
        }
    }

    private func diagnosticRow(_ title: String, _ value: String, ok: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ok ? AppColor.successMint : AppColor.flameOrange)
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 🍏 Apple's own Screen Time

    /// The same three tips the parent saw right after joining, kept here —
    /// behind the parent code, so this one may open Settings.
    private var appleScreenTimeCard: some View {
        controlCard(tint: AppColor.companionGlow) {
            sectionHead(tr("זְמַן מָסָךְ שֶׁל אַפֶּל"),
                        tr("שְׁלוֹשָׁה דְּבָרִים בְּ\"זמן מסך\" שֶׁל אַפֶּל — הָרִאשׁוֹן הוּא הֶחָשׁוּב:"),
                        icon: "hourglass", tint: AppColor.companionGlow)
            AppleScreenTimeStepsList(steps: AppleScreenTimeTips.steps)
            ScreenTimeShowMeButton()
            openSettingsButton
        }
    }

    /// Apple publishes no link to the Screen Time page itself (a private
    /// "prefs:" URL is a rejection), so: Settings, and where to go from there.
    private var openSettingsButton: some View {
        VStack(spacing: 6) {
            Button {
                Haptic.light()
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Label(tr("פִּתְחוּ אֶת הַהַגְדָּרוֹת"), systemImage: "gearshape.fill")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "4B3FBF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.92)))
            }
            .buttonStyle(.juicy)
            Text(tr("נִפְתַּח הַדַּף שֶׁל טוֹפִי בַּהַגְדָּרוֹת — חִזְרוּ צַעַד אֶחָד אֲחוֹרָה וּבַחֲרוּ \"זְמַן מָסָךְ\"."))
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Deleting Tofy (parent only)

    /// Rani: "חייבים איכשהו להסביר להורה שאם הוא רוצה למחוק את טופי אז הוא חייב
    /// להיכנס להגדרות זמן מסך לגלול עד למטה לישומים עם גישה לזמן מסך ולסגור את
    /// טופי". The short "allow deletion for 5 minutes" window this replaces left
    /// parents stuck; switching off Tofy's Screen Time access is what actually
    /// releases the device, so the card says exactly that, step by step.
    private var allowDeleteCard: some View {
        controlCard(tint: AppColor.flameOrange) {
            sectionHead(tr("מְחִיקַת הָאַפְּלִיקַצְיָה"),
                        tr("כְּדֵי לִמְחֹק אֶת טוֹפִי מֵהַטֶּלֶפוֹן הַזֶּה:"),
                        icon: "trash", tint: AppColor.flameOrange)
            AppleScreenTimeStepsList(steps: [
                .init(id: 1, title: tr("\"הגדרות\" ← \"זמן מסך\""),
                      detail: tr("אִם אַתֶּם מְנַהֲלִים אֶת הַיֶּלֶד מֵהַטֶּלֶפוֹן שֶׁלָּכֶם — בַּטֶּלֶפוֹן שֶׁלָּכֶם, וְאָז הַשֵּׁם שֶׁל הַיֶּלֶד.")),
                .init(id: 2, title: tr("גּוֹלְלִים עַד לְמַטָּה ← \"יישומים עם גישה אל ”זמן מסך”\""), detail: ""),
                .init(id: 3, title: tr("טוֹפִי ← כִּבּוּי"), detail: tr("זֶה מְבַטֵּל אֶת כָּל הַנְּעִילוֹת בַּטֶּלֶפוֹן.")),
                .init(id: 4, title: tr("וְאָז מוֹחֲקִים אֶת טוֹפִי מִמָּסַךְ הַבַּיִת כָּרָגִיל"), detail: ""),
            ])
            ScreenTimeShowMeButton(pages: ScreenTimeLookalikes.deletion)
            openSettingsButton
        }
    }

    /// Disconnect THIS device from the child and reset to a just-installed state.
    /// (Parent-gated, like everything on this screen.) Cloud progress is kept.
    private var disconnectButton: some View {
        Button { Haptic.medium(); showDisconnect = true } label: {
            Label(tr("הִתְנַתְּקוּ מֵהַמִּשְׁפָּחָה"), systemImage: "iphone.slash")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.flameOrange)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .glassInset(radius: 14)
        }
        .buttonStyle(.juicy)
    }

    // MARK: - Actions

    /// 💝 Give minutes on the child's own device: straight into the synced gift
    /// pocket (this device IS the child, so no cloud command needed — the store
    /// change syncs up). Never opens a window — the child does that.
    private func gift(minutes: Int) {
        guard minutes > 0 else { return }
        controlsLog.notice("parent gift on-device: \(minutes, privacy: .public) min")
        progress.addParentGiftMinutes(minutes)
        dismiss()
    }

    private func lockNow() {
        shields.cancelScheduledReshield()
        // Save, don't burn — same semantics as the remote lock: an EARNED window
        // banks back to the wallet, a parent window freezes for later.
        progress.stopAndSaveCurrentUnlock()
        shields.relockBaseline()
        dismiss()
    }

    private func startAllow(minutes: Int) {
        Task {
            await shields.requestAuthorizationIfNeeded(userInitiated: true)
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
        shields.relockBaseline()
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
        .environment(\.layoutDirection, .app)
}
