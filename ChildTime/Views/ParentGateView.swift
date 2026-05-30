import SwiftUI

struct ParentGateView<Content: View>: View {
    /// What to show once unlocked. Defaults to Parent Settings (its original use),
    /// but the parent device also wraps the whole dashboard with it.
    private let content: () -> Content
    var allowClose: Bool = true

    init(allowClose: Bool = true,
         @ViewBuilder content: @escaping () -> Content = {
             ParentSettingsView().environment(\.layoutDirection, .rightToLeft)
         }) {
        self.allowClose = allowClose
        self.content = content
    }

    @EnvironmentObject var settings: ParentSettings
    @Environment(\.dismiss) private var dismiss
    @State private var entered: String = ""
    @State private var shake: Bool = false
    @State private var authorized: Bool = false
    /// First-time setup: the parent never picked a code on this device, so we
    /// let them CREATE one (enter → confirm) instead of guessing the default.
    @State private var setupFirst: String? = nil   // first entry while confirming

    private var isSetupMode: Bool { !settings.hasSetParentPIN }

    private var canUseFaceID: Bool {
        settings.faceIDForParentGate && PINManager.shared.biometryAvailable
            && !isSetupMode
    }

    var body: some View {
        if authorized {
            content()
        } else {
            gate
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

                    Text(isSetupMode ? "בְּחֲרוּ קוֹד הוֹרֶה" : "הַגְדָּרוֹת הוֹרֶה")
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
            if canUseFaceID { Task { await tryBiometric() } }
        }
    }

    private func tryBiometric() async {
        if await PINManager.shared.authenticateBiometric() {
            authorized = true
        }
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
        return "הַזִּינוּ קוֹד בֶּן 4 סְפָרוֹת"
    }

    private func verify() {
        if isSetupMode {
            if let first = setupFirst {
                // Confirming the new code.
                if entered == first {
                    PINManager.shared.setPIN(entered)
                    settings.hasSetParentPIN = true
                    Haptic.success()
                    authorized = true
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
        if PINManager.shared.verify(entered) {
            authorized = true
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
