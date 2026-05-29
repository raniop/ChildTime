import SwiftUI

struct ParentGateView: View {
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.dismiss) private var dismiss
    @State private var entered: String = ""
    @State private var shake: Bool = false
    @State private var authorized: Bool = false

    private var canUseFaceID: Bool {
        settings.faceIDForParentGate && PINManager.shared.biometryAvailable
    }

    var body: some View {
        if authorized {
            ParentSettingsView()
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            gate
        }
    }

    private var gate: some View {
        VStack(spacing: 32) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
                Spacer()
            }
            .padding(.horizontal, 8)

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("הגדרות הורה")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("הזן קוד 4 ספרות")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .stroke(Color.secondary, lineWidth: 2)
                        .background(
                            Circle().fill(i < entered.count ? Color.blue : Color.clear)
                        )
                        .frame(width: 28, height: 28)
                }
            }
            .offset(x: shake ? -10 : 0)
            .animation(shake ? .default.repeatCount(3, autoreverses: true).speed(6) : .default, value: shake)

            if canUseFaceID {
                Button {
                    Task { await tryBiometric() }
                } label: {
                    Label("פתח עם Face ID", systemImage: "faceid")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.blue)
                }
                .padding(.top, 4)
            }

            Spacer()

            keypad
                .padding(.bottom, 24)
        }
        .padding()
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
        return VStack(spacing: 16) {
            ForEach(layout, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func keyButton(_ key: String) -> some View {
        Group {
            if key.isEmpty {
                Color.clear.frame(width: 80, height: 80)
            } else {
                Button {
                    handleKey(key)
                } label: {
                    Text(key)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }
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

    private func verify() {
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
