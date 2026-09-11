import SwiftUI

/// Parent-side editor for ONE child: which worlds/topics are open. Stored on the
/// child's `Profile` (`enabledTopics`) and synced to their device via
/// `ChildRecord`. Turning a world OFF hides its card on the home screen AND stops
/// the Smart Feed from serving that topic — so a parent who doesn't want English
/// just switches it off. At least one world must stay open.
struct ChildWorldsView: View {
    @EnvironmentObject private var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID

    /// Read the live profile each render so edits + cloud echoes stay reflected.
    private var profile: Profile? {
        profiles.profiles.first(where: { $0.id == profileID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(tr("בִּחֲרוּ אֵילוּ עוֹלָמוֹת פְּתוּחִים עֲבוּר \(profile?.name ?? tr("הַיֶּלֶד")). עוֹלָם כָּבוּי נֶעֱלָם מֵהַמָּסָךְ, וְהַיֶּלֶד לֹא מְקַבֵּל מִמֶּנּוּ שְׁאֵלוֹת. הַשִּׁנּוּי מִסְתַּנְכְרֵן אוֹטוֹמָטִית לַמַּכְשִׁיר שֶׁל הַיֶּלֶד."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .glassRows()

                Section {
                    // The bonus arena isn't a topic toggle — it mixes whatever
                    // topics are enabled here, so it has no row of its own.
                    // Base worlds always; a pack world when the family HAS it (bought or
                    // Tofy+) and the founder switched it on — even if this child's switch is off.
                    ForEach(Worlds.all.filter { w in
                        guard !w.isBonusWorld, ContentAvailability.hasContent(w.topic) else { return false }
                        guard let pack = w.topic.pack else { return true }
                        return profile.map { PackAccess.has($0, pack) } == true
                            && PackStore.shared.visiblePacks.contains { $0.id == pack.id }
                    }) { world in
                        Toggle(isOn: binding(for: world)) {
                            HStack(spacing: 10) {
                                Text(world.emoji).font(.title3)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(world.name)
                                    Text(world.topic.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text(tr("עוֹלָמוֹת פְּעִילִים"))
                } footer: {
                    Text(tr("\"טוֹפִי טַיים\" תָּמִיד פְּתוּחָה וּמַגִּישָׁה רַק מֵהַנּוֹשְׂאִים הַפְּעִילִים. חַיָּב לְהִשָּׁאֵר לְפָחוֹת עוֹלָם אֶחָד פָּתוּחַ."))
                }
                .glassRows()
            }
            .glassForm()
            .navigationTitle(tr("עוֹלָמוֹת פְּעִילִים"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("סִיּוּם")) { dismiss() }
                }
            }
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
                    profiles.update(p); Haptic.light(); return
                }
                if on {
                    p.enabledTopics.insert(world.topic)
                    profiles.update(p)
                    Haptic.light()
                } else {
                    // Never let the parent close the last world — the toggle just
                    // springs back (the getter still reports it on).
                    guard p.enabledTopics.count > 1 else { Haptic.soft(); return }
                    p.enabledTopics.remove(world.topic)
                    profiles.update(p)
                    Haptic.light()
                }
            }
        )
    }
}
