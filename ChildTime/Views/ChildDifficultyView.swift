import SwiftUI

/// Parent-side editor for ONE child's per-topic question difficulty. Difficulty
/// is stored on the child's `Profile` and synced to their device via
/// `ChildRecord` (the parent's device is authoritative). The live question feed
/// still nudges the chosen level up/down a little based on the child's accuracy
/// (DDA) — this sets the *base* level.
struct ChildDifficultyView: View {
    @ObservedObject private var railHost = DisplayGeometry.shared
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
                    Text(tr("בחרו רמת קושי לכל נושא עבור \(profile?.name ?? tr("הילד")). השינוי מסתנכרן אוטומטית למכשיר של הילד."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .glassRows()

                Section {
                    HStack(spacing: 8) {
                        ForEach(Difficulty.allCases) { d in
                            Button {
                                applyToAll(d)
                            } label: {
                                Text(d.parentName)
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(tr("החל על כל הנושאים"))
                }
                .glassRows()

                Section {
                    ForEach(Topic.allCases.filter { !$0.isPack || profile?.allows($0) == true }) { topic in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(topic.emoji)
                                Text(topic.parentName)
                            }
                            Picker(tr("רמת קושי"), selection: binding(for: topic)) {
                                ForEach(Difficulty.allCases) { d in
                                    Text(d.parentName).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(tr("לפי נושא"))
                }
                .glassRows()
            }
            .readableColumn()
            .glassForm()
            .navigationTitle(tr("רמת קושי"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 🎚 The one way out lives in the rail on a foldable.
                if !railHost.hasRail {
                    ToolbarItem(placement: .awayFromBar(.confirmationAction, leading: false)) {
                        Button(tr("סיום")) { dismiss() }
                    }
                }
            }
        }
        // 🎚 Outside the NavigationStack and outside the readable-width
        // cap — otherwise the rail is drawn at the edge of the 600pt
        // column instead of the edge of the glass.
        .railDismiss(tr("סיום"), systemImage: "checkmark") { dismiss() }
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
