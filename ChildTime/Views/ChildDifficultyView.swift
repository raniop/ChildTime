import SwiftUI

/// Parent-side editor for ONE child's per-topic question difficulty. Difficulty
/// is stored on the child's `Profile` and synced to their device via
/// `ChildRecord` (the parent's device is authoritative). The live question feed
/// still nudges the chosen level up/down a little based on the child's accuracy
/// (DDA) — this sets the *base* level.
struct ChildDifficultyView: View {
    @EnvironmentObject private var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID

    /// Always read the live profile from the store so edits + cloud echoes stay
    /// reflected while the sheet is open.
    private var profile: Profile? {
        profiles.profiles.first(where: { $0.id == profileID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("בִּחֲרוּ רָמַת קֹשִׁי לְכָל נוֹשֵׂא עֲבוּר \(profile?.name ?? "הַיֶּלֶד"). הַשִּׁנּוּי מִסְתַּנְכְרֵן אוֹטוֹמָטִית לַמַּכְשִׁיר שֶׁל הַיֶּלֶד.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(Difficulty.allCases) { d in
                            Button {
                                applyToAll(d)
                            } label: {
                                Text(d.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                        }
                    }
                } header: {
                    Text("הַחֵל עַל כָּל הַנּוֹשְׂאִים")
                }

                Section {
                    ForEach(Topic.allCases) { topic in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(topic.emoji)
                                Text(topic.displayName)
                            }
                            Picker("רָמַת קֹשִׁי", selection: binding(for: topic)) {
                                ForEach(Difficulty.allCases) { d in
                                    Text(d.displayName).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("לְפִי נוֹשֵׂא")
                }
            }
            .navigationTitle("רָמַת קֹשִׁי")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סִיּוּם") { dismiss() }
                }
            }
        }
    }

    // MARK: - Editing

    private func binding(for topic: Topic) -> Binding<Difficulty> {
        Binding(
            get: { profile?.difficulty(for: topic) ?? .easy },
            set: { newValue in
                guard var p = profile else { return }
                p.difficultyByTopic[topic.rawValue] = newValue.rawValue
                profiles.update(p)
                Haptic.light()
            }
        )
    }

    private func applyToAll(_ d: Difficulty) {
        guard var p = profile else { return }
        for topic in Topic.allCases {
            p.difficultyByTopic[topic.rawValue] = d.rawValue
        }
        profiles.update(p)
        Haptic.success()
    }
}
