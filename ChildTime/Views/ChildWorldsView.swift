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
                    Text("בִּחֲרוּ אֵילוּ עוֹלָמוֹת פְּתוּחִים עֲבוּר \(profile?.name ?? "הַיֶּלֶד"). עוֹלָם כָּבוּי נֶעֱלָם מֵהַמָּסָךְ, וְהַיֶּלֶד לֹא מְקַבֵּל מִמֶּנּוּ שְׁאֵלוֹת. הַשִּׁנּוּי מִסְתַּנְכְרֵן אוֹטוֹמָטִית לַמַּכְשִׁיר שֶׁל הַיֶּלֶד.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .glassRows()

                Section {
                    // The bonus arena isn't a topic toggle — it mixes whatever
                    // topics are enabled here, so it has no row of its own.
                    ForEach(Worlds.all.filter { !$0.isBonusWorld && (!$0.topic.isPack || profile?.allows($0.topic) == true) }) { world in
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
                    Text("עוֹלָמוֹת פְּעִילִים")
                } footer: {
                    Text("\"טוֹפִי טַיים\" תָּמִיד פְּתוּחָה וּמַגִּישָׁה רַק מֵהַנּוֹשְׂאִים הַפְּעִילִים. חַיָּב לְהִשָּׁאֵר לְפָחוֹת עוֹלָם אֶחָד פָּתוּחַ.")
                }
                .glassRows()
            }
            .glassForm()
            .navigationTitle("עוֹלָמוֹת פְּעִילִים")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סִיּוּם") { dismiss() }
                }
            }
        }
    }

    private func binding(for world: World) -> Binding<Bool> {
        Binding(
            get: { profile?.allows(world.topic) ?? !world.topic.isPack },
            set: { on in
                guard var p = profile, !world.topic.isPack else { return }   // a bought pack stays on
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
