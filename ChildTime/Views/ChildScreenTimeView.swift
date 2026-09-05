import SwiftUI

/// Parent-side editor for ONE child's daily screen-time cap. Stored on the
/// child's `Profile` (`dailyCapMinutes`) and synced to their device via
/// `ChildRecord` — so the parent controls it from THEIR device, per child.
/// The parent types the exact minutes (no preset buttons); 0 = unlimited.
struct ChildScreenTimeView: View {
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
                    Text("בִּחֲרוּ כַּמָּה דַּקּוֹת מָסָךְ בְּיוֹם עֲבוּר \(profile?.name ?? "הַיֶּלֶד"). הַשִּׁנּוּי מִסְתַּנְכְרֵן אוֹטוֹמָטִית לַמַּכְשִׁיר שֶׁל הַיֶּלֶד.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("הַגְבָּלַת זְמַן יוֹמִית", isOn: $limited)

                    if limited {
                        HStack {
                            Text("דַּקּוֹת בְּיוֹם")
                            Spacer()
                            TextField("60", value: $minutes, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 64)
                                .focused($minutesFocused)
                                .textFieldStyle(.roundedBorder)
                            Stepper("", value: $minutes, in: Self.minMinutes...Self.maxMinutes, step: 5)
                                .labelsHidden()
                        }
                        // Friendly hours:minutes readout of whatever they typed.
                        Text(readout)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("לְלֹא הַגְבָּלָה")
                            Spacer()
                            Text("♾️")
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("מַקְסִימוּם זְמַן מָסָךְ יוֹמִי")
                } footer: {
                    Text("הַיֶּלֶד מַרְוִיחַ עַד הַתִּקְרָה הַזּוֹ בִּלְמִידָה. בּוֹנוּסִים מֵהַגַּלְגַּל/קוּפְסָה נִשְׁמָרִים לְמָחָר כְּשֶׁמַּגִּיעִים לַתִּקְרָה.")
                }
            }
            .glassForm()
            .navigationTitle("זְמַן מָסָךְ יוֹמִי")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סִיּוּם") { save(); dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("סִיּוּם") { minutesFocused = false }
                }
            }
        }
        .onAppear { loadIfNeeded() }
        // Persist when the sheet closes (covers both typed and stepped values)
        // — keeps Firestore writes to one per edit session, not one per keystroke.
        .onDisappear { save() }
        .onChangeCompat(of: limited) { _, on in if on && minutes < Self.minMinutes { minutes = 60 } }
    }

    private var readout: String {
        let m = clamped(minutes)
        let h = m / 60, r = m % 60
        let hWord = h == 1 ? "שָׁעָה" : "\(h) שָׁעוֹת"
        if h == 0 { return "\(r) דַּקּוֹת בְּיוֹם" }
        if r == 0 { return "\(hWord) בְּיוֹם" }
        return "\(hWord) וְ-\(r) דַּקּוֹת בְּיוֹם"
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
        profiles.update(p)
        Haptic.light()
    }
}
