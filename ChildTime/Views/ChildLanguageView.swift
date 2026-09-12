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
                    Text(tr("בִּחֲרוּ בְּאֵיזוֹ שָׂפָה טוֹפִי יוֹפִיעַ בַּמַּכְשִׁיר שֶׁל \(profile?.name ?? tr("הַיֶּלֶד")). הַשִּׁנּוּי מַגִּיעַ לַמַּכְשִׁיר בַּסִּנְכְרוּן הַבָּא."))
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
                    Text(tr("שָׂפַת הָאַפְּלִיקַצְיָה אֵצֶל הַיֶּלֶד"))
                } footer: {
                    Text(tr("הַשָּׂפָה מְשַׁנָּה גַּם אֶת הַשְּׁאֵלוֹת, לֹא רַק אֶת הַטֶּקְסְטִים. אִם תְּשַׁנּוּ אוֹתָהּ בַּמַּכְשִׁיר שֶׁל הַיֶּלֶד עַצְמוֹ — הַבְּחִירָה הָאַחֲרוֹנָה קוֹבַעַת."))
                }
                .glassRows()
            }
            .glassForm()
            .navigationTitle(tr("שָׂפָה"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("סִיּוּם")) { dismiss() }
                }
            }
        }
    }

    private func pick(_ lang: AppLanguage) {
        guard var p = profile, p.language != lang.rawValue else { return }
        p.language = lang.rawValue
        p.languageUpdatedAt = .now          // the stamp the merge compares
        profiles.update(p)
        Haptic.light()
    }
}
