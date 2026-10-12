import SwiftUI

/// Parent-side editor for ONE child: which worlds/topics are open. Stored on the
/// child's `Profile` (`enabledTopics`) and synced to their device via
/// `ChildRecord`. Turning a world OFF hides its card on the home screen AND stops
/// the Smart Feed from serving that topic — so a parent who doesn't want English
/// just switches it off. At least one world must stay open.
struct ChildWorldsView: View {
    @ObservedObject private var railHost = DisplayGeometry.shared
    @EnvironmentObject private var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID

    /// Read the live profile each render so edits + cloud echoes stay reflected.
    private var profile: Profile? {
        profiles.profiles.first(where: { $0.id == profileID })
    }

    @Environment(\.closeSettings) private var closeSettings
    /// Pushed inside the settings window (see `SettingsStack`) — no stack and
    /// no "סיום" of its own there.
    var embedded = false
    /// "סיום": alone it closes this sheet; inside the settings window, the whole window.
    private func close() { if embedded, let closeSettings { closeSettings() } else { dismiss() } }

    var body: some View {
        SettingsStack(embedded: embedded) {
            Form {
                SettingsBandHeader(title: tr("עולמות פעילים"), active: embedded)
                Section {
                    Text(tr("בחרו אילו עולמות פתוחים עבור \(profile?.name ?? tr("הילד")). עולם כבוי נעלם מהמסך, והילד לא מקבל ממנו שאלות. השינוי מסתנכרן אוטומטית למכשיר של הילד."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .glassRows()

                Section {
                    // The bonus arena isn't a topic toggle — it mixes whatever
                    // topics are enabled here, so it has no row of its own.
                    // Base worlds always; a pack world when the family HAS it (bought or
                    // Tofy+) and the founder switched it on — even if this child's switch is off.
                    ForEach(Self.listedWorlds(for: profile)) { world in
                        Toggle(isOn: binding(for: world)) {
                            HStack(spacing: 10) {
                                Text(world.emoji).font(.title3)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(world.name)
                                    Text(world.topic.parentName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text(tr("עולמות פעילים"))
                } footer: {
                    Text(tr("\"טופי טיים\" תמיד פתוחה ומגישה רק מהנושאים הפעילים. חייב להישאר לפחות עולם אחד פתוח."))
                }
                .glassRows()
            }
            .readableColumn(form: true)
            .glassForm()
            .navigationTitle(tr("עולמות פעילים"))
            .navigationBarTitleDisplayMode(.inline)
            .settingsBand(active: embedded)
            .toolbar {
                // 🎚 The one way out lives in the rail on a foldable.
                // Pushed inside the settings window the page has ONE button, the back
                // arrow — "סיום" beside it read as a second way out (Rani, 2026-10-12).
                if !railHost.hasRail, !embedded {
                    ToolbarItem(placement: .awayFromBar(.confirmationAction, leading: false)) {
                        Button(tr("סיום")) { close() }
                    }
                }
            }
        }
        // 🎚 Outside the NavigationStack and outside the readable-width
        // cap — otherwise the rail is drawn at the edge of the 600pt
        // column instead of the edge of the glass.
        .railDismiss(unless: embedded, tr("סיום"), systemImage: "checkmark") { close() }
    }

    /// The worlds this editor lists — also counted on the child's settings
    /// page ("5 מִתּוֹךְ 7").
    static func listedWorlds(for profile: Profile?) -> [World] {
        Worlds.all.filter { w in
            guard !w.isBonusWorld, ContentAvailability.hasContent(w.topic) else { return false }
            guard let pack = w.topic.pack else { return true }
            return profile.map { PackAccess.has($0, pack) } == true
                && PackStore.shared.visiblePacks.contains { $0.id == pack.id }
        }
    }

    private func binding(for world: World) -> Binding<Bool> {
        Binding(
            get: { profile?.allows(world.topic) ?? !world.topic.isPack },
            set: { on in
                guard var p = profile else { return }
                if let pack = world.topic.pack {
                    // A pack: the parent's per-child switch (the family keeps the pack).
                    if on { p.disabledPacks.remove(pack.id) } else { p.disabledPacks.insert(pack.id) }
                    profiles.parentEdit(p); Haptic.light(); return
                }
                if on {
                    p.enabledTopics.insert(world.topic)
                    profiles.parentEdit(p)
                    Haptic.light()
                } else {
                    // Never let the parent close the last world — the toggle just
                    // springs back (the getter still reports it on).
                    guard p.enabledTopics.count > 1 else { Haptic.soft(); return }
                    p.enabledTopics.remove(world.topic)
                    profiles.parentEdit(p)
                    Haptic.light()
                }
            }
        )
    }
}
