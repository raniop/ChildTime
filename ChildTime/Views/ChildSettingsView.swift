import SwiftUI

/// The adaptive engine's view of ONE topic for one child: the difficulty it is
/// actually serving now, and whether that sits above or below the parent's base
/// for the topic. Shared by the report's topic rows (a small tag) and the
/// child's settings page (the full "רמת קושי חכמה" list).
enum AdaptiveTopicLevel {
    enum Direction { case raised, eased }

    struct State {
        let served: Difficulty
        let direction: Direction?
    }

    static func state(for topic: Topic, profile: Profile, snapshot s: ProgressSnapshot) -> State {
        let base = AdaptiveDifficultyEngine.level(for: profile.difficulty(for: topic))
        let level = s.topicAdaptiveLevel?[topic.rawValue] ?? base
        let dir: Direction? = level > base + 0.35 ? .raised : (level < base - 0.35 ? .eased : nil)
        return State(served: AdaptiveDifficultyEngine.difficulty(forLevel: level), direction: dir)
    }

    /// Enough answers for the engine's levels to mean something.
    static func hasSignal(_ s: ProgressSnapshot) -> Bool { s.totalAnswered >= 4 }

    /// Topics the child has actually practiced, most-practiced first.
    static func practicedTopics(profile: Profile, snapshot s: ProgressSnapshot, limit: Int = 6) -> [Topic] {
        Array(profile.playableTopics
            .filter { (s.topicAnswered[$0.rawValue] ?? 0) >= 1 }
            .sorted { (s.topicAnswered[$0.rawValue] ?? 0) > (s.topicAnswered[$1.rawValue] ?? 0) }
            .prefix(limit))
    }

    /// One warm, plain-language sentence about the most notable adaptation —
    /// a topic where the system raised the challenge, else one it eased.
    static func sentence(for topics: [Topic], profile: Profile, snapshot s: ProgressSnapshot) -> String? {
        let g: (String, String) -> String = { profile.gender == .girl ? $1 : $0 }
        if let raised = topics.first(where: { state(for: $0, profile: profile, snapshot: s).direction == .raised }) {
            return tr("\(profile.name) \(g(tr("מתקדם"),tr("מתקדמת"))) יפה ב\(raised.parentName), אז המערכת התחילה להוסיף שאלות מעט מאתגרות יותר.")
        }
        if let eased = topics.first(where: { state(for: $0, profile: profile, snapshot: s).direction == .eased }) {
            return tr("ב\(eased.parentName) המערכת הורידה מעט את הקושי כדי לבנות ביטחון והצלחה.")
        }
        return nil
    }
}

/// "הַגְדָּרוֹת שֶׁל {name}" — everything about ONE child that is set rather than
/// read, in one grouped list (Rani's approved mockup). The child's page itself
/// is the report; this sheet replaced the old card's "⋯" menu and its folded
/// legacy blocks. Each row opens the same editor it always did.
///
/// It owns its own sheets and confirmations: it is itself presented as a sheet,
/// so the dashboard's dialogs (on the page underneath) could not show over it.
struct ChildSettingsView: View {
    @ObservedObject private var railHost = DisplayGeometry.shared
    @EnvironmentObject private var profiles: ProfileStore
    @EnvironmentObject private var settings: ParentSettings
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID
    let snapshot: ProgressSnapshot
    /// Pushed inside the ⚙️ window (see `SettingsStack`); alone it is its own sheet.
    var embedded = false
    /// Owned by the dashboard: the local + cloud wipe and its refresh.
    var onResetProgress: (Profile) -> Void
    /// Owned by the dashboard: removes the child, closes the window and pops the page.
    var onDelete: (Profile) -> Void
    /// "Connect a device": the pairing code is made and watched by the home
    /// screen, so the home screen supplies the sheet — and it opens OVER this
    /// window (`pairing`), instead of closing the settings to show it.
    var onConnectDevice: (() -> Void)? = nil
    var pairing: Binding<Profile?>? = nil
    var pairingSheet: ((Profile) -> AnyView)? = nil
    /// 📍 The map slides in here too.
    var showsLocation = false
    @Environment(\.closeSettings) private var closeSettings
    /// "סיום" closes the whole settings window, from any depth.
    private func close() { if embedded, let closeSettings { closeSettings() } else { dismiss() } }

