import SwiftUI

/// 🏫 School time / 🌙 bedtime for one child, from the parent's settings.
/// The child's device applies it on the next sync (see `QuietHoursManager`).
struct QuietHoursEditorView: View {
    @ObservedObject private var railHost = DisplayGeometry.shared
    @EnvironmentObject private var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID
    let kind: QuietKind

    @State private var window = QuietHours.schoolDefault
    @State private var offToday = false
    @State private var paused = false
    @State private var shortFriday = true
    @State private var loaded = false

    private var profile: Profile? { profiles.profiles.first { $0.id == profileID } }
    private var isSchool: Bool { kind == .school }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $window.enabled) {
                        Text(isSchool ? tr("זמן בית ספר פעיל") : tr("שעת שינה פעילה"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .tint(AppColor.successMint)
                } footer: {
                    Text(tr("בשעות האלה אי אפשר לפתוח דקות משחק. טופי והאפליקציות שתמיד פתוחות נשארים פתוחים, ואפשר להמשיך לענות ולצבור דקות לאחר כך. פתיחה ידנית שלכם תמיד עובדת."))
                }
                .glassRows()

                if window.enabled {
                    Section {
                        dayChips
                    } header: {
                        Text(tr("ימים"))
                    }
                    .glassRows()

                    Section {
                        timeRow(tr("שעת התחלה"), minutes: $window.start)
                        timeRow(tr("שעת סיום"), minutes: $window.end)
                        if isSchool {
                            Toggle(tr("ביום שישי מסיימים מוקדם"), isOn: $shortFriday)
                                .tint(AppColor.successMint)
                            if shortFriday {
                                timeRow(tr("סיום ביום שישי"), minutes: Binding(
                                    get: { window.fridayEnd ?? window.end },
                                    set: { window.fridayEnd = $0 }))
                            }
                        }
                    } header: {
                        Text(tr("שעות"))
                    } footer: {
                        if !isSchool {
                            Text(tr("שעת השינה נמשכת עד הבוקר שאחרי."))
                        }
                    }
                    .glassRows()

                    if isSchool {
                        Section {
                            Toggle(tr("היום אין לימודים"), isOn: $offToday)
                                .tint(AppColor.successMint)
                            Toggle(tr("חופש — זמן בית הספר מושהה"), isOn: $paused)
                                .tint(AppColor.successMint)
                        } header: {
                            Text(tr("חגים וחופשות"))
                        } footer: {
                            Text(tr("\"היום אין לימודים\" חל רק על היום. מחר זמן בית הספר חוזר כרגיל."))
                        }
                        .glassRows()
                    }
                }
            }
            .readableColumn()
            .glassForm()
            .navigationTitle(isSchool ? tr("🏫 זמן בית ספר") : tr("🌙 שעת שינה"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !railHost.hasRail {
                    ToolbarItem(placement: .awayFromBar(.confirmationAction, leading: false)) {
                        Button(tr("סיום")) { if save() { dismiss() } }
                    }
                }
            }
        }
        .railDismiss(tr("סיום"), systemImage: "checkmark") { if save() { dismiss() } }
        .onAppear { load() }
        // One write per editing session, not one per wheel tick.
        .onDisappear { _ = save() }
    }

    // MARK: - Pieces

    private var dayChips: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { d in
                let on = window.days.contains(d)
                Button {
                    Haptic.light()
                    if on { window.days.removeAll { $0 == d } } else { window.days = (window.days + [d]).sorted() }
                } label: {
                    Text(QuietHoursText.dayLetter(d))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(on ? Color.white : GlassInk.secondary)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(on ? AppColor.successMint.opacity(0.55) : Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private func timeRow(_ title: String, minutes: Binding<Int>) -> some View {
        DatePicker(title, selection: Binding(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                         minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date() },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }), displayedComponents: .hourAndMinute)
    }

    // MARK: - Load / save

    private func load() {
        guard !loaded, let p = profile else { return }
        loaded = true
        let q = p.quietHours ?? QuietHours()
        let stored = isSchool ? q.school : q.bedtime
        var w = stored ?? (isSchool ? QuietHours.schoolDefault : QuietHours.bedtimeDefault)
        if stored == nil { w.enabled = false }
        window = w
        shortFriday = w.fridayEnd != nil && w.fridayEnd != w.end
        offToday = q.schoolOffDay == QuietHours.dayKey(Date())
        paused = q.schoolPaused == true
    }

    /// False only when the family isn't loaded and the edit was refused — "סיום"
    /// then keeps the sheet open (its alert explains) instead of losing it.
    @discardableResult
    private func save() -> Bool {
        guard loaded, var fresh = profile else { return true }
        var q = fresh.quietHours ?? QuietHours()
        var w = window
        // The child doc is MERGE-written, nested maps included: a value is cleared
        // by writing an explicit "off" (the regular end, "", false) — a missing
        // key would leave the old one standing.
        if isSchool {
            if !shortFriday { w.fridayEnd = w.end }
            q.school = w
            q.schoolOffDay = offToday ? QuietHours.dayKey(Date()) : ""
            q.schoolPaused = paused
        } else {
            w.fridayEnd = w.end
            q.bedtime = w
        }
        // Never written before and still off → leave the profile untouched.
        if fresh.quietHours == nil, q.isEmpty, !offToday, !paused { return true }
        guard q != fresh.quietHours else { return true }
        fresh.quietHours = q
        return profiles.parentEdit(fresh)
    }
}

/// The parent-facing words for a child's quiet hours.
enum QuietHoursText {
    /// "א׳" in Hebrew, "Sun" elsewhere — from the app language's own calendar.
    static func dayLetter(_ weekday: Int) -> String {
        let lang = LanguageStore.shared.current
        if lang == .he { return ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"][(weekday - 1) % 7] }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = lang.locale
        return cal.shortStandaloneWeekdaySymbols[(weekday - 1) % 7]
    }

    /// "א׳–ו׳", "כל יום", or "א׳, ג׳, ה׳".
    static func days(_ days: [Int]) -> String {
        let d = Array(Set(days)).sorted()
        if d.count == 7 { return tr("כל יום") }
        if d.isEmpty { return "—" }
        if d.count > 2, d.last! - d.first! == d.count - 1 {
            return "\(dayLetter(d.first!))–\(dayLetter(d.last!))"
        }
        return d.map(dayLetter).joined(separator: ", ")
    }

    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// The settings row: "א׳–ו׳ · 08:00–13:30" / "כבוי" / "חופש".
    static func summary(_ q: QuietHours?, kind: QuietKind) -> String {
        let w = kind == .school ? q?.school : q?.bedtime
        guard let w, w.enabled, !w.days.isEmpty else { return tr("כבוי") }
        if kind == .school, q?.schoolPaused == true { return tr("חופש — מושהה") }
        return "\(days(w.days)) · \u{2066}\(clock(w.start))–\(clock(w.end))\u{2069}"
    }
}
