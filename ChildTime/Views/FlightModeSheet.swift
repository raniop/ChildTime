import SwiftUI

/// ✈️ The parent's side of `FlightMode`: pick the day you're back, get a code,
/// send it to the child (or to whoever stays with them). One window — the
/// date, the code, and the three things to do with it.
struct FlightModeSheet: View {
    let profile: Profile

    @EnvironmentObject private var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var backAt: Date = FlightModeSheet.defaultReturn
    @State private var editingDate = false
    @State private var saving = false
    @State private var status: String?

    private var name: String { Question.stripNiqqud(profile.name) }
    private var girl: Bool { profile.gender == .girl }
    /// The live copy — it changes under us when the save lands.
    private var mode: FlightMode? {
        (profiles.profiles.first { $0.id == profile.id } ?? profile).flightMode.flatMap { $0.isActive ? $0 : nil }
    }

    /// A week from now, at eight in the evening.
    static var defaultReturn: Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return cal.date(bySettingHour: 20, minute: 0, second: 0, of: day) ?? day
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let mode, !editingDate {
                    codeCard(mode)
                    actions(mode)
                } else {
                    datePane
                    goldButton(mode == nil ? tr("יצירת קוד") : tr("שמירת התאריך")) { save(keepCode: mode?.code) }
                    if mode != nil {
                        plainButton(tr("ביטול")) { editingDate = false }
                    }
                }
                if let status {
                    Text(status)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .foregroundStyle(GlassInk.primary)
        }
        .background(GlassBackdrop().ignoresSafeArea())
        .environment(\.layoutDirection, .app)
        .onAppear { if let mode { backAt = mode.untilDate } }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("✈️").font(.system(size: 34))
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("מצב טיסה"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                Text(girl ? tr("טסים? \(name) תקבל קוד שפותח את המכשיר שלה לבד, לכמה זמן שתבחר, עד שתחזרו. גם בלי אינטרנט. שעת השינה ממשיכה לעבוד.")
                          : tr("טסים? \(name) יקבל קוד שפותח את המכשיר שלו לבד, לכמה זמן שיבחר, עד שתחזרו. גם בלי אינטרנט. שעת השינה ממשיכה לעבוד."))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.2), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("סגירה"))
        }
    }

    private var datePane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("חוזרים ב־"))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            DatePicker("", selection: $backAt, in: Date().addingTimeInterval(3600)...,
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: LanguageStore.shared.current.rawValue))
            Text(tr("עד אז הקוד עובד. אחר כך הוא מפסיק לבד וטופי חוזר לחוקים הרגילים."))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPane(radius: 16)
    }

    private func codeCard(_ mode: FlightMode) -> some View {
        VStack(spacing: 8) {
            Text(tr("הקוד של \(name)"))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
            // Digits read left to right, like every number.
            HStack(spacing: 10) {
                ForEach(Array(mode.code), id: \.self) { d in
                    Text(String(d))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .frame(width: 56, height: 68)
                        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            Text(tr("עובד עד \(Self.dateLine(mode.untilDate))"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassPane(radius: 16)
    }

    private func actions(_ mode: FlightMode) -> some View {
        VStack(spacing: 10) {
            ShareLink(item: shareText(mode)) {
                Text(tr("שליחת הקוד"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "3A2700"))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            plainButton(tr("שינוי תאריך החזרה")) { backAt = mode.untilDate; editingDate = true }
            plainButton(tr("קוד חדש")) { backAt = mode.untilDate; save(keepCode: nil) }
            plainButton(tr("סיום מצב טיסה"), destructive: true) { end() }
        }
    }

    private func goldButton(_ title: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Group {
                if saving { ProgressView().tint(Color(hex: "3A2700")) }
                else { Text(title).font(.system(size: 17, weight: .heavy, design: .rounded)) }
            }
            .foregroundStyle(Color(hex: "3A2700"))
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(saving)
    }

    private func plainButton(_ title: String, destructive: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(destructive ? Color(hex: "FFB4B4") : GlassInk.primary)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(saving)
    }

    // MARK: - Saving

    private func save(keepCode: String?) {
        guard !HouseholdManager.shared.refuseIfDisconnected() else { return }
        let mode = FlightMode(code: keepCode ?? FlightMode.newCode(),
                              until: backAt.timeIntervalSince1970,
                              setAt: Date().timeIntervalSince1970)
        saving = true
        Task { @MainActor in
            let outcome = await FlightModeStore.save(mode, for: profile.id)
            saving = false
            editingDate = false
            status = Self.statusLine(outcome, name: name, girl: girl)
            Haptic.success()
        }
    }

    private func end() {
        saving = true
        Task { @MainActor in
            let outcome = await FlightModeStore.save(nil, for: profile.id)
            saving = false
            status = outcome == .ok || outcome == .queued ? tr("מצב טיסה הסתיים. הקוד כבר לא עובד.") : Self.statusLine(outcome, name: name, girl: girl)
        }
    }

    static func statusLine(_ outcome: ConfirmedWriteOutcome, name: String, girl: Bool) -> String {
        switch outcome {
        case .ok:     return tr("✅ נשמר. הקוד יגיע למכשיר של \(name).")
        case .queued: return tr("⏳ אין כרגע אינטרנט. יישלח ברגע שיחזור.")
        case .denied, .error: return tr("⚠️ לא נשמר. נסו שוב.")
        }
    }

    private func shareText(_ mode: FlightMode) -> String {
        tr("✈️ הקוד של \(name) בטופי: \(mode.code)\nפותח את המכשיר עד \(Self.dateLine(mode.untilDate)).")
    }

    static func dateLine(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: LanguageStore.shared.current.rawValue)
        f.setLocalizedDateFormatFromTemplate("EEEE d.M")
        let t = DateFormatter()
        t.locale = f.locale
        t.setLocalizedDateFormatFromTemplate("HH:mm")
        return f.string(from: d) + " · " + t.string(from: d)
    }
}