    @State private var editing: Profile? = nil
    @State private var friends: Profile? = nil
    @State private var confirmPinReset = false
    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var remoteNote: String? = nil
    @State private var deviceToRemove: ChildDevice? = nil
    /// What just happened on "עוד הגדרות" (refresh sent, progress reset) — on
    /// THAT page; an alert on the settings root underneath never comes up.
    @State private var moreNote: String? = nil

    private var profile: Profile? { profiles.profiles.first { $0.id == profileID } }

    var body: some View {
        SettingsStack(embedded: embedded) {
            Group {
                if let p = profile {
                    sheets(form(p))
                } else {
                    Color.clear.background(GlassBackdrop())
                }
            }
            .navigationTitle(profile.map { tr("הגדרות של \($0.name)") } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 🎚 The one way out lives in the rail on a foldable.
                if !railHost.hasRail {
                    ToolbarItem(placement: .awayFromBar(.confirmationAction, leading: false)) {
                        Button(tr("סיום")) { close() }
                    }
                }
            }
        }
        .railDismiss(unless: embedded, tr("סיום"), systemImage: "checkmark") { dismiss() }
        // Every page pushed from here closes the same window with its "סיום".
        .environment(\.closeSettings, closeSettings ?? { dismiss() })
        // 🔌 An edit refused while the family isn't loaded — outside the
        // NavigationStack, so it shows from every pushed page. (The editor
        // SHEETS below carry their own: an alert can't show under a sheet.)
        .familyConnectionAlert()
        .environment(\.layoutDirection, .app)
    }

    // MARK: - The list

    private func form(_ p: Profile) -> some View {
        // Four groups in the order a parent uses them (Rani, 2026-10-11: "יותר
        // מדי דברים, יותר מדי מסובך… סדר הדברים לא טוב"): time · learning ·
        // devices · profile. Every row slides its page IN — nothing closes this
        // window to open another.
        Form {
            screenTimeSection(p)
            learningSection(p)
            deviceSection(p)
            profileSection(p)
        }
        .readableColumn()
        .glassForm()
    }

