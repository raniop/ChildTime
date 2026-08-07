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

    init(allowClose: Bool = true,
         gateTitle: String? = nil,
         gateReason: String? = nil,
         useFaceID: Bool = true,
         respectSession: Bool = true,
         onAuthorized: (() -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content = {
             ParentSettingsView().environment(\.layoutDirection, .rightToLeft)
         }) {
        self.allowClose = allowClose
        self.gateTitle = gateTitle
        self.gateReason = gateReason
        self.useFaceID = useFaceID
        self.respectSession = respectSession
        self.onAuthorized = onAuthorized
        self.content = content
    }

    @EnvironmentObject var settings: ParentSettings
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss
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

    private var canUseFaceID: Bool {
        useFaceID && settings.faceIDForParentGate && PINManager.shared.biometryAvailable
            && !isSetupMode
    }

    var body: some View {
        Group {
            if authorized || (respectSession && settings.sessionUnlocked) {
                content()
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

    private var gate: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 18, size: 12)

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
                                .background(.white.opacity(0.15), in: Circle())
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
                                .background(.white.opacity(0.16), in: Capsule())
                        }
                    }
                    Spacer()
                }

                // Header block — pulled toward the top so nothing floats in a
                // big empty middle.
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppColor.starGold)
                        .glow(AppColor.starGold, radius: 14)

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
                                    Circle().fill(i < entered.count ? AppColor.starGold : Color.clear)
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
                                .background(.white.opacity(0.15), in: Capsule())
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
        settings.sessionUnlocked = true
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
                    .background(.white.opacity(0.15), in: Circle())
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
            // Cache locally so next time (and Face ID) work on this device — and so
            // a refreshed family code overwrites any stale local one.
            if !okLocal { PINManager.shared.setPIN(entered) }
            settings.hasSetParentPIN = true
            // Backfill the family code if it isn't shared yet (e.g. a parent who
            // set a PIN before this feature) so other devices use the same one.
            if household.householdPIN == nil, let blob = PINManager.shared.storedBlob {
                household.setHouseholdPIN(blob)
            }
            grantAccess()
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
