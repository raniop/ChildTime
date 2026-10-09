import SwiftUI

/// Parent-side editor for ONE child's daily screen-time cap. Stored on the
/// child's `Profile` (`dailyCapMinutes`) and synced to their device via
/// `ChildRecord` — so the parent controls it from THEIR device, per child.
/// The parent types the exact minutes (no preset buttons); 0 = unlimited.
struct ChildScreenTimeView: View {
    @ObservedObject private var railHost = DisplayGeometry.shared
    @EnvironmentObject private var profiles: ProfileStore
    @EnvironmentObject private var settings: ParentSettings
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID

    @State private var limited: Bool = true
    @State private var minutes: Int = 60
    @State private var loaded = false
    @FocusState private var minutesFocused: Bool

    private static let minMinutes = 5
    private static let maxMinutes = 600   // 10 hours — generous manual ceiling

    private var profile: Profile? {
        profiles.profiles.first(where: { $0.id == profileID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(tr("בחרו כמה דקות מסך ביום עבור \(profile?.name ?? tr("הילד")). השינוי מסתנכרן אוטומטית למכשיר של הילד."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .glassRows()

                Section {
                    Toggle(tr("הגבלת זמן יומית"), isOn: $limited)

                    if limited {
                        HStack {
                            Text(tr("דקות ביום"))
                            Spacer()
                            TextField("60", value: $minutes, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 64)
                                .focused($minutesFocused)
                                .textFieldStyle(.plain)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                            Stepper("", value: $minutes, in: Self.minMinutes...Self.maxMinutes, step: 5)
                                .labelsHidden()
                        }
                        // Friendly hours:minutes readout of whatever they typed.
                        Text(readout)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text(tr("ללא הגבלה"))
                            Spacer()
                            Text("♾️")
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(tr("מקסימום זמן מסך יומי"))
                } footer: {
                    Text(tr("הילד מרוויח עד התקרה הזו בלמידה. בונוסים מהגלגל/קופסה נשמרים למחר כשמגיעים לתקרה."))
                }
                .glassRows()
            }
            .readableColumn()
            .glassForm()
            .navigationTitle(tr("זמן מסך יומי"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 🎚 The one way out lives in the rail on a foldable.
                if !railHost.hasRail {
                    ToolbarItem(placement: .awayFromBar(.confirmationAction, leading: false)) {
                        Button(tr("סיום")) { save(); dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(tr("סיום")) { minutesFocused = false }
                }
            }
        }
        // 🎚 Outside the NavigationStack and outside the readable-width cap —
        // otherwise the rail is drawn at the edge of the 600pt column instead
        // of the edge of the glass.
        .railDismiss(tr("סיום"), systemImage: "checkmark") { save(); dismiss() }
        .onAppear { loadIfNeeded() }
        // Persist when the sheet closes (covers both typed and stepped values)
        // — keeps Firestore writes to one per edit session, not one per keystroke.
        .onDisappear { save() }
        .onChangeCompat(of: limited) { _, on in if on && minutes < Self.minMinutes { minutes = 60 } }
    }

    private var readout: String {
        let m = clamped(minutes)
        let language = LanguageStore.shared.current
        // 🇦🇪 Arabic: the hours word from the catalog read "2 ساعتان" (the dual
        // already says "two"), and a line opening with a digit could come out
        // with its numbers in the wrong order (QA round 3). The system's own
        // formatter writes it the Arabic way — "ساعتان و30 دقيقة", Western
        // digits from the app's locale — and the whole line is one explicit
        // right-to-left unit (RLM + RLI … PDI), whatever direction the text
        // view itself starts in. Hebrew is untouched; English/Russian keep the
        // catalog's "and"/"и".
        if language.isRightToLeft, language != .he, let span = Self.durationText(minutes: m, locale: language.locale) {
            return "\u{200F}\u{2067}" + tr("\(span) ביום") + "\u{2069}"
        }
        let h = m / 60, r = m % 60
        let hWord = h == 1 ? tr("שעה") : tr("\(h) שעות")
        if h == 0 { return tr("\(r) דקות ביום") }
        if r == 0 { return tr("\(hWord) ביום") }
        return tr("\(hWord) ו-\(r) דקות ביום")
    }

    /// "ساعة و30 دقيقة" — hours + minutes spelled out by the system in `locale`.
    private static func durationText(minutes: Int, locale: Locale) -> String? {
        let f = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        f.calendar = calendar
        f.unitsStyle = .full
        f.allowedUnits = [.hour, .minute]
        return f.string(from: TimeInterval(minutes * 60))
    }

    private func clamped(_ v: Int) -> Int { min(Self.maxMinutes, max(Self.minMinutes, v)) }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let m = profile?.dailyCapMinutes {
            limited = m > 0
            minutes = m > 0 ? m : 60
        } else {
            limited = settings.dailyCapEnabled
            minutes = settings.maxMinutesPerDay
        }
    }

    private func save() {
        guard var p = profile else { return }
        let value = limited ? clamped(minutes) : 0
        // If this child was INHERITING the global cap (dailyCapMinutes == nil)
        // and the shown value still equals that inherited value, don't write —
        // otherwise merely opening+closing this sheet froze the child onto a
        // per-child override and future global changes stopped affecting them.
        if p.dailyCapMinutes == nil {
            let inherited = settings.dailyCapEnabled ? settings.maxMinutesPerDay : 0
            if value == inherited { return }
        }
        guard p.dailyCapMinutes != value else { return }
        p.dailyCapMinutes = value
        profiles.parentEdit(p)
        Haptic.light()
    }
}