    /// A row that slides its page in.
    private func link<D: View>(_ emoji: String, _ title: String, value: String? = nil,
                               valueTint: Color = GlassInk.secondary,
                               @ViewBuilder to destination: @escaping () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            rowLabel(emoji, title, value: value, valueTint: valueTint, chevron: false)
        }
    }

    /// 📱 The child's own device(s) and the map.
    private func deviceSection(_ p: Profile) -> some View {
        let devices = household.devicesByChild[p.id.uuidString] ?? []
        let deviceValue = devices.isEmpty
            ? (onConnectDevice != nil ? tr("עוד לא חובר — לחצו לחיבור") : tr("עוד לא חובר"))
            : devices.map(\.name).joined(separator: ", ") + " · " + tr("מחובר")
        return Section {
            if devices.isEmpty, onConnectDevice != nil {
                row("📱", tr("המכשיר של \(p.name)"), value: deviceValue) { connectDevice(p) }
            } else if devices.isEmpty {
                rowLabel("📱", tr("המכשיר של \(p.name)"), value: deviceValue, chevron: false)
            } else {
                link("📱", tr("המכשיר של \(p.name)"), value: deviceValue) { devicesPage(p) }
            }
            if showsLocation, !devices.isEmpty {   // 📍 nothing to locate without a device
                link("📍", tr("איפה \(p.name)"), value: tr("מפה, מקומות וצפצוף לטלפון")) {
                    ParentLocationView(focusChildID: p.id.uuidString, embedded: true)
                        .environmentObject(profiles)
                        .environment(\.layoutDirection, .app)
                }
            }
        } header: {
            Text(tr("📱 מכשיר ומיקום"))
        }
        .glassRows()
    }

    private func connectDevice(_ p: Profile) {
        onConnectDevice?()
        pairing?.wrappedValue = p
    }

    private func learningSection(_ p: Profile) -> some View {
        let listed = ChildWorldsView.listedWorlds(for: p)
        let open = listed.filter { p.allows($0.topic) }.count
        let girl = p.gender == .girl
        let lang = p.language.flatMap(AppLanguage.init(rawValue:))
        return Section {
            // ONE place for difficulty: what the parent chose, and — inside —
            // what the engine serves per topic. A "בינוני" row over a list of
            // "קל" and "קשה" read as a contradiction (Rani, 2026-10-11).
            link("🎚️", tr("רמת קושי"), value: tr("\(difficultySummary(p)) · מתאימה את עצמה לכל נושא")) {
                ChildDifficultyView(profileID: p.id, snapshot: snapshot, embedded: true)
                    .environmentObject(profiles)
            }
            link("🌐", tr("עולמות פעילים"), value: listed.isEmpty ? nil : tr("\(open) מתוך \(listed.count)")) {
                ChildWorldsView(profileID: p.id, embedded: true)
                    .environmentObject(profiles)
            }
            link("🌍", girl ? tr("שפה במכשיר שלה") : tr("שפה במכשיר שלו"),
                 value: lang.map { "\($0.flag) \($0.nativeName)" }) {
                ChildLanguageView(profileID: p.id, embedded: true)
                    .environmentObject(profiles)
            }
        } header: {
            Text(tr("📚 למידה"))
        }
        .glassRows()
    }

    /// 👤 Who the child is, and everything rare one step further in.
    private func profileSection(_ p: Profile) -> some View {
        // 🎓 The grade drives ALL curriculum content — flagged when it is missing
        // or when the CHILD picked it on their own device.
        let flagged = p.grade == nil || p.gradeSetByChild
        let grade: String = p.grade == nil
            ? tr("כיתה לא הוגדרה — הגדירו")
            : Profile.gradeNameForParent(p.effectiveGrade) + (p.gradeSetByChild ? " " + tr("· נבחרה ע\"י הילד — בדקו") : "")
        return Section {
            // The one editor with "שמירה" / "ביטול" — a form to fill, so it stays a sheet.
            row("✏️", tr("שם, גיל וכיתה"),
                value: "\(p.name) · \(p.age.label) · \(grade)",
                valueTint: flagged ? AppColor.flameOrange : GlassInk.secondary) { editing = p }
            link("🛠️", tr("עוד הגדרות"), value: tr("קוד, חברים, איפוס והסרה")) { morePage(p) }
        } header: {
            Text(tr("👤 פרופיל"))
        }
        .glassRows()
    }

    /// 📝 "רק שאלות רגילות" — a world opens straight into regular questions,
    /// without the game chooser. Synced to the child's device via ChildRecord.
    private func onlyQuestionsToggle(_ p: Profile) -> some View {
        Toggle(isOn: Binding(
            get: { profiles.profiles.first { $0.id == p.id }?.onlyRegularQuestions ?? false },
            set: { on in
                guard var fresh = profiles.profiles.first(where: { $0.id == p.id }),
                      fresh.onlyRegularQuestions != on else { return }
                Haptic.light()
                fresh.onlyRegularQuestions = on
                profiles.parentEdit(fresh)
            })) {
            HStack(spacing: 12) {
                Text("📝").font(.system(size: 20)).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("רק שאלות רגילות"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                    Text(tr("בלי מסך המשחקים: בחירת עולם מובילה ישר לשאלות"))
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(AppColor.successMint)
    }

    /// The base level the parent set — one name when every open topic shares
    /// it, "לפי נושא" when they differ. (The engine still adapts on top; the
    /// section below shows where it moved.)
    private func difficultySummary(_ p: Profile) -> String {
        let topics = p.playableTopics.isEmpty ? Set(Topic.allCases) : p.playableTopics
        let levels = Set(topics.map { p.difficulty(for: $0) })
        if levels.count == 1, let only = levels.first { return only.parentName }
        return tr("לפי נושא")
    }

    private func screenTimeSection(_ p: Profile) -> some View {
        let cap = p.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled, globalMax: settings.maxMinutesPerDay)
        return Section {
            link("⏳", tr("זמן מסך יומי"), value: cap.enabled ? tr("\(cap.minutes) דקות") : tr("ללא הגבלה")) {
                ChildScreenTimeView(profileID: p.id, embedded: true)
                    .environmentObject(profiles)
                    .environmentObject(settings)
            }
            // 🏫🌙 Hours when minutes don't open (QuietHours).
            link("🏫", tr("זמן בית ספר"), value: QuietHoursText.summary(p.quietHours, kind: .school)) {
                QuietHoursEditorView(profileID: profileID, kind: .school, embedded: true)
                    .environmentObject(profiles)
            }
            link("🌙", tr("שעת שינה"), value: QuietHoursText.summary(p.quietHours, kind: .bedtime)) {
                QuietHoursEditorView(profileID: profileID, kind: .bedtime, embedded: true)
                    .environmentObject(profiles)
            }
        } header: {
            Text(tr("⏱ זמן"))
        }
        .glassRows()
    }

    /// "המכשירים של X" — every device connected to this child: when it was last
    /// seen, whether its lock can work, remove it, connect another.
    private func devicesPage(_ p: Profile) -> some View {
        let devices = household.devicesByChild[p.id.uuidString] ?? []
        return Form {
            ForEach(devices) { d in
                Section {
                    // Not a PARENT's phone in Kid Mode: that row goes away by itself
                    // when Kid Mode ends, and removing it reset the parent's phone
                    // (the same liveness rule as the report's device list).
                    let removable = !household.parentDevices.contains(where: { $0.deviceID == d.deviceID && $0.lastSeenAt >= d.joinedAt })
                    // The device and its "הסרה" are ONE row — a separate full-width
                    // "הסר מכשיר" row under it read as a thing of its own (Rani, 2026-10-12).
                    HStack(spacing: 8) {
                        rowLabel(d.kind == "ipad" ? "📲" : "📱",
                                 (d.kind == "ipad" ? tr("אייפד") : tr("אייפון"))
                                    + ([tr("אייפד"), tr("אייפון"), "iPhone", "iPad", ""].contains(d.name) ? "" : " · \(d.name)"),
                                 value: Date().timeIntervalSince(d.lastSeenAt) < 120 ? tr("● מחובר") : tr("נראה \(Self.relative(d.lastSeenAt))"),
                                 valueTint: Date().timeIntervalSince(d.lastSeenAt) < 120 ? GlassInk.good : GlassInk.secondary,
                                 chevron: false)
                        if removable {
                            Button {
                                Haptic.light()
                                deviceToRemove = d
                            } label: {
                                Text(tr("הסרה"))
                                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(GlassInk.weak)
                                    .padding(.horizontal, 12).frame(minHeight: 36)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if d.shieldAuthorized == false, d.role != "parent" {
                        Label(tr("אין הרשאת ״זמן מסך״ במכשיר הזה — נעילת אפליקציות לא תעבוד בו. פתחו בו את טופי ← ⚙️ ← בקש הרשאה."),
                              systemImage: "exclamationmark.shield.fill")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColor.flameOrange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .glassRows()
            }
            if onConnectDevice != nil {
                Section {
                    row("🔗", tr("+ חיבור מכשיר נוסף"), chevron: false) { connectDevice(p) }
                }
                .glassRows()
            }
            // 🗑️ An action on the device, so it sits with the devices — it was a
            // stray row in the settings list (Rani, 2026-10-11).
            // Said in full: "לאפשר מחיקת אפליקציות (5 דק')" alone told a parent
            // nothing (Rani, 2026-10-12: "מי יבין מה זה אומר בכלל?").
            if !devices.isEmpty {
                Section {
                    row("🗑️", tr("לאפשר מחיקת אפליקציות ל-5 דקות"), chevron: false) { allowAppRemoval(p) }
                } footer: {
                    Text(tr("במכשיר של \(p.name) אי אפשר למחוק אפליקציות — כך טופי לא נמחק ממנו, בטעות או בכוונה. רוצים למחוק שם אפליקציה? לחצו כאן, ובמשך 5 דקות אפשר יהיה למחוק במכשיר. אחר כך המחיקה ננעלת שוב לבד."))
                }
                .glassRows()
            }
        }
        .readableColumn()
        .glassForm()
        .settingsDoneButton()
        .alert(tr("שליטה מרחוק"), isPresented: Binding(
            get: { remoteNote != nil },
            set: { if !$0 { remoteNote = nil } })) {
            Button(tr("הבנתי"), role: .cancel) {}
        } message: {
            Text(remoteNote ?? "")
        }
        // On THIS page, beside its rows (an alert on the root underneath never comes up).
        .alert(deviceToRemove.map { tr("להסיר את \"\($0.name)\"?") } ?? "",
               isPresented: Binding(get: { deviceToRemove != nil }, set: { if !$0 { deviceToRemove = nil } })) {
            Button(tr("הסר מכשיר"), role: .destructive) {
                if let d = deviceToRemove { household.removeChildDevice(id: d.id) }
                deviceToRemove = nil
            }
            Button(tr("ביטול"), role: .cancel) { deviceToRemove = nil }
        } message: {
            Text(tr("המכשיר יתנתק אוטומטית מהילד ויחזור למצב התחלתי (כאילו הותקן מחדש). ההתקדמות בענן נשמרת — כדי לחבר אותו שוב (או לילד אחר), סרקו בו מחדש את ה-QR של הילד הנכון."))
        }
        .navigationTitle(tr("המכשירים של \(p.name)"))
    }

    private static func relative(_ d: Date) -> String {
        let m = Int(Date().timeIntervalSince(d) / 60)
        if m < 60 { return tr("לפני \(max(1, m)) דק׳") }
        if m < 60 * 24 { return tr("לפני \(m / 60) שע׳") }
        return tr("לפני \(m / (60 * 24)) ימים")
    }

    /// "עוד הגדרות" — what a parent needs rarely: the child's play code,
    /// friends, questions-only, a data refresh, reset and deletion.
    private func morePage(_ p: Profile) -> some View {
        Form {
            Section {
                pinRow(p)
                row("👫", tr("חברים")) { friends = p }
                onlyQuestionsToggle(p)
            }
            .glassRows()
            Section {
                // Repair for a device that keeps re-uploading wrong numbers: tell
                // every device to drop its cached copy and take the cloud as-is.
                row("🔄", tr("רענון נתונים בכל המכשירים"), chevron: false) {
                    Haptic.warning()
                    RemoteSyncManager.shared.purgeChildCaches(childID: p.id)
                    moreNote = tr("נשלחה בקשת רענון לכל המכשירים של \(p.name). זה קורה בפתיחה הבאה של טופי בכל מכשיר.")
                }
                row("↩️", tr("איפוס התקדמות"), destructive: true, chevron: false) { confirmReset = true }
                // The ONE place a child is removed (David, 11.10: "כמה מקומות שמהם אפשר
                // למחוק ילד" — and "מחיקת הילדה" beside 🚮 read badly).
                row("❌", p.gender == .girl ? tr("הסרת הילדה מהמשפחה") : tr("הסרת הילד מהמשפחה"),
                    destructive: true, chevron: false) { confirmDelete = true }
            }
            .glassRows()
        }
        .readableColumn()
        .glassForm()
        // ⚠️ The confirmations live on THIS page, beside their rows. Attached to
        // the settings root underneath, the alert never came up from here —
        // "איפוס" did nothing at all (Eli, 9.10).
        .alert(tr("לאפס את ההתקדמות של \(p.name)?"), isPresented: $confirmReset) {
                Button(tr("אפס דקות + ניקוד"), role: .destructive) {
                    onResetProgress(p)
                    // "Sent", not "done": for a child with a device, that device
                    // performs the wipe (a refusal shows on the dashboard).
                    moreNote = tr("בקשת האיפוס של \(p.name) נשלחה. ההתקדמות תתאפס בכל המכשירים.")
                }
                Button(tr("בטל"), role: .cancel) {}
            } message: {
                Text(tr("פעולה זו תאפס דקות משחק שנצברו, ניקוד הסשן ועונש טעויות. לא יימחקו שמות, פרופילים או פריטי קוסמטיקה."))
            }
        .alert(tr("לאפס את קוד הגנת הזמן של \(p.name)?"), isPresented: $confirmPinReset) {
                Button(tr("אפס קוד"), role: .destructive) {
                    var updated = p
                    // "" (not nil) — deliberate-clear sentinel; survives sync merges.
                    updated.playPIN = ""
                    profiles.parentEdit(updated)
                }
                Button(tr("בטל"), role: .cancel) {}
            } message: {
                Text(tr("הקוד שהילד הגדיר לפתיחת זמן משחק יימחק. הילד יוכל להגדיר קוד חדש מהמכשיר שלו. שימושי כשהקוד נשכח."))
            }
        .alert(tr("להסיר את \(p.name) מהמשפחה?"), isPresented: $confirmDelete) {
                Button(tr("הסרה מהמשפחה"), role: .destructive) { onDelete(p) }
                Button(tr("בטל"), role: .cancel) {}
            } message: {
                Text(tr("כל הנתונים של \(p.name) יימחקו לצמיתות, ואי אפשר לשחזר אותם. מכשיר שמחובר לפרופיל הזה יתנתק."))
            }
        .alert(moreNote ?? "", isPresented: Binding(get: { moreNote != nil },
                                                    set: { if !$0 { moreNote = nil } })) {
            Button(tr("הבנתי"), role: .cancel) {}
        }
        .navigationTitle(tr("עוד הגדרות"))
        .navigationBarTitleDisplayMode(.inline)
        .settingsDoneButton()
        .environment(\.layoutDirection, .app)
    }

    /// 🔐 The child's play-protection code — the parent SEES it (to remind a
    /// forgetful kid) and can reset it.
    @ViewBuilder private func pinRow(_ p: Profile) -> some View {
        // Always shown (Rani looked for it and couldn't find it): before the
        // child picks one it says so instead of hiding the row.
        if !p.hasPlayPIN {
            HStack(spacing: 12) {
                Text("🔐").font(.system(size: 20)).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("קוד הגנת זמן המשחק"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                    Text(p.gender == .girl
                         ? tr("\(p.name) עוד לא בחרה קוד")
                         : tr("\(p.name) עוד לא בחר קוד"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
                Spacer(minLength: 4)
            }
        } else {
            HStack(spacing: 12) {
                Text("🔐").font(.system(size: 20)).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("קוד הגנת זמן המשחק"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                    Text(p.gender == .girl
                         ? tr("\(p.name) מזינה אותו כדי לפתוח את הדקות שצברה")
                         : tr("\(p.name) מזין אותו כדי לפתוח את הדקות שצבר"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Text(p.playPIN ?? "")
                    .font(.system(size: 19, weight: .heavy, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(GlassInk.primary)
                    .environment(\.layoutDirection, .leftToRight)
                Button(tr("אפס")) { confirmPinReset = true }
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .buttonStyle(.bordered)
                    .tint(.orange)
            }
        }
    }

    private func row(_ emoji: String, _ title: String, value: String? = nil,
                     valueTint: Color = GlassInk.secondary, destructive: Bool = false,
                     chevron: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            rowLabel(emoji, title, value: value, valueTint: valueTint, destructive: destructive, chevron: chevron)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(_ emoji: String, _ title: String, value: String? = nil,
                          valueTint: Color = GlassInk.secondary, destructive: Bool = false,
                          chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 20)).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(destructive ? GlassInk.weak : GlassInk.primary)
                if let value {
                    Text(value)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(valueTint)
                        .lineLimit(2).minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
            if chevron {
                Image(systemName: AppSymbol.forwardChevron)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GlassInk.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    /// Open a 5-minute app-deletion window on the child's device from afar —
    /// deletion is normally hard-blocked there (Screen Time denyAppRemoval).
    private func allowAppRemoval(_ p: Profile) {
        Haptic.medium()
        household.allowAppRemovalRemotely(toChildID: p.id)
        let connected = (household.devicesByChild[p.id.uuidString]?.isEmpty == false)
        remoteNote = connected
            ? tr("נפתח חלון של 5 דקות למחיקת אפליקציות במכשיר של \(p.name) — מיידי כשטופי פתוח שם. אחר כך הנעילה חוזרת לבד.")
            : tr("אין כרגע מכשיר מחובר ל\(p.name) — החלון ייפתח ברגע שהמכשיר יתחבר.")
    }

    // MARK: - Sheets (the same editors the old "⋯" menu opened)

    private func sheets<V: View>(_ content: V) -> some View {
        content
            .sheet(item: $editing) { p in
                ProfileEditorView(mode: .edit(p)) { updated in
                    profiles.parentEdit(updated)
                }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .app)
                .familyConnectionAlert()
            }
            .sheet(item: $friends) { p in
                ChildFriendsView(childID: p.id.uuidString, childName: p.name)
                    .environment(\.layoutDirection, .app)
                .familyConnectionAlert()
            }
            // 🔗 The pairing code, OVER the settings window.
            .sheet(item: pairing ?? .constant(nil)) { p in
                if let pairingSheet { pairingSheet(p) }
            }
    }
}
