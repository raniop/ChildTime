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
            return tr("\(profile.name) \(g(tr("מתקדם"),tr("מתקדמת"))) יפה ב\(raised.displayName), אז המערכת התחילה להוסיף שאלות מעט מאתגרות יותר.")
        }
        if let eased = topics.first(where: { state(for: $0, profile: profile, snapshot: s).direction == .eased }) {
            return tr("ב\(eased.displayName) המערכת הורידה מעט את הקושי כדי לבנות ביטחון והצלחה.")
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
    /// Owned by the dashboard: the local + cloud wipe and its refresh.
    var onResetProgress: (Profile) -> Void
    /// Owned by the dashboard: removes the child, closes this sheet and pops the page.
    var onDelete: (Profile) -> Void

    @State private var editing: Profile? = nil
    @State private var language: Profile? = nil
    @State private var difficulty: Profile? = nil
    @State private var worlds: Profile? = nil
    @State private var screenTime: Profile? = nil
    @State private var friends: Profile? = nil
    @State private var confirmPinReset = false
    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var remoteNote: String? = nil

    private var profile: Profile? { profiles.profiles.first { $0.id == profileID } }

    var body: some View {
        NavigationStack {
            Group {
                if let p = profile {
                    dialogs(sheets(form(p)), p)
                } else {
                    Color.clear.background(GlassBackdrop())
                }
            }
            .navigationTitle(profile.map { tr("הַגְדָּרוֹת שֶׁל \($0.name)") } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 🎚 The one way out lives in the rail on a foldable.
                if !railHost.hasBarStrip {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("סִיּוּם")) { dismiss() }
                    }
                }
            }
        }
        .railDismiss(tr("סִיּוּם"), systemImage: "checkmark") { dismiss() }
        .environment(\.layoutDirection, .app)
    }

    // MARK: - The list

    private func form(_ p: Profile) -> some View {
        Form {
            childSection(p)
            learningSection(p)
            smartDifficultySection(p)
            screenTimeSection(p)
            Section {
                row("👫", tr("חֲבֵרִים")) { friends = p }
            }
            .glassRows()
            advancedSection(p)
        }
        .readableOnWideShort()
        .glassForm()
    }

    private func childSection(_ p: Profile) -> some View {
        let girl = p.gender == .girl
        // 🎓 The grade drives ALL curriculum content — flagged when it is missing
        // or when the CHILD picked it on their own device.
        let flagged = p.grade == nil || p.gradeSetByChild
        let grade: String = p.grade == nil
            ? tr("כיתה לא הוגדרה — הגדירו")
            : Profile.gradeDisplayName(p.effectiveGrade) + (p.gradeSetByChild ? " " + tr("· נבחרה ע\"י הילד — בדקו") : "")
        let lang = p.language.flatMap(AppLanguage.init(rawValue:))
        return Section {
            row("✏️", tr("שֵׁם, גִּיל וְכִתָּה"),
                value: "\(p.name) · \(p.age.label) · \(grade)",
                valueTint: flagged ? AppColor.flameOrange : GlassInk.secondary) { editing = p }
            row("🌍", girl ? tr("שָׂפָה בַּמַּכְשִׁיר שֶׁלָּהּ") : tr("שָׂפָה בַּמַּכְשִׁיר שֶׁלּוֹ"),
                value: lang.map { "\($0.flag) \($0.nativeName)" }) { language = p }
        } header: {
            Text(girl ? tr("הַיַּלְדָּה") : tr("הַיֶּלֶד"))
        }
        .glassRows()
    }

    private func learningSection(_ p: Profile) -> some View {
        let listed = ChildWorldsView.listedWorlds(for: p)
        let open = listed.filter { p.allows($0.topic) }.count
        return Section {
            row("🎚️", tr("רָמַת קֹשִׁי"), value: difficultySummary(p)) { difficulty = p }
            row("🌐", tr("עוֹלָמוֹת פְּעִילִים"),
                value: listed.isEmpty ? nil : tr("\(open) מִתּוֹךְ \(listed.count)")) { worlds = p }
        } header: {
            Text(tr("לְמִידָה"))
        }
        .glassRows()
    }

    /// The base level the parent set — one name when every open topic shares
    /// it, "לפי נושא" when they differ. (The engine still adapts on top; the
    /// section below shows where it moved.)
    private func difficultySummary(_ p: Profile) -> String {
        let topics = p.playableTopics.isEmpty ? Set(Topic.allCases) : p.playableTopics
        let levels = Set(topics.map { p.difficulty(for: $0) })
        if levels.count == 1, let only = levels.first { return only.displayName }
        return tr("לְפִי נוֹשֵׂא")
    }

    /// "רמת קושי חכמה" — the adaptive engine's current level per practiced
    /// topic and where it moved (moved here from the old child card).
    @ViewBuilder
    private func smartDifficultySection(_ p: Profile) -> some View {
        let topics = AdaptiveTopicLevel.practicedTopics(profile: p, snapshot: snapshot)
        if AdaptiveTopicLevel.hasSignal(snapshot), !topics.isEmpty {
            Section {
                ForEach(topics) { topic in
                    let st = AdaptiveTopicLevel.state(for: topic, profile: p, snapshot: snapshot)
                    HStack(spacing: 8) {
                        Text("\(topic.emoji) \(topic.displayName)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.primary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        if let dir = st.direction { directionChip(dir) }
                        Text(st.served.displayName)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(GlassInk.primary)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.16)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    }
                }
            } header: {
                Text(tr("רמת קושי חכמה"))
            } footer: {
                if let sentence = AdaptiveTopicLevel.sentence(for: topics, profile: p, snapshot: snapshot) {
                    Text(sentence)
                }
            }
            .glassRows()
        }
    }

    private func directionChip(_ dir: AdaptiveTopicLevel.Direction) -> some View {
        let raised = dir == .raised
        return Text(raised ? "↑ " + tr("מְאַתְגֵּר יוֹתֵר") : "↓ " + tr("בּוֹנֶה בִּטָּחוֹן"))
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(raised ? GlassInk.good : GlassInk.warn)
            .lineLimit(1).minimumScaleFactor(0.8)
    }

    private func screenTimeSection(_ p: Profile) -> some View {
        let cap = p.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled, globalMax: settings.maxMinutesPerDay)
        return Section {
            row("⏳", tr("זְמַן מָסָךְ יוֹמִי"),
                value: cap.enabled ? tr("\(cap.minutes) דַּקּוֹת") : tr("לְלֹא הַגְבָּלָה")) { screenTime = p }
            // The child's play-protection code — full parental transparency: the
            // parent SEES the code (to remind a forgetful kid) and can reset it.
            // Always shown (Rani looked for it and couldn't find it): before the
            // child picks one it says so instead of hiding the row.
            if !p.hasPlayPIN {
                HStack(spacing: 12) {
                    Text("🔐").font(.system(size: 20)).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("קוֹד הַגָּנַת זְמַן הַמִּשְׂחָק"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.primary)
                        Text(p.gender == .girl
                             ? tr("\(p.name) עוֹד לֹא בָּחֲרָה קוֹד")
                             : tr("\(p.name) עוֹד לֹא בָּחַר קוֹד"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(GlassInk.secondary)
                    }
                    Spacer(minLength: 4)
                }
            } else {
                HStack(spacing: 12) {
                    Text("🔐").font(.system(size: 20)).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("קוֹד הַגָּנַת זְמַן הַמִּשְׂחָק"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.primary)
                        Text(p.gender == .girl
                             ? tr("\(p.name) מַזִּינָה אוֹתוֹ כְּדֵי לִפְתֹּחַ אֶת הַדַּקּוֹת שֶׁצָּבְרָה")
                             : tr("\(p.name) מַזִּין אוֹתוֹ כְּדֵי לִפְתֹּחַ אֶת הַדַּקּוֹת שֶׁצָּבַר"))
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
        } header: {
            Text(tr("זְמַן מָסָךְ"))
        }
        .glassRows()
    }

    private func advancedSection(_ p: Profile) -> some View {
        Section {
            row("🗑️", tr("לְאַפְשֵׁר מְחִיקַת אַפְּלִיקַצְיוֹת (5 דַּק')"), chevron: false) { allowAppRemoval(p) }
            // Repair for a device that keeps re-uploading wrong numbers: tell
            // every device to drop its cached copy and take the cloud as-is.
            row("🔄", tr("רַעֲנוּן נְתוּנִים בְּכָל הַמַּכְשִׁירִים"), chevron: false) {
                Haptic.warning()
                RemoteSyncManager.shared.purgeChildCaches(childID: p.id)
            }
            row("↩️", tr("אִפּוּס הִתְקַדְּמוּת"), destructive: true, chevron: false) { confirmReset = true }
            row("🚮", p.gender == .girl ? tr("מְחִיקַת הַיַּלְדָּה") : tr("מְחִיקַת הַיֶּלֶד"),
                destructive: true, chevron: false) { confirmDelete = true }
        } header: {
            Text(tr("מִתְקַדֵּם"))
        }
        .glassRows()
    }

    private func row(_ emoji: String, _ title: String, value: String? = nil,
                     valueTint: Color = GlassInk.secondary, destructive: Bool = false,
                     chevron: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
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
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    /// Open a 5-minute app-deletion window on the child's device from afar —
    /// deletion is normally hard-blocked there (Screen Time denyAppRemoval).
    private func allowAppRemoval(_ p: Profile) {
        Haptic.medium()
        household.allowAppRemovalRemotely(toChildID: p.id)
        let connected = (household.devicesByChild[p.id.uuidString]?.isEmpty == false)
        remoteNote = connected
            ? tr("נִפְתָּח חַלּוֹן שֶׁל 5 דַּקּוֹת לִמְחִיקַת אַפְּלִיקַצְיוֹת בַּמַּכְשִׁיר שֶׁל \(p.name) — מִיָּדִי כְּשֶׁטּוֹפִי פָּתוּחַ שָׁם. אַחַר כָּךְ הַנְּעִילָה חוֹזֶרֶת לְבַד.")
            : tr("אֵין כָּרֶגַע מַכְשִׁיר מְחֻבָּר לְ\(p.name) — הַחַלּוֹן יִפָּתַח בָּרֶגַע שֶׁהַמַּכְשִׁיר יִתְחַבֵּר.")
    }

    // MARK: - Sheets (the same editors the old "⋯" menu opened)

    private func sheets<V: View>(_ content: V) -> some View {
        content
            .sheet(item: $editing) { p in
                ProfileEditorView(mode: .edit(p)) { updated in
                    profiles.update(updated)
                } onDelete: { removed in
                    editing = nil
                    onDelete(removed)
                }
                .environmentObject(profiles)
                .environment(\.layoutDirection, .app)
            }
            .sheet(item: $language) { p in
                ChildLanguageView(profileID: p.id)
                    .environmentObject(profiles)
                    .environment(\.layoutDirection, .app)
            }
            .sheet(item: $difficulty) { p in
                ChildDifficultyView(profileID: p.id)
                    .environmentObject(profiles)
                    .environment(\.layoutDirection, .app)
            }
            .sheet(item: $worlds) { p in
                ChildWorldsView(profileID: p.id)
                    .environmentObject(profiles)
                    .environment(\.layoutDirection, .app)
            }
            .sheet(item: $screenTime) { p in
                ChildScreenTimeView(profileID: p.id)
                    .environmentObject(profiles)
                    .environmentObject(settings)
                    .environment(\.layoutDirection, .app)
            }
            .sheet(item: $friends) { p in
                ChildFriendsView(childID: p.id.uuidString, childName: p.name)
                    .environment(\.layoutDirection, .app)
            }
    }

    // MARK: - Confirmations (moved here with their rows)

    private func dialogs<V: View>(_ content: V, _ p: Profile) -> some View {
        content
            .alert(tr("לאפס את ההתקדמות של \(p.name)?"), isPresented: $confirmReset) {
                Button(tr("אפס דקות + ניקוד"), role: .destructive) { onResetProgress(p) }
                Button(tr("בטל"), role: .cancel) {}
            } message: {
                Text(tr("פעולה זו תאפס דקות משחק שנצברו, ניקוד הסשן ועונש טעויות. לא יימחקו שמות, פרופילים או פריטי קוסמטיקה."))
            }
            .alert(tr("לאפס את קוד הגנת הזמן של \(p.name)?"), isPresented: $confirmPinReset) {
                Button(tr("אפס קוד"), role: .destructive) {
                    var updated = p
                    // "" (not nil) — deliberate-clear sentinel; survives sync merges.
                    updated.playPIN = ""
                    profiles.update(updated)
                }
                Button(tr("בטל"), role: .cancel) {}
            } message: {
                Text(tr("הקוד שהילד הגדיר לפתיחת זמן משחק יימחק. הילד יוכל להגדיר קוד חדש מהמכשיר שלו. שימושי כשהקוד נשכח."))
            }
            .alert(tr("למחוק את \(p.name)?"), isPresented: $confirmDelete) {
                Button(tr("מְחִיקַת יֶלֶד/ה"), role: .destructive) { onDelete(p) }
                Button(tr("בטל"), role: .cancel) {}
            } message: {
                Text(tr("הילד/ה והנתונים שלו יימחקו מהמשפחה לצמיתות. תוכלו ליצור אותו מחדש בכל עת. מכשיר שמחובר לילד הזה יתנתק."))
            }
            .alert(tr("שְׁלִיטָה מֵרָחוֹק"), isPresented: Binding(
                get: { remoteNote != nil },
                set: { if !$0 { remoteNote = nil } })) {
                Button(tr("הֵבַנְתִּי"), role: .cancel) {}
            } message: {
                Text(remoteNote ?? "")
            }
    }
}
