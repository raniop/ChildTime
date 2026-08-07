import SwiftUI

/// The child's OWN "protect my time" code screen — NOT the parent gate.
///
/// Shown on the child's device to (a) verify the code before spending earned
/// play minutes, and (b) set / change / remove the code. The tone is a kid
/// guarding their treasure, not a lock keeping them out: big friendly keypad,
/// gentle "almost!" on a wrong code (never failure language), no lockouts.
struct KidPINView: View {
    enum Mode: Equatable {
        /// Ask for the existing code; success runs the pending action.
        case verify(title: String)
        /// Choose a new code (enter → confirm). Used for first setup and,
        /// after an inline verify, for changing it.
        case setNew
    }

    let profile: Profile
    let mode: Mode
    var onSuccess: (String) -> Void      // verified pin / newly chosen pin
    var onCancel: () -> Void
    /// Verify mode only: "I forgot my code" — routes to the forgot screen
    /// (parent notification + parent-code reset). nil hides the button.
    var onForgot: (() -> Void)? = nil

    @State private var entered = ""
    @State private var firstEntry: String?   // set-mode: the code awaiting confirm
    @State private var shake = false
    @State private var almost = false        // gentle wrong-code feedback

    private var isSetMode: Bool { mode == .setNew }

    private var title: String {
        switch mode {
        case .verify(let t): return t
        case .setNew: return firstEntry == nil ? "בַּחֲרוּ קוֹד סוֹדִי" : "עוֹד פַּעַם, לִבְדִיקָה"
        }
    }

    private var subtitle: String {
        switch mode {
        case .verify:
            return almost ? "כִּמְעַט! נַסּוּ שׁוּב 💪" : "הַזְמַן הַזֶּה שֶׁלְּךָ — רַק אַתָּה פּוֹתֵחַ אוֹתוֹ"
        case .setNew:
            if almost { return "הַקּוֹדִים לֹא הָיוּ אוֹתוֹ דָּבָר — בּוֹאוּ נְנַסֶּה שׁוּב 🙂" }
            return firstEntry == nil
                ? "4 סְפָרוֹת שֶׁרַק אַתָּה תֵּדַע — לֹא אַחִים וְלֹא חֲבֵרִים 😉"
                : "מַקְלִידִים אֶת אוֹתוֹ קוֹד שׁוּב"
        }
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 14, size: 12)

