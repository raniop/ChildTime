import SwiftUI

struct ParentGateView<Content: View>: View {
    /// What to show once unlocked. Defaults to Parent Settings (its original use),
    /// but the parent device also wraps the whole dashboard with it.
    private let content: () -> Content
    var allowClose: Bool = true
    /// Optional contextual title/reason — e.g. when gating a star purchase rather
    /// than opening Parent Settings. Falls back to the settings wording.
    var gateTitle: String? = nil
    var gateReason: String? = nil
    /// Allow biometric (Face ID) unlock.
    var useFaceID: Bool = true
    /// When true, this gate opens automatically if the parent already
    /// authenticated elsewhere this session (`settings.sessionUnlocked`) — used by
    /// the root dashboard so leaving Kid Mode needs only ONE Face ID. Gates that
    /// must always authenticate (like the Kid-Mode exit itself) pass false.
    var respectSession: Bool = true
    /// Fired the moment the gate is unlocked (any method). Lets a caller act on
    /// the single authentication — e.g. exit Kid Mode — without a second screen.
    var onAuthorized: (() -> Void)? = nil
    /// When false, this gate REFUSES to run first-time code creation: if no
    /// parent code exists on this device yet (e.g. the household code hasn't
    /// synced), it shows a "not available" notice instead of letting whoever
    /// holds the device invent a parent code. Pass false for privileged actions
    /// on a CHILD device (like resetting the kid's play-protection code) where
    /// "create a code right now" would be a bypass.
    var allowSetup: Bool = true

