import SwiftUI

/// Parent-side editor for ONE child's app language.
///
/// A Russian-speaking parent sets up the child's iPad; the child is six and will
/// not go find a language setting. So the choice lives on the child's `Profile`
/// (`language`) and syncs to their device via `ChildRecord`, exactly like the
/// daily cap and the per-topic difficulty.
///
/// It is not a one-way remote control: the picker on the child's own device
/// writes the same field back, stamped. Whoever pressed last wins — see
/// `Profile.languageUpdatedAt` and `ProfileStore.mergeRemoteChildren`.
struct ChildLanguageView: View {
    @ObservedObject private var railHost = DisplayGeometry.shared
    @EnvironmentObject private var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID

    private var profile: Profile? {
        profiles.profiles.first(where: { $0.id == profileID })
    }
    /// nil on the record → the child's device keeps whatever it already shows.
    private var chosen: AppLanguage? {
        profile?.language.flatMap(AppLanguage.init(rawValue:))
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
                SettingsBandHeader(title: tr("שפה"), active: embedded)
                Section {
                    Text(tr("בחרו באיזו שפה טופי יופיע במכשיר של \(profile?.name ?? tr("הילד")). השינוי מגיע למכשיר בסנכרון הבא."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .glassRows()

                Section {
                    ForEach(AppLanguage.allCases) { lang in
                        Button { pick(lang) } label: {
                            HStack(spacing: 12) {
                                Text(lang.flag).font(.system(size: 24))
                                Text(lang.nativeName)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer(minLength: 0)
                                if lang == chosen {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(AppColor.successMint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(lang == chosen ? .isSelected : [])
                    }
                } header: {
                    Text(tr("שפת האפליקציה אצל הילד"))
                } footer: {
                    Text(tr("השפה משנה גם את השאלות, לא רק את הטקסטים. אם תשנו אותה במכשיר של הילד עצמו — הבחירה האחרונה קובעת."))
                }
                .glassRows()
            }
            .readableColumn(form: true)
            .glassForm()
            .navigationTitle(tr("שפה"))
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

    private func pick(_ lang: AppLanguage) {
        guard var p = profile, p.language != lang.rawValue else { return }
        p.language = lang.rawValue
        p.languageUpdatedAt = .now          // the stamp the merge compares
        profiles.parentEdit(p)
        Haptic.light()
    }
}
