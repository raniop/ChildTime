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
    /// The child's synced progress — with it, each topic also shows what the
    /// engine SERVES right now. The choice and its effect sit in one place
    /// (they were two: a "רמת קושי" row and a separate "רמת קושי חכמה" list).
    var snapshot: ProgressSnapshot? = nil

    /// Always read the live profile from the store so edits + cloud echoes stay
    /// reflected while the sheet is open.
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
                SettingsBandHeader(title: tr("רמת קושי"), active: embedded)
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
                                Spacer(minLength: 4)
                                servedChips(topic)
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
                } footer: {
                    if servedExplained {
                        Text(tr("הבחירה היא נקודת ההתחלה. טופי מעלה ומוריד מעט בכל נושא לפי התשובות — התווית ליד שם הנושא מראה מה מוגש עכשיו."))
                    }
                }
                .glassRows()
            }
            .readableColumn(form: true)
            .glassForm()
            .navigationTitle(tr("רמת קושי"))
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

    // MARK: - What the engine serves now

    /// Whether any topic has enough answers for the engine to have moved.
    private var servedExplained: Bool {
        guard let snapshot else { return false }
        return AdaptiveTopicLevel.hasSignal(snapshot)
    }

    /// "↑ מאתגר יותר · קשה" beside a practiced topic whose served level moved
    /// away from the parent's choice.
    @ViewBuilder private func servedChips(_ topic: Topic) -> some View {
        if let snapshot, let profile, (snapshot.topicGradeStretch?[topic.rawValue] ?? 0) > 0 {
            // 🚀 Past the top of the parent's choice: questions from the grade above.
            Text("🚀 " + tr("שאלות של \(Profile.gradeNameForParent(profile.effectiveGrade + 1))"))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "3A2700"))
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
        } else if let snapshot, let profile, AdaptiveTopicLevel.hasSignal(snapshot),
           (snapshot.topicAnswered[topic.rawValue] ?? 0) >= 1 {
            let st = AdaptiveTopicLevel.state(for: topic, profile: profile, snapshot: snapshot)
            if let dir = st.direction {
                let raised = dir == .raised
                Text(raised ? "↑ " + tr("מאתגר יותר") : "↓ " + tr("בונה ביטחון"))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(raised ? GlassInk.good : GlassInk.warn)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(st.served.parentName)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
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
                profiles.parentEdit(p)
                Haptic.light()
            }
        )
    }

    private func applyToAll(_ d: Difficulty) {
        guard var p = profile else { return }
        for topic in Topic.allCases {
            p.difficultyByTopic[topic.rawValue] = d.rawValue
        }
        profiles.parentEdit(p)
        Haptic.success()
    }
}