    init(allowClose: Bool = true,
         gateTitle: String? = nil,
         gateReason: String? = nil,
         useFaceID: Bool = true,
         respectSession: Bool = true,
         allowSetup: Bool = true,
         onAuthorized: (() -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content = {
             ParentSettingsView().environment(\.layoutDirection, .rightToLeft)
         }) {
        self.allowClose = allowClose
        self.gateTitle = gateTitle
        self.gateReason = gateReason
        self.useFaceID = useFaceID
        self.respectSession = respectSession
        self.allowSetup = allowSetup
        self.onAuthorized = onAuthorized
        self.content = content
    }

    @EnvironmentObject var settings: ParentSettings
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var loadingTimedOut = false
    @State private var loadingToken = UUID()
    @Environment(\.scenePhase) private var scenePhase
    @State private var entered: String = ""
    @State private var shake: Bool = false
    @State private var authorized: Bool = false
    /// First-time setup: the parent never picked a code on this device, so we
    /// let them CREATE one (enter → confirm) instead of guessing the default.
    @State private var setupFirst: String? = nil   // first entry while confirming

    // First-time setup only when NEITHER this device NOR the family has a code.
    // If the family already set one (e.g. on the parent's phone), this device
    // asks to ENTER it — not create a new one.
    private var isSetupMode: Bool { !settings.hasSetParentPIN && household.householdPIN == nil }

    // Signed-in device that hasn't finished loading the family yet (or has no
    // network — simulator errno 50 caught this live): we CANNOT yet tell "new
    // family, create a code" apart from "existing family, enter the code". The
    // setup keypad here let a returning parent mint a NEW code that would
    // overwrite the family's real one once the network came back. Wait instead.
    private var householdStillLoading: Bool {
        !settings.hasSetParentPIN && household.householdPIN == nil
            && household.household == nil && AuthManager.shared.isSignedIn
    }

    private var canUseFaceID: Bool {
        useFaceID && settings.faceIDForParentGate && PINManager.shared.biometryAvailable
            && !isSetupMode
    }

    var body: some View {
        Group {
            if authorized || (respectSession && settings.sessionUnlocked) {
                content()
            } else if householdStillLoading {
                familyLoadingGate
            } else if isSetupMode && !allowSetup {
                // No parent code exists on this device (yet) and this gate must
                // not offer to create one — that would let whoever HOLDS the
                // device mint a parent code and walk through.
                setupUnavailable
            } else {
                gate
            }
        }
        .onChangeCompat(of: scenePhase) { _, phase in
            // On a CHILD device, leaving the app must re-lock the parent gate
            // IMMEDIATELY — otherwise returning lands straight back in the unlocked
            // controls and the child could reach the settings. (sessionUnlocked is
            // already reset on background; we must also drop the local `authorized`
            // flag, which otherwise keeps the content showing.) The parent's own
            // device keeps its session so the parent isn't re-prompted constantly.
            if phase == .background, settings.deviceRole == .child {
                authorized = false
            }
        }
    }

    /// Shown while the family is still streaming down: neither the setup keypad
    /// (could mint a code over the family's real one) nor the entry keypad
    /// (nothing to verify against yet) is safe to show.
    private var familyLoadingGate: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            VStack(spacing: AppSpacing.md) {
                if loadingTimedOut {
                    // Rani: after a while this must SAY what is wrong, not spin.
                    Text("📡").font(.system(size: 44))
                    Text("הַמַּכְשִׁיר לֹא הִצְלִיחַ לְהִתְחַבֵּר לַמִּשְׁפָּחָה")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                        .multilineTextAlignment(.center)
                    Text("בִּדְקוּ שֶׁיֵּשׁ אִינְטֶרְנֶט, וְשֶׁהַמַּכְשִׁיר עֲדַיִן מְקֻשָּׁר לַמִּשְׁפָּחָה בְּלוּחַ הַהוֹרִים.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Haptic.light()
                        loadingTimedOut = false
                        household.refreshHouseholdNow()
                        armLoadingTimeout()
                    } label: {
                        Text("נַסּוּ שׁוּב")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "4B3FBF"))
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.92)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else {
                    ProgressView().scaleEffect(1.4).tint(.white)
                    Text("טוֹעֲנִים אֶת הַמִּשְׁפָּחָה שֶׁלָּכֶם…")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                    Text("רֶגַע אֶחָד…")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 360)
            .glassPane(radius: 24)
            .animation(.easeInOut(duration: 0.25), value: loadingTimedOut)
            // Never a dead end: the child (or parent) can always back out while
            // the family is still streaming down (Rani hit this in the shop).
            if allowClose {
                VStack {
                    HStack {
                        Spacer()
                        Button { Haptic.light(); dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.22), in: Circle()).overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                                .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(AppSpacing.md)
                    }
                    Spacer()
                }
            }
        }
        .onAppear { household.refreshHouseholdNow(); armLoadingTimeout() }
    }

    /// Ten seconds of spinner, then an honest message with a retry.
    private func armLoadingTimeout() {
        let token = UUID()
        loadingToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if loadingToken == token && householdStillLoading { loadingTimedOut = true }
        }
    }

    /// Shown instead of the keypad when `allowSetup == false` and no parent code
    /// is available on this device: explain + gentle exit, never a create-flow.
    private var setupUnavailable: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "lock.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColor.starGold)
                Text("קוֹד הַהוֹרֶה לֹא זָמִין כָּאן")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("קוֹד הַהוֹרֶה שֶׁל הַמִּשְׁפָּחָה עֲדַיִן לֹא הִגִּיעַ לַמַּכְשִׁיר הַזֶּה (בִּדְקוּ חִבּוּר לָאִינְטֶרְנֶט). אֶפְשָׁר תָּמִיד לְאַפֵּס מִלּוּחַ הַהוֹרִים בַּמַּכְשִׁיר שֶׁל אַבָּא אוֹ אִמָּא.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                if allowClose {
                    Button {
                        dismiss()
                    } label: {
                        Text("סְגִירָה")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 34).padding(.vertical, 13)
                            .background(Capsule().fill(.white.opacity(0.14))).overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.juicy)
                }
            }
            .padding(.top, 30)
        }
    }

    private var gate: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            VStack(spacing: 0) {
                HStack {
                    if allowClose {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.22), in: Circle()).overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                        }
                    } else if isSetupMode {
                        // Root gate during FIRST-TIME setup (no parent code exists
                        // yet, anywhere in the family) — "parent" may have been
                        // tapped by mistake, so allow going back to the role picker.
                        // Once a code exists this never shows: the everyday unlock
                        // gate must not offer a way around it.
                        Button {
                            Haptic.light()
                            settings.deviceRole = .unset
                        } label: {
                            Label("חֲזָרָה", systemImage: "chevron.backward")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(.white.opacity(0.14))).overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        }
                    }
                    Spacer()
                }

                // Header block — pulled toward the top so nothing floats in a
                // big empty middle.
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                    Text(isSetupMode ? "בְּחֲרוּ קוֹד הוֹרֶה" : (gateTitle ?? "הַגְדָּרוֹת הוֹרֶה"))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text(gateSubtitle)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 18) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .stroke(.white.opacity(0.7), lineWidth: 2)
                                .background(
                                    Circle().fill(i < entered.count ? Color.white : Color.clear)
                                )
                                .frame(width: 26, height: 26)
                        }
                    }
                    .padding(.top, 4)
                    .offset(x: shake ? -10 : 0)
                    .animation(shake ? .default.repeatCount(3, autoreverses: true).speed(6) : .default, value: shake)

                    if canUseFaceID {
                        Button {
                            Task { await tryBiometric() }
                        } label: {
                            Label("פִּתְחוּ עִם Face ID", systemImage: "faceid")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.white.opacity(0.14))).overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.top, 28)

                // Fixed gap (not flexible) so the header + keypad stay grouped
                // near the top instead of drifting to the vertical center.
                Color.clear.frame(height: 32)

                keypad

                // All remaining slack collects at the bottom — everything rides
                // high on the screen.
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .onAppear {
            // Pull the freshest family code so a just-changed parent code works here
            // immediately (and the old one stops) even if the live listener lagged.
            household.refreshHouseholdNow()
            if canUseFaceID { Task { await tryBiometric() } }
        }
    }

    private func tryBiometric() async {
        if await PINManager.shared.authenticateBiometric() {
            grantAccess()
        }
    }

    /// Unlock the gate (any method): remember it for the session, flip the local
    /// state, and notify the caller so a single auth can also drive an action.
    private func grantAccess() {
        // On a CHILD's device, the parent isn't usually present — so any unlock of
        // the parent gate (code or Face ID) pings the household's parents, so they
        // know someone opened the parent controls on the kid's device.
        if settings.deviceRole == .child {
            LiveEventReporter.report(.parentGateOpened)
        }
        // Persist the session unlock ONLY where the parent holds the device.
        // On a child device (or the parent's phone in Kid Mode) the kid holds
        // it — a lingering unlock would let them re-open any session-respecting
        // gate after the parent used it once.
        if settings.deviceRole != .child && !KidModeManager.shared.active {
            settings.sessionUnlocked = true
        }
        authorized = true
        onAuthorized?()
    }

    private var keypad: some View {
        let layout: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "⌫"]
        ]
        return VStack(spacing: 18) {
            ForEach(layout, id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func keyButton(_ key: String) -> some View {
        Group {
            if key.isEmpty {
                Color.clear.frame(width: 76, height: 76)
            } else {
                Button {
                    handleKey(key)
                } label: {
                    Group {
                        if key == "⌫" {
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 26, weight: .medium))
                        } else {
                            Text(key)
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.22), in: Circle()).overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleKey(_ key: String) {
        if key == "⌫" {
            if !entered.isEmpty { entered.removeLast() }
            return
        }
        guard entered.count < 4 else { return }
        entered.append(key)
        if entered.count == 4 {
            verify()
        }
    }

    private var gateSubtitle: String {
        if isSetupMode {
            return setupFirst == nil
                ? "בִּחֲרוּ קוֹד בֶּן 4 סְפָרוֹת לְהָגֵן עַל הַהַגְדָּרוֹת"
                : "הַזִּינוּ שׁוּב אֶת הַקּוֹד לְאִשּׁוּר"
        }
        if let reason = gateReason { return reason }
        // A co-parent's FIRST entry on this device: the family code exists in
        // the cloud but was never typed here — and nobody told them a code
        // exists. Point them at the person who knows it (Rani).
        if !settings.hasSetParentPIN, household.householdPIN != nil {
            return "זֶהוּ קוֹד הַהוֹרֶה הַמִּשְׁפַּחְתִּי · בַּקְּשׁוּ אוֹתוֹ מֵהַהוֹרֶה שֶׁהִזְמִין אֶתְכֶם"
        }
        return "הַזִּינוּ קוֹד בֶּן 4 סְפָרוֹת"
    }

    private func verify() {
        if isSetupMode {
            if let first = setupFirst {
                // Confirming the new code.
                if entered == first {
                    PINManager.shared.setPIN(entered)
                    settings.hasSetParentPIN = true
                    // Share it family-wide so other devices use the same code.
                    household.setHouseholdPIN(PINManager.shared.makeBlob(entered))
                    Haptic.success()
                    // First-time setup: immediately offer Face ID / Touch ID so the
                    // parent turns on fast unlock right here, instead of having to find
                    // the toggle in settings later. Enable it only if they approve the
                    // system prompt; if they cancel, it stays off (and they still get in).
                    Task { @MainActor in
                        if PINManager.shared.biometryAvailable {
                            let ok = await PINManager.shared.authenticateBiometric(
                                reason: "הַפְעִילוּ פְּתִיחָה מְהִירָה עִם Face ID")
                            if ok { settings.faceIDForParentGate = true }
                        }
                        grantAccess()
                    }
                } else {
                    shake = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        shake = false; entered = ""; setupFirst = nil
                    }
                }
            } else {
                // First entry → ask to confirm.
                setupFirst = entered
                entered = ""
            }
            return
        }
        let family = household.householdPIN
        let okLocal = PINManager.shared.verify(entered)
        let okFamily = family.map { PINManager.shared.verify(entered, against: $0) } ?? false
        // The family code is AUTHORITATIVE whenever the household has one: changing
        // the parent code on one device must invalidate the OLD code on every other
        // device once it has synced here. We only fall back to the device-local code
        // when there is NO family code yet (offline first run / pre-feature setup) —
        // otherwise a stale cached PIN would keep working forever after a change.
        let accepted = family != nil ? okFamily : okLocal
        if accepted {
            // First successful ENTRY of the code on this device (e.g. a second
            // parent device that received the family code) → offer Face ID right
            // now, exactly like first-time creation does. Otherwise the parent
            // only discovers the toggle later in Settings. Decide BEFORE we flip
            // hasSetParentPIN, and only on a PARENT device (a kid's device must
            // never enroll biometrics for the parent gate).
            let firstEntryHere = !settings.hasSetParentPIN
                && settings.deviceRole == .parent
                && !settings.faceIDForParentGate
                && PINManager.shared.biometryAvailable
            // Cache locally so next time (and Face ID) work on this device — and so
            // a refreshed family code overwrites any stale local one.
            if !okLocal { PINManager.shared.setPIN(entered) }
            settings.hasSetParentPIN = true
            // Backfill the family code if it isn't shared yet (e.g. a parent who
            // set a PIN before this feature) so other devices use the same one.
            if household.householdPIN == nil, let blob = PINManager.shared.storedBlob {
                household.setHouseholdPIN(blob)
            }
            if firstEntryHere {
                Haptic.success()
                Task { @MainActor in
                    let ok = await PINManager.shared.authenticateBiometric(
                        reason: "הַפְעִילוּ פְּתִיחָה מְהִירָה עִם Face ID")
                    if ok { settings.faceIDForParentGate = true }
                    grantAccess()   // in either case — the code was right
                }
            } else {
                grantAccess()
            }
        } else {
            shake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                shake = false
                entered = ""
            }
        }
    }
}

#Preview {
    ParentGateView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ShieldManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
