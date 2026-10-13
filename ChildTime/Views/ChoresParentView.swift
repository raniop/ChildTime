import SwiftUI

/// 🧹 Parent-side chores screen for ONE child. The chores catalog is BUILT-IN —
/// every child automatically has ~15 house chores rewarding 🎮 play-minutes
/// scaled to the chore's size. Here the parent: approves/returns what the kid
/// marked done, retunes any chore's minutes, hides catalog chores or adds
/// custom ones. (Money rewards were removed — Rani.)
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
    /// Editing opens IN PLACE as a sheet (Rani: nobody found the editor at the
    /// bottom of the list). The bottom section is for a NEW chore only.
    @State private var showEditor = false
    @State private var formTitle = ""
    @State private var formEmoji = "🧹"
    @State private var formMinutes = 10
    @State private var formTimesPerDay = 1

    private static let emojiOptions = ["🧹", "🛏", "🍽", "🗑", "👕", "🐕", "🪴", "🎒", "🧸", "🛒", "🍳", "🧺"]

    private var myChores: [Chore] { choreStore.chores(forChild: profile.id) }
    private var pending: [Chore] { myChores.filter { $0.isPendingApproval } }
    private var rest: [Chore] { myChores.filter { !$0.isPendingApproval } }
    private var hidden: [Chore] { choreStore.hiddenPresets(forChild: profile.id) }

    var body: some View {
        if Self.newLook { newScreen } else { classic }
    }

    // MARK: - 🧪 A new look, for approval (Rani, 2026-10-13: "מסך מטלות לא יפה")
    //
    // DEMO_CHORES=new. The same data and the same actions as the list below,
    // drawn as the app's own tiles: who it is about, what waits for the parent,
    // today at a glance, and every chore as a card that says what it pays.

    private static var newLook: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["DEMO_CHORES"] == "new"
        #else
        return false
        #endif
    }

    private var newScreen: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(tr("מטלות הבית"))
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(tr("סגור"))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.16)))
                    }
                    // Who it is about — a face, not a segmented control.
                    if profilesStore.profiles.count > 1 {
                        HStack(spacing: 10) {
                            ForEach(profilesStore.profiles) { p in
                                let on = p.id == profile.id
                                let waiting = choreStore.chores(forChild: p.id).contains { $0.isPendingApproval }
                                Button { selectedID = p.id } label: {
                                    HStack(spacing: 8) {
                                        ProfileAvatarView(profile: p, size: 34)
                                        Text(p.name)
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.white)
                                        if waiting { Text("🕐").font(.system(size: 14)) }
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(on ? 0.22 : 0.08)))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(on ? AppColor.starGold : .white.opacity(0.2), lineWidth: on ? 2 : 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    // What waits for the parent comes first, and looks like it.
                    ForEach(pending) { chore in newPendingCard(chore) }
                    // Today at a glance.
                    HStack(spacing: 10) {
                        newStat("\(myChores.filter { $0.doneToday > 0 }.count)", tr("בוצעו היום"))
                        newStat("\(pending.count)", tr("מחכות לאישור"))
                        newStat("\(choreStore.totals(forChild: profile.id).minutes)", tr("דק׳ מהמטלות"))
                    }
                    Text(tr("המטלות של \(profile.name)"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        newAddTile
                        ForEach(rest) { chore in newChoreTile(chore) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $showEditor, onDismiss: { clearForm() }) {
            NavigationStack {
                Form { if let e = editing { Section { Text("\(e.emoji) \(e.title)").font(.headline); formFields }.glassRows() } }
                    .readableColumn(form: true).glassForm()
            }
        }
    }

    private func newStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.78))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassPane(radius: 16, shadow: false)
    }

    private func newPendingCard(_ chore: Chore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("מחכה לאישור שלכם"))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "2B1C04"))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
            HStack(spacing: 12) {
                Text(chore.emoji).font(.system(size: 40))
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(Question.stripNiqqud(chore.title))
                        .font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    Text(tr("🎮 \(chore.rewardMinutes) דק׳ משחק"))
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Text(tr("בוצע — אשרו ✅"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "1FA35C")))
                Text(tr("עוד לא הושלמה"))
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
            }
        }
        .padding(14)
        .glassPane(radius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppColor.starGold, lineWidth: 2))
    }

    private var newAddTile: some View {
        VStack(spacing: 8) {
            Text("＋").font(.system(size: 44, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .frame(height: 64)
            Text(tr("מטלה חדשה"))
                .font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text(tr("שם, אימוג׳י ודקות"))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, minHeight: 168)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
    }

    private func newChoreTile(_ chore: Chore) -> some View {
        let done = chore.approvedToday
        return Button { startEditing(chore) } label: {
            VStack(spacing: 8) {
                Text(chore.emoji).font(.system(size: 40))
                    .frame(maxWidth: .infinity).frame(height: 64)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)))
                Text(Question.stripNiqqud(chore.title))
                    .font(.system(size: 15.5, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                    .frame(minHeight: 38)
                HStack(spacing: 6) {
                    Text(tr("🎮 \(chore.rewardMinutes) דק׳"))
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2B1C04"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                    if chore.timesPerDay > 1 {
                        Text(tr("עד \(chore.timesPerDay) ביום"))
                            .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                Text(done ? tr("✅ הושלמה להיום") : (chore.doneToday > 0 ? tr("✅ \(chore.doneToday)/\(chore.timesPerDay) היום") : tr("עוד לא היום")))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(chore.doneToday > 0 ? Color(hex: "5CFF9D") : .white.opacity(0.55))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 168)
            .glassPane(radius: 16, shadow: false)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(done ? Color(hex: "5CFF9D").opacity(0.7) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var classic: some View {
        NavigationStack {
            Form {
                if profilesStore.profiles.count > 1 {
                    Section {
                        Picker(tr("ילד/ה"), selection: $selectedID) {
                            ForEach(profilesStore.profiles) { p in
                                // 🕐 marks a kid with a chore waiting for approval.
                                Text(choreStore.chores(forChild: p.id).contains(where: { $0.isPendingApproval })
                                     ? "\(p.name) 🕐" : p.name)
                                    .tag(p.id)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .glassRows()
                }

                if !pending.isEmpty {
                    Section(pending.count == 1 ? tr("מחכה לאישור שלכם 🕐") : tr("מחכות לאישור שלכם 🕐")) {
                        ForEach(pending) { chore in pendingRow(chore) }
                    }
                    .glassRows()
                }

                if choreStore.totals(forChild: profile.id).minutes > 0 {
                    Section {
                        Text(tr("סה\"כ הרוויח\(profile.gender == .girl ? tr("ה") : "") מהמטלות: 🎮 \(choreStore.totals(forChild: profile.id).minutes) דקות משחק"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .glassRows()
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
                    Text(tr("המטלות של \(profile.name)"))
                } footer: {
                    Text(tr("כל המטלות זמינות אוטומטית, ופרס דקות המשחק מוצע לפי גודל המטלה. לחיצה על מטלה — עריכת הפרס; החלקה — הסתרה."))
                }
                .glassRows()

                if !hidden.isEmpty {
                    Section(tr("מטלות שהוסתרו 🙈")) {
                        ForEach(hidden) { chore in
                            HStack {
                                Text("\(chore.emoji) \(chore.title)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(tr("החזירו")) { choreStore.restoreChore(chore) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                    .glassRows()
                }

                Section(tr("מטלה חדשה ➕")) {
                    formFields
                }
                .glassRows()
            }
            .readableColumn(form: true)
            .glassForm()
            .sheet(isPresented: $showEditor, onDismiss: { clearForm() }) {
                NavigationStack {
                    Form {
                        if let e = editing {
                            Section {
                                Text("\(e.emoji) \(e.title)").font(.headline)
                                formFields
                            }
                            .glassRows()
                        }
                    }
                    .readableColumn(form: true)
                    .glassForm()
                    .navigationTitle(tr("עריכת מטלה"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .awayFromBar(.cancellationAction, leading: true)) { Button(tr("ביטול")) { showEditor = false } } }
                }
                .environment(\.layoutDirection, .app)
                .presentationDetents([.medium, .large])
            }
            .navigationTitle(tr("מטלות הבית · \(profile.name)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .awayFromBar(.topBarLeading, leading: true)) { Button(tr("סגור")) { dismiss() } }
            }
            .onAppear { choreStore.startIfNeeded() }
            .onChangeCompat(of: selectedID) { _, _ in clearForm() }
            .alert(tr("האישור לא נשלח"), isPresented: $choreStore.lastActionFailed) {
                Button(tr("הבנתי"), role: .cancel) { }
            } message: {
                Text(tr("לא הצלחנו לאשר את המטלה כרגע. בדקו את החיבור לאינטרנט ונסו שוב."))
            }
        }
    }

    /// The shared fields: name + emoji for a custom chore, then the reward knobs
    /// and the save button. Used by the "new" section and the edit sheet.
    @ViewBuilder private var formFields: some View {
                    // A catalog chore keeps its name — only the rewards retune.
                    if editing == nil || !ChoreStore.isPreset(editing!) {
                        RTLTextField(placeholder: tr("מה המטלה? (למשל: לשטוף את האוטו)"), text: $formTitle)
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
                                                        in: RoundedRectangle(cornerRadius: 16))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Stepper(tr("🎮 פרס דקות משחק: \(formMinutes)"), value: $formMinutes, in: 5...120, step: 5)
                    Stepper(formTimesPerDay == 1 ? tr("🔁 פעם אחת ביום") : tr("🔁 עד \(formTimesPerDay) פעמים ביום"),
                            value: $formTimesPerDay, in: 1...6)
                    Button {
                        saveForm()
                    } label: {
                        HStack { Spacer(); Text(editing == nil ? tr("הוסיפו מטלה") : tr("שמרו שינויים")).bold(); Spacer() }
                    }
                    .disabled((editing == nil && formTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                              || formMinutes == 0)
    }

    @ViewBuilder
    private func pendingRow(_ chore: Chore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(chore.emoji) \(chore.title)").bold()
                Spacer()
                Text(tr("🎮 \(chore.rewardMinutes) דק׳ משחק"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let data = chore.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            let approving = choreStore.approvingIDs.contains(chore.id)
            HStack(spacing: 10) {
                Button {
                    Haptic.success()
                    choreStore.approve(chore)
                } label: {
                    HStack(spacing: 6) {
                        if approving { ProgressView().controlSize(.small).tint(.white) }
                        Text(approving ? tr("מאשר…") : tr("בוצע — אשרו ✅")).bold()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(approving)
                Button {
                    choreStore.returnChore(chore)
                    Haptic.light()
                } label: {
                    Text(tr("עוד לא הושלמה"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(approving)
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
                        Text(tr("🎮 \(chore.rewardMinutes) דק׳"))
                        if chore.timesPerDay > 1 { Text(tr("🔁 עד \(chore.timesPerDay) ביום")) }
                    if chore.isDaily && chore.doneToday > 0 {
                        Text(chore.approvedToday ? tr("✅ הושלמה להיום") : tr("✅ \(chore.doneToday)/\(chore.timesPerDay) היום"))
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
        formTimesPerDay = chore.timesPerDay
        showEditor = true
        Haptic.light()
    }

    private func clearForm() {
        editing = nil
        formTitle = ""
        formEmoji = "🧹"
        formMinutes = 10
        formTimesPerDay = 1
    }

    private func saveForm() {
        if let chore = editing {
            let keepName = ChoreStore.isPreset(chore)
            choreStore.updateChore(chore,
                                   title: keepName ? chore.title : formTitle.trimmingCharacters(in: .whitespaces),
                                   emoji: keepName ? chore.emoji : formEmoji,
                                   rewardMinutes: formMinutes,
                                   rewardCoins: 0,
                                   timesPerDay: formTimesPerDay)
        } else {
            choreStore.addChore(childID: profile.id,
                                title: formTitle.trimmingCharacters(in: .whitespaces),
                                emoji: formEmoji,
                                rewardMinutes: formMinutes,
                                rewardCoins: 0,
                                isDaily: true,
                                timesPerDay: formTimesPerDay)
        }
        showEditor = false
        clearForm()
        Haptic.success()
    }
}