            VStack(spacing: 0) {
                HStack {
                    Button {
                        Haptic.light()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                VStack(spacing: 14) {
                    Text("🔒")
                        .font(.system(size: 54))
                        .glow(AppColor.starGold, radius: 12)

                    Text(title)
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .animation(.easeInOut(duration: 0.2), value: subtitle)

                    HStack(spacing: 18) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .stroke(.white.opacity(0.7), lineWidth: 2)
                                .background(Circle().fill(i < entered.count ? AppColor.starGold : Color.clear))
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding(.top, 2)
                    .offset(x: shake ? -10 : 0)
                    .animation(shake ? .default.repeatCount(3, autoreverses: true).speed(6) : .default, value: shake)
                }
                .padding(.top, 10)

                Color.clear.frame(height: 26)
                keypad

                if !isSetMode, let onForgot {
                    Button {
                        Haptic.light()
                        onForgot()
                    } label: {
                        Text("שָׁכַחְתִּי אֶת הַקּוֹד 🤔")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    private var keypad: some View {
        let layout: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        // A number pad reads 1-2-3 left-to-right even in Hebrew (like the iOS
        // passcode screen) — pin the direction so RTL doesn't mirror the rows.
        return VStack(spacing: 14) {
            ForEach(layout, id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 76, height: 76)
                        } else {
                            Button { press(key) } label: {
                                Text(key)
                                    .font(.system(size: key == "⌫" ? 26 : 32, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 76, height: 76)
                                    .background(.white.opacity(0.14), in: Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                            }
                            .buttonStyle(.juicy)
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func press(_ key: String) {
        almost = false
        if key == "⌫" {
            if !entered.isEmpty { entered.removeLast() }
            Haptic.light()
            return
        }
        guard entered.count < 4 else { return }
        Haptic.light()
        entered += key
        guard entered.count == 4 else { return }
        // Full code typed — act by mode.
        switch mode {
        case .verify:
            if profile.verifyPlayPIN(entered) {
                Haptic.success()
                onSuccess(entered)
            } else {
                gentleRetry()
            }
        case .setNew:
            if let first = firstEntry {
                if entered == first {
                    Haptic.success()
                    onSuccess(entered)
                } else {
                    firstEntry = nil
                    gentleRetry()
                }
            } else {
                firstEntry = entered
                entered = ""
            }
        }
    }

    /// Wrong code / mismatched confirm → a soft shake and an "almost!" line.
    /// Never scary, never locking the kid out — mistakes are recoverable.
    private func gentleRetry() {
        shake = true
        almost = true
        Haptic.soft()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            shake = false
            entered = ""
        }
    }
}

/// "I forgot my code" — kid-safe dead end that ISN'T a dead end:
/// 1. On appear it pings the parents (push via LiveEventReporter), so a remote
///    parent knows to look the code up / reset from the dashboard.
/// 2. A parent standing next to the kid can reset ON THE SPOT behind the
///    parent gate (respectSession:false — always re-authenticates, so a kid
///    can never ride an old unlock).
/// The kid alone still has no way through — that's the whole protection.
struct PlayPINForgotView: View {
    let childName: String
    var onParentReset: () -> Void
    var onClose: () -> Void

    @EnvironmentObject var settings: ParentSettings
    @State private var showParentGate = false
    @State private var notified = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 12, size: 12)

            VStack(spacing: AppSpacing.lg) {
                Text("💌")
                    .font(.system(size: 54))
                    .glow(AppColor.companionGlow, radius: 12)

                Text("זֶה בְּסֵדֶר, קוֹרֶה לְכֻלָּם!")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("שָׁלַחְנוּ עַכְשָׁיו הוֹדָעָה לְאַבָּא וּלְאִמָּא 💌\nהֵם רוֹאִים אֶת הַקּוֹד שֶׁלְּךָ בַּלּוּחַ שֶׁלָּהֶם,\nוְיוֹדְעִים אֵיךְ לַעֲזוֹר.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                VStack(spacing: 12) {
                    // For a parent standing right here.
                    Button {
                        Haptic.light()
                        showParentGate = true
                    } label: {
                        Label("אֲנִי הוֹרֶה · אִפּוּס עִם קוֹד הוֹרֶה", systemImage: "key.fill")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .glow(AppColor.starGold, radius: 10)
                    }
                    .buttonStyle(.juicy)

                    Button {
                        Haptic.light(); onClose()
                    } label: {
                        Text("סְגִירָה")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 340)
                .padding(.horizontal, AppSpacing.lg)
            }
        }
        .onAppear {
            // Ping the parents ONCE per appearance of this screen.
            guard !notified else { return }
            notified = true
            LiveEventReporter.report(.playPINForgot)
        }
        // The parent-code gate; success clears the child's code immediately.
        .sheet(isPresented: $showParentGate) {
            ParentGateView(allowClose: true,
                           gateTitle: "אִפּוּס קוֹד הֲגַנַּת הַזְּמַן",
                           gateReason: "הַזִּינוּ קוֹד הוֹרֶה כְּדֵי לְאַפֵּס אֶת הַקּוֹד שֶׁל \(childName)",
                           useFaceID: true,
                           respectSession: false,
                           // NEVER offer to CREATE a parent code here — a kid
                           // holding the device could mint one and self-reset.
                           allowSetup: false,
                           onAuthorized: {
                               showParentGate = false
                               onParentReset()
                           }) {
                Color.clear
            }
            .environmentObject(settings)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

/// Tiny chooser shown when a code already exists: change it or remove it.
/// Both routes re-verify the current code first (see WorldMapView.playPINCover).
struct PlayPINManageView: View {
    var onChange: () -> Void
    var onRemove: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 12, size: 12)

            VStack(spacing: AppSpacing.lg) {
                Text("🔒")
                    .font(.system(size: 54))
                    .glow(AppColor.starGold, radius: 12)
                Text("הַזְּמַן שֶׁלְּךָ מוּגָן")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("רַק מִי שֶׁיּוֹדֵעַ אֶת הַקּוֹד יָכוֹל לִפְתּוֹחַ אֶת דַּקּוֹת הַמִּשְׂחָק שֶׁלְּךָ.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                VStack(spacing: 12) {
                    Button {
                        Haptic.light(); onChange()
                    } label: {
                        Label("הַחְלָפַת הַקּוֹד", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .glow(AppColor.starGold, radius: 10)
                    }
                    .buttonStyle(.juicy)

                    Button {
                        Haptic.light(); onRemove()
                    } label: {
                        Label("הֲסָרַת הַקּוֹד", systemImage: "lock.open")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.juicy)

                    Button {
                        Haptic.light(); onClose()
                    } label: {
                        Text("סְגִירָה")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 340)
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }
}

#Preview {
    KidPINView(profile: Profile(name: "דנה"), mode: .setNew, onSuccess: { _ in }, onCancel: {})
        .environment(\.layoutDirection, .rightToLeft)
}
