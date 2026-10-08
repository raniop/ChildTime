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

    var body: some View {
        NavigationStack {
            Form {
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
            .readableColumn()
            .glassForm()
            .navigationTitle(tr("שפה"))
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

    private func pick(_ lang: AppLanguage) {
        guard var p = profile, p.language != lang.rawValue else { return }
        p.language = lang.rawValue
        p.languageUpdatedAt = .now          // the stamp the merge compares
        profiles.update(p)
        Haptic.light()
    }
}
