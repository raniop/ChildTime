import SwiftUI

/// Parent-side editor for ONE child's daily screen-time cap. Stored on the
/// child's `Profile` (`dailyCapMinutes`) and synced to their device via
/// `ChildRecord` — so the parent controls it from THEIR device, per child.
/// 0 = unlimited.
struct ChildScreenTimeView: View {
    @EnvironmentObject private var profiles: ProfileStore
    @EnvironmentObject private var settings: ParentSettings
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID

    private var profile: Profile? {
        profiles.profiles.first(where: { $0.id == profileID })
    }

    private let options = [0, 15, 30, 45, 60, 90, 120]

    /// Currently-selected minutes (0 = unlimited). Falls back to the device global
    /// (default 60) until the parent picks a per-child value.
    private var current: Int {
        if let m = profile?.dailyCapMinutes { return max(0, m) }
        return settings.dailyCapEnabled ? settings.maxMinutesPerDay : 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("בִּחֲרוּ כַּמָּה דַּקּוֹת מָסָךְ בְּיוֹם עֲבוּר \(profile?.name ?? "הַיֶּלֶד"). הַשִּׁנּוּי מִסְתַּנְכְרֵן אוֹטוֹמָטִית לַמַּכְשִׁיר שֶׁל הַיֶּלֶד.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(options, id: \.self) { m in
                        Button {
                            set(m)
                        } label: {
                            HStack {
                                Text(m == 0 ? "לְלֹא הַגְבָּלָה ♾️" : "\(m) דַּקּוֹת בְּיוֹם")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if current == m {
                                    Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.bold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("מַקְסִימוּם זְמַן מָסָךְ יוֹמִי")
                } footer: {
                    Text("הַיֶּלֶד מַרְוִיחַ עַד הַתִּקְרָה הַזּוֹ בִּלְמִידָה. בּוֹנוּסִים מֵהַגַּלְגַּל/קֻפְסָה נִשְׁמָרִים לְמָחָר כְּשֶׁמַּגִּיעִים לַתִּקְרָה.")
                }
            }
            .navigationTitle("זְמַן מָסָךְ יוֹמִי")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סִיּוּם") { dismiss() }
                }
            }
        }
    }

    private func set(_ minutes: Int) {
        guard var p = profile else { return }
        p.dailyCapMinutes = minutes
        profiles.update(p)
        Haptic.light()
    }
}
