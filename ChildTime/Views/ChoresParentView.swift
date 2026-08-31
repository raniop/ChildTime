import SwiftUI

/// 🧹 Parent-side chores screen for ONE child. The chores catalog is BUILT-IN —
/// every child automatically has ~15 house chores with rewards scaled to the
/// chore's size, and the kid picks which reward they want (a little trade with
/// the parent). Here the parent: approves/returns what the kid marked done,
/// settles the 🪙 money pocket, retunes any chore's rewards, hides catalog
/// chores or adds custom ones.
struct ChoresParentView: View {
    /// The child the screen opened on — a segmented picker switches between
    /// ALL the kids without leaving the screen (Rani: "אין לי דרך לראות מטלות
    /// של כל הילדים").
    let initialProfile: Profile
    @StateObject private var choreStore = ChoreStore.shared
    @StateObject private var profilesStore = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID

    init(profile: Profile) {
        self.initialProfile = profile
        _selectedID = State(initialValue: profile.id)
    }

    private var profile: Profile {
        profilesStore.profiles.first { $0.id == selectedID } ?? initialProfile
    }

    // Add/edit form. `editing` non-nil → the form edits that chore.
    @State private var editing: Chore?
    @State private var formTitle = ""
    @State private var formEmoji = "🧹"
    @State private var formMinutes = 10
    @State private var formCoins = 5
    @State private var formTimesPerDay = 1
    @State private var settleConfirm = false

    private static let emojiOptions = ["🧹", "🛏", "🍽", "🗑", "👕", "🐕", "🪴", "🎒", "🧸", "🛒", "🍳", "🧺"]

    private var myChores: [Chore] { choreStore.chores(forChild: profile.id) }
    private var pending: [Chore] { myChores.filter { $0.isPendingApproval } }
    private var rest: [Chore] { myChores.filter { !$0.isPendingApproval } }
    private var hidden: [Chore] { choreStore.hiddenPresets(forChild: profile.id) }

    /// 🪙 what the family owes the kid right now — pure ledger arithmetic
    /// (earned − paid), immune to old-build snapshot pushes.
    private var moneyBalance: Int { choreStore.moneyBalance(forChild: profile.id) }

