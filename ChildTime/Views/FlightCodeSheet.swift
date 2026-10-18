import SwiftUI
import Combine

/// ✈️ The child's side of `FlightMode`: type the code the parents left, then
/// pick how long to open. Checked on the device itself, so it works with no
/// internet. Five wrong tries → a minute's wait (never a scolding).
struct FlightCodeSheet: View {
    let mode: FlightMode
    let quietHours: QuietHours?
    /// Chosen minutes — the map opens the window.
    let onOpen: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var unlocked = ProcessInfo.processInfo.environment["DEMO_FLIGHT_STEP"] == "2"   // screenshots
    @State private var wrong = 0
    @State private var hint: String?
    @State private var wait = FlightModeStore.waitSeconds
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("סְגִירָה"))
            }
            Text("✈️").font(.system(size: 54))
            if unlocked { durations } else { codePad }
            Spacer(minLength: 0)
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(GlassBackdrop().ignoresSafeArea())
        .environment(\.layoutDirection, .app)
        .onReceive(tick) { _ in wait = FlightModeStore.waitSeconds }
    }

    // MARK: - The code

    private var codePad: some View {
        VStack(spacing: 16) {
            Text(tr("הַקְלִידוּ אֶת קוֹד הַטִּיסָה"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            // Four boxes, left to right like every number.
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    Text(i < typed.count ? String(Array(typed)[i]) : "")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .frame(width: 58, height: 68)
                        .background(Color.white.opacity(i < typed.count ? 0.26 : 0.12),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .modifier(MiniGameShake(animatableData: CGFloat(wrong)))
            .animation(.easeInOut(duration: 0.4), value: wrong)

            Text(wait > 0 ? tr("חַכּוּ רֶגַע וּנְנַסֶּה שׁוּב ⏳ \(wait)") : (hint ?? " "))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.starGold)
                .multilineTextAlignment(.center)
                .frame(minHeight: 22)

            keypad
        }
    }

    private var keypad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 76, height: 60)
                        } else {
                            Button { press(key) } label: {
                                Text(key)
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .frame(width: 76, height: 60)
                                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.juicy)
                            .disabled(wait > 0)
                            .accessibilityLabel(key == "⌫" ? tr("מְחִיקָה") : key)
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .opacity(wait > 0 ? 0.5 : 1)
    }

    private func press(_ key: String) {
        Haptic.light()
        hint = nil
        if key == "⌫" { if !typed.isEmpty { typed.removeLast() }; return }
        guard typed.count < 4 else { return }
        typed.append(key)
        guard typed.count == 4 else { return }
        if FlightModeStore.check(typed, against: mode) {
            Haptic.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { unlocked = true }
        } else {
            wrong += 1
            Haptic.warning()
            hint = tr("הַקּוֹד לֹא נָכוֹן. נְנַסֶּה שׁוּב 🙂")
            typed = ""
            wait = FlightModeStore.waitSeconds
        }
    }

    // MARK: - How long

    private var durations: some View {
        VStack(spacing: 12) {
            Text(tr("לְכַמָּה זְמַן לִפְתֹּחַ?"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            ForEach(choices, id: \.minutes) { c in
                Button {
                    Haptic.success()
                    dismiss()
                    onOpen(c.minutes)
                } label: {
                    Text(c.label)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(c.bedtime ? Color(hex: "3A2700") : .white)
                        .frame(maxWidth: 340).frame(height: 58)
                        .background(c.bedtime ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.16)),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.juicy)
            }
        }
    }

    private struct Choice { let minutes: Int; let label: String; var bedtime = false }

    /// 15 · 30 · an hour · two hours · three hours, plus "until bedtime" when
    /// one is set for tonight. Never past the day the parents are back.
    private var choices: [Choice] {
        let left = max(1, Int((mode.until - Date().timeIntervalSince1970) / 60))
        var list: [Choice] = [
            Choice(minutes: 15, label: tr("15 דַּקּוֹת")),
            Choice(minutes: 30, label: tr("חֲצִי שָׁעָה")),
            Choice(minutes: 60, label: tr("שָׁעָה")),
            Choice(minutes: 120, label: tr("שְׁעָתַיִם")),
            Choice(minutes: 180, label: tr("שָׁלוֹשׁ שָׁעוֹת")),
        ].filter { $0.minutes <= left }
        if let m = minutesUntilBedtime(), m >= 20, m <= left {
            list.append(Choice(minutes: m, label: tr("עַד שְׁעַת הַשֵּׁנָה 🌙"), bedtime: true))
        }
        if list.isEmpty { list = [Choice(minutes: left, label: tr("\(left) דַּקּוֹת"))] }
        return list
    }

    /// Minutes from now to tonight's bedtime, if one is set for today.
    private func minutesUntilBedtime(now: Date = Date()) -> Int? {
        guard let b = quietHours?.bedtime, b.enabled else { return nil }
        let cal = Calendar.current
        guard b.days.contains(cal.component(.weekday, from: now)) else { return nil }
        let sinceMidnight = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let m = b.start - sinceMidnight
        return m > 0 ? m : nil
    }
}
