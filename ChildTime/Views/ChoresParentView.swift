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


    private var myChores: [Chore] { choreStore.chores(forChild: profile.id) }
    private var pending: [Chore] { myChores.filter { $0.isPendingApproval } }
    private var rest: [Chore] { myChores.filter { !$0.isPendingApproval } }
    private var hidden: [Chore] { choreStore.hiddenPresets(forChild: profile.id) }

    // The screen (Rani, 2026-10-13: "מסך מטלות לא יפה" — it was a settings-style
    // list). The same data and the same actions, drawn as the app's own tiles:
    // who it is about, what waits for the parent, today at a glance, and every
    // chore as a card that says what it pays and what happened with it today.
    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if profilesStore.profiles.count > 1 { childChips }
                        // What waits for the parent comes first, and looks like it.
                        ForEach(pending) { chore in pendingCard(chore) }
                        HStack(spacing: 10) {
                            stat("\(myChores.filter { $0.doneToday > 0 }.count)", tr("בוצעו היום"))
                            stat("\(pending.count)", tr("מחכות לאישור"))
                            stat("\(choreStore.totals(forChild: profile.id).minutes)", tr("דק׳ מהמטלות"))
                        }
                        Text(tr("המטלות של \(profile.name)"))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 4)
                        // Rows, like the child's own screen (Rani, 2026-10-13: "בשורות
                        // זה יותר טוב") — the same picture and the same colour for the
                        // same chore on both sides.
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: hsc == .compact ? 1 : 2), spacing: 10) {
                            addTile
                            ForEach(rest) { chore in choreTile(chore) }
                        }
                        Text(tr("כל המטלות זמינות לילד אוטומטית, ופרס דקות המשחק מוצע לפי גודל המטלה. לחיצה על מטלה פותחת את העריכה שלה."))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        if !hidden.isEmpty { hiddenCard }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                }
            }
            .sheet(isPresented: $showEditor, onDismiss: { clearForm() }) {
                NavigationStack {
                    Form {
                        Section {
                            if let e = editing { Text("\(e.emoji) \(Question.stripNiqqud(e.title))").font(.headline) }
                            formFields
                        }
                        .glassRows()
                        // Removing a chore lives inside the chore itself (never a
                        // swipe on a list): a built-in one is hidden and can come
                        // back, a family's own one is deleted.
                        if let e = editing {
                            Section {
                                Button(role: .destructive) {
                                    if ChoreStore.isPreset(e) { choreStore.hideChore(e) } else { choreStore.deleteChore(e) }
                                    showEditor = false
                                } label: {
                                    HStack { Spacer(); Text(ChoreStore.isPreset(e) ? tr("הסתרת המטלה") : tr("מחיקת המטלה")); Spacer() }
                                }
                            } footer: {
                                if ChoreStore.isPreset(e) { Text(tr("מטלה מוסתרת לא מופיעה אצל הילד. אפשר להחזיר אותה מתחתית המסך.")) }
                            }
                            .glassRows()
                        }
                    }
                    .readableColumn(form: true)
                    .glassForm()
                    .navigationTitle(editing == nil ? tr("מטלה חדשה") : tr("עריכת מטלה"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar { ToolbarItem(placement: .awayFromBar(.cancellationAction, leading: true)) { Button(tr("ביטול")) { showEditor = false } } }
                }
                .environment(\.layoutDirection, .app)
                .presentationDetents([.medium, .large])
            }
            .navigationTitle(tr("מטלות הבית"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)   // white title on the glass
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

    @Environment(\.horizontalSizeClass) private var hsc

    /// Who it is about — a face, not a segmented control. 🕐 = a chore of theirs waits.
    private var childChips: some View {
        HStack(spacing: 10) {
            ForEach(profilesStore.profiles) { p in
                let on = p.id == profile.id
                let waiting = choreStore.chores(forChild: p.id).contains { $0.isPendingApproval }
                Button { Haptic.light(); selectedID = p.id } label: {
                    HStack(spacing: 8) {
                        ProfileAvatarView(profile: p, size: 34)
                        Text(p.name)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
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

    private func stat(_ value: String, _ label: String) -> some View {
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

    /// A chore the child marked as done: its photo if there is one, and the two answers.
    private func pendingCard(_ chore: Chore) -> some View {
        let approving = choreStore.approvingIDs.contains(chore.id)
        return VStack(alignment: .leading, spacing: 12) {
            Text(tr("מחכה לאישור שלכם"))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "2B1C04"))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
            HStack(spacing: 12) {
                ChorePicture(chore: chore, side: 56)
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(Question.stripNiqqud(chore.title))
                        .font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tr("🎮 \(chore.rewardMinutes) דק׳ משחק"))
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            if let data = chore.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            HStack(spacing: 10) {
                Button {
                    Haptic.success()
                    choreStore.approve(chore)
                } label: {
                    HStack(spacing: 6) {
                        if approving { ProgressView().controlSize(.small).tint(.white) }
                        Text(approving ? tr("מאשר…") : tr("בוצע — אשרו ✅"))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "1FA35C")))
                }
                .buttonStyle(.plain)
                .disabled(approving)
                Button {
                    choreStore.returnChore(chore)
                    Haptic.light()
                } label: {
                    Text(tr("עוד לא הושלמה"))
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .disabled(approving)
            }
        }
        .padding(14)
        .glassPane(radius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppColor.starGold, lineWidth: 2))
    }

    /// "＋ מטלה חדשה" — the first row, so it is found without scrolling past twenty chores.
    private var addTile: some View {
        Button {
            Haptic.light()
            clearForm()
            showEditor = true
        } label: {
            HStack(spacing: 12) {
                Text("＋").font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("מטלה חדשה"))
                        .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    Text(tr("שם, תמונה ודקות"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 86)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// One chore, one coloured row: its picture, its name, the prize in gold,
    /// how it stands today — and a tap on the row edits it.
    private func choreTile(_ chore: Chore) -> some View {
        let done = chore.approvedToday
        let tint = ChoreArt.tint(for: chore)
        return Button { startEditing(chore) } label: {
            HStack(spacing: 12) {
                ChorePicture(chore: chore, side: 70)
                    .scaleEffect(1.08)
                VStack(alignment: .leading, spacing: 6) {
                    Text(Question.stripNiqqud(chore.title))
                        .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .multilineTextAlignment(.leading).lineLimit(2).minimumScaleFactor(0.8)
                    HStack(spacing: 7) {
                        Text(tr("🎮 \(chore.rewardMinutes) דק׳"))
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "2B1C04"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                        if chore.timesPerDay > 1 {
                            Text(tr("עד \(chore.timesPerDay) ביום"))
                                .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .lineLimit(1)
                }
                Spacer(minLength: 2)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(done ? tr("✅ הושלמה להיום") : (chore.doneToday > 0 ? tr("✅ \(chore.doneToday)/\(chore.timesPerDay) היום") : tr("עוד לא היום")))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(chore.doneToday > 0 ? Color(hex: "B6FFD3") : .white.opacity(0.75))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.18)))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 86)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.62), tint.opacity(0.28)], startPoint: .leading, endPoint: .trailing)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(done ? Color(hex: "5CFF9D").opacity(0.8) : .white.opacity(0.35), lineWidth: done ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Built-in chores the parent hid — each can come back.
    private var hiddenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("מטלות שהוסתרו"))
                .font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            ForEach(hidden) { chore in
                HStack {
                    Text("\(chore.emoji) \(Question.stripNiqqud(chore.title))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Button { choreStore.restoreChore(chore) } label: {
                        Text(tr("החזירו"))
                            .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassPane(radius: 16, shadow: false)
    }

    /// The shared fields: name + emoji for a custom chore, then the reward knobs
    /// and the save button. Used by the "new" section and the edit sheet.
    @ViewBuilder private var formFields: some View {
                    // A catalog chore keeps its name — only the rewards retune.
                    if editing == nil || !ChoreStore.isPreset(editing!) {
                        RTLTextField(placeholder: tr("מה המטלה? (למשל: לשטוף את האוטו)"), text: $formTitle)
                            .frame(height: 24)
                        picturePicker
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

    /// 🎨 The picture of the chore (Rani, 2026-10-13): the drawings, in a grid —
    /// and, first in it, a box that opens the phone's own emoji keyboard for
    /// any emoji at all (Sasha, 12.10: "לצחצח שיניים" had no toothbrush).
    private var picturePicker: some View {
        let chosen = ChoreArt.key(forEmoji: formEmoji)
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr("תמונה למטלה"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: hsc == .compact ? 5 : 8), spacing: 8) {
                    VStack(spacing: 2) {
                        EmojiPickField(emoji: $formEmoji, isCustom: chosen == nil)
                            .frame(width: 44, height: 40)
                        Text(tr("אימוג׳י"))
                            .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).frame(height: 62)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(chosen == nil ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(chosen == nil ? Color.accentColor : .clear, lineWidth: 2))
                    ForEach(ChoreArt.library, id: \.key) { art in
                        Button {
                            Haptic.light()
                            formEmoji = art.emoji
                        } label: {
                            Group {
                                if let img = ChoreArt.image(key: art.key) { Image(uiImage: img).resizable().scaledToFit() }
                                else { Text(art.emoji).font(.system(size: 30)) }
                            }
                            .padding(5)
                            .frame(maxWidth: .infinity).frame(height: 62)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(chosen == art.key ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(chosen == art.key ? Color.accentColor : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(art.emoji)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 290)   // four rows and a peek of the fifth: there is more to scroll
        }
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


/// A one-emoji field that opens the phone's EMOJI keyboard: shows "＋" until a
/// custom emoji is chosen, then that emoji.
struct EmojiPickField: UIViewRepresentable {
    @Binding var emoji: String
    var isCustom: Bool

    final class Field: UITextField {
        override var textInputContextIdentifier: String? { "" }
        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
        }
        override func caretRect(for position: UITextPosition) -> CGRect { .zero }
    }

    func makeUIView(context: Context) -> Field {
        let f = Field()
        f.delegate = context.coordinator
        f.textAlignment = .center
        f.font = .systemFont(ofSize: 24)
        f.tintColor = .clear
        f.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return f
    }

    func updateUIView(_ f: Field, context: Context) {
        context.coordinator.parent = self
        let shown = isCustom ? emoji : "＋"
        if f.text != shown, !f.isFirstResponder || isCustom { f.text = shown }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiPickField
        init(_ parent: EmojiPickField) { self.parent = parent }

        func textFieldDidBeginEditing(_ textField: UITextField) { textField.text = "" }

        @objc func changed(_ f: UITextField) {
            // Keep the last thing typed, and only if it really is an emoji.
            guard let last = f.text?.last, last.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.properties.isEmoji && $0.value > 0x238C }) else {
                f.text = ""; return
            }
            parent.emoji = String(last)
            f.text = String(last)
            f.resignFirstResponder()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool { textField.resignFirstResponder(); return true }
    }
}