    var body: some View {
        NavigationStack {
            Form {
                if profilesStore.profiles.count > 1 {
                    Section {
                        Picker("ילד/ה", selection: $selectedID) {
                            ForEach(profilesStore.profiles) { p in
                                // 🕐 marks a kid with a chore waiting for approval.
                                Text(choreStore.chores(forChild: p.id).contains(where: { $0.isPendingApproval })
                                     ? "\(p.name) 🕐" : p.name)
                                    .tag(p.id)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if !pending.isEmpty {
                    Section("מחכה לאישור שלכם 🕐") {
                        ForEach(pending) { chore in pendingRow(chore) }
                    }
                }

                Section("קופת הכסף 🪙") {
                    HStack {
                        Text("\(profile.name) \(profile.gender == .girl ? "צברה" : "צבר")")
                        Spacer()
                        Text("₪\(moneyBalance)")
                            .font(.system(.body, design: .rounded)).bold()
                            .foregroundStyle(moneyBalance > 0 ? .orange : .secondary)
                    }
                    if moneyBalance > 0 {
                        Button("שילמתי ביד — אפסו את הקופה ✅") { settleConfirm = true }
                            .confirmationDialog("נתתם ל\(profile.name) ₪\(moneyBalance) ביד?",
                                                isPresented: $settleConfirm, titleVisibility: .visible) {
                                Button("כן, שילמתי — אפסו") {
                                    choreStore.settleMoney(childID: profile.id, amount: moneyBalance)
                                    Haptic.success()
                                }
                                Button("ביטול", role: .cancel) {}
                            }
                    } else {
                        Text("כשמאשרים מטלה עם פרס כסף — הסכום נרשם כאן, ואתם נותנים ביד.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    let totals = choreStore.totals(forChild: profile.id)
                    if totals.minutes > 0 || totals.coins > 0 {
                        Text("סה\"כ מהמטלות עד היום: ⏰ \(totals.minutes) דק׳ · 🪙 ₪\(totals.coins)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(rest) { chore in choreRow(chore) }
                        .onDelete { idx in
                            for chore in idx.map({ rest[$0] }) {
                                if ChoreStore.isPreset(chore) { choreStore.hideChore(chore) }
                                else { choreStore.deleteChore(chore) }
                            }
                        }
                } header: {
                    Text("המטלות של \(profile.name)")
                } footer: {
                    Text("כל המטלות זמינות אוטומטית, והפרסים מוצעים לפי גודל המטלה. לחיצה על מטלה — עריכת הפרסים; החלקה — הסתרה. \(profile.gender == .girl ? "היא בוחרת" : "הוא בוחר") בעצמו אם לקבל דקות או כסף.")
                }

                if !hidden.isEmpty {
                    Section("מטלות שהוסתרו 🙈") {
                        ForEach(hidden) { chore in
                            HStack {
                                Text("\(chore.emoji) \(chore.title)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("החזירו") { choreStore.restoreChore(chore) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                Section(editing == nil ? "מטלה חדשה ➕" : "עריכת מטלה ✏️") {
                    if let e = editing {
                        HStack {
                            Text("עורכים: \(e.emoji) \(e.title)")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("ביטול") { clearForm() }
                                .font(.caption)
                                .buttonStyle(.borderless)
                        }
                    }
                    // A catalog chore keeps its name — only the rewards retune.
                    if editing == nil || !ChoreStore.isPreset(editing!) {
                        RTLTextField(placeholder: "מה המטלה? (למשל: לשטוף את האוטו)", text: $formTitle)
                            .frame(height: 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Self.emojiOptions, id: \.self) { e in
                                    Button {
                                        formEmoji = e
                                    } label: {
                                        Text(e).font(.system(size: 26))
                                            .frame(width: 40, height: 40)
                                            .background(formEmoji == e ? Color.accentColor.opacity(0.25) : .clear,
                                                        in: RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Stepper("⏰ פרס דקות משחק: \(formMinutes)", value: $formMinutes, in: 0...120, step: 5)
                    Stepper("🪙 פרס כסף: ₪\(formCoins)", value: $formCoins, in: 0...100)
                    Stepper(formTimesPerDay == 1 ? "🔁 פעם אחת ביום" : "🔁 עד \(formTimesPerDay) פעמים ביום",
                            value: $formTimesPerDay, in: 1...6)
                    Button {
                        saveForm()
                    } label: {
                        HStack { Spacer(); Text(editing == nil ? "הוסיפו מטלה" : "שמרו שינויים").bold(); Spacer() }
                    }
                    .disabled((editing == nil && formTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                              || (formMinutes == 0 && formCoins == 0))
                }
            }
            .navigationTitle("מטלות הבית · \(profile.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("סגור") { dismiss() } }
            }
            .onAppear { choreStore.startIfNeeded() }
            .onChangeCompat(of: selectedID) { _, _ in clearForm() }
        }
    }

    @ViewBuilder
    private func pendingRow(_ chore: Chore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(chore.emoji) \(chore.title)").bold()
                Spacer()
                Text(chore.chosenReward == "coins"
                     ? "🪙 בחר/ה ₪\(chore.rewardCoins)"
                     : "⏰ בחר/ה \(chore.rewardMinutes) דק׳")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let data = chore.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            HStack(spacing: 10) {
                Button {
                    choreStore.approve(chore)
                    Haptic.success()
                } label: {
                    Text("בוצע — אשרו ✅").bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                Button {
                    choreStore.returnChore(chore)
                    Haptic.light()
                } label: {
                    Text("עוד לא הושלמה")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func choreRow(_ chore: Chore) -> some View {
        Button {
            startEditing(chore)
        } label: {
            HStack {
                Text(chore.emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(chore.title).foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        if chore.rewardMinutes > 0 { Text("⏰ \(chore.rewardMinutes) דק׳") }
                        if chore.rewardMinutes > 0 && chore.rewardCoins > 0 { Text("או") }
                        if chore.rewardCoins > 0 { Text("🪙 ₪\(chore.rewardCoins)") }
                        if chore.timesPerDay > 1 { Text("🔁 עד \(chore.timesPerDay) ביום") }
                    if chore.isDaily && chore.doneToday > 0 {
                        Text(chore.approvedToday ? "✅ הושלמה להיום" : "✅ \(chore.doneToday)/\(chore.timesPerDay) היום")
                    }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func startEditing(_ chore: Chore) {
        editing = chore
        formTitle = chore.title
        formEmoji = chore.emoji
        formMinutes = chore.rewardMinutes
        formCoins = chore.rewardCoins
        formTimesPerDay = chore.timesPerDay
        Haptic.light()
    }

    private func clearForm() {
        editing = nil
        formTitle = ""
        formEmoji = "🧹"
        formMinutes = 10
        formCoins = 5
        formTimesPerDay = 1
    }

    private func saveForm() {
        if let chore = editing {
            let keepName = ChoreStore.isPreset(chore)
            choreStore.updateChore(chore,
                                   title: keepName ? chore.title : formTitle.trimmingCharacters(in: .whitespaces),
                                   emoji: keepName ? chore.emoji : formEmoji,
                                   rewardMinutes: formMinutes,
                                   rewardCoins: formCoins,
                                   timesPerDay: formTimesPerDay)
        } else {
            choreStore.addChore(childID: profile.id,
                                title: formTitle.trimmingCharacters(in: .whitespaces),
                                emoji: formEmoji,
                                rewardMinutes: formMinutes,
                                rewardCoins: formCoins,
                                isDaily: true,
                                timesPerDay: formTimesPerDay)
        }
        clearForm()
        Haptic.success()
    }
}
