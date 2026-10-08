import SwiftUI

/// 📱 Parent settings on an iPad that ended up as the family's PARENT device:
/// "להפוך את האייפד הזה למכשיר של ילד". In production 3 of 16 families had the
/// shared iPad as their only parent device — the parent installed there first,
/// while the kid is the one using it. One tap moves the iPad to the child role
/// (same path as scanning the child's QR on a fresh device); the family, the
/// kids and their progress stay in the cloud. Reached only from Parent Settings,
/// which on a parent device already sits behind the root parent gate.
struct ConvertToChildDeviceView: View {
    /// Opened from a child's QR "connect a device" sheet → that child is chosen.
    var preselectedChildID: UUID? = nil
    /// Called once the device has switched — closes the presenting sheet(s).
    var onConverted: () -> Void

    @EnvironmentObject private var profiles: ProfileStore
    @ObservedObject private var household = HouseholdManager.shared
    @State private var selectedID: UUID?
    @State private var acknowledgedNoOtherParent = false
    @State private var working = false
    @State private var errorText: String?

    /// The household's children (the local roster, limited to kids the cloud
    /// family lists once it has loaded — no stale leftovers).
    private var children: [Profile] {
        let ids = Set(household.household?.childIDs ?? [])
        guard !ids.isEmpty else { return profiles.profiles }
        // (A child saved a moment ago may not be in the cloud list yet.)
        return profiles.profiles.filter { ids.contains($0.id.uuidString) || $0.id == preselectedChildID }
    }

    /// Another device that can still manage the family once this one is a
    /// child's. This install's own row is `parent_<installID>`.
    private var hasOtherParentDevice: Bool {
        // Only a parent device that is really someone else's counts: seen in the
        // last 30 days, and not an older row of THIS same iPad (a reinstall gets a
        // new install ID, and its old parent row stays behind — seen live, 2026-10-03,
        // where a stale row hid this warning on a family with no other parent device).
        let mine = "parent_\(DeviceIdentity.installID)"
        let recent = Date().addingTimeInterval(-30 * 86_400)
        return household.parentDevices.contains {
            $0.id != mine && $0.lastSeenAt > recent
                && !($0.kind == DeviceIdentity.kind && $0.name == DeviceIdentity.friendlyName)
        }
    }

    private var selectedChild: Profile? {
        children.first { $0.id == selectedID }
    }

    private var canConvert: Bool {
        selectedChild != nil && !working && (hasOtherParentDevice || acknowledgedNoOtherParent)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                childPicker
                if !hasOtherParentDevice { noOtherParentWarning }
                convertButton
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColor.almostWarm)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxl)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(GlassBackdrop())
        .navigationTitle(tr("מַכְשִׁיר שֶׁל יֶלֶד"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard selectedID == nil else { return }
            if let pre = preselectedChildID, children.contains(where: { $0.id == pre }) {
                selectedID = pre
            } else if children.count == 1 {
                selectedID = children.first?.id   // one child → nothing to choose
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("📱 → 🧒").font(.system(size: 34))
            Text(tr("לַהֲפֹךְ אֶת הָאַיְפֵּד הַזֶּה לְמַכְשִׁיר שֶׁל יֶלֶד"))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.primary)
                .multilineTextAlignment(.center)
            Text(tr("הָאַיְפֵּד יִתְנַתֵּק מֵחֶשְׁבּוֹן הַהוֹרֶה וְיִתְחַבֵּר כְּמַכְשִׁיר הַמִּשְׂחָק שֶׁל הַיֶּלֶד שֶׁתִּבְחֲרוּ. הַמִּשְׁפָּחָה, הַיְּלָדִים וְהַהִתְקַדְּמוּת נִשְׁמָרִים בֶּעָנָן."))
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassPane(radius: 16)
    }

    private var childPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("שֶׁל מִי הָאַיְפֵּד?"))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.primary)
            if children.isEmpty {
                Text(tr("עוֹד אֵין יְלָדִים בַּמִּשְׁפָּחָה. הוֹסִיפוּ יֶלֶד קֹדֶם, וְאָז חִזְרוּ לְכָאן."))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(children) { child in
                    let selected = child.id == selectedID
                    Button {
                        Haptic.light()
                        selectedID = child.id
                    } label: {
                        HStack(spacing: 12) {
                            Text(String(child.name.prefix(1)))
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.white.opacity(0.22)))
                                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                            Text(child.name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(GlassInk.primary)
                            Spacer(minLength: 0)
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(selected ? AppColor.starGold : GlassInk.tertiary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .glassInset(radius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPane(radius: 16)
    }

    /// No other parent device is registered — after the switch nobody could
    /// manage the family. Say so, show where to get Tofy on the iPhone (a local
    /// QR — this iPad's camera can't open a link for the iPhone anyway), and
    /// require an explicit "continue anyway".
    private var noOtherParentWarning: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text("⚠️").font(.system(size: 20))
                Text(tr("אֵין לַמִּשְׁפָּחָה מַכְשִׁיר הוֹרֶה נוֹסָף. קֹדֶם הַתְקִינוּ טוֹפִי בָּאַיְפוֹן וְהִתְחַבְּרוּ עִם אוֹתוֹ חֶשְׁבּוֹן, אַחֶרֶת לֹא תּוּכְלוּ לְנַהֵל."))
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .center, spacing: 12) {
                QRCodeView(text: ChildJoinView.appStoreURL, size: 96)
                    .accessibilityLabel(tr("קוֹד QR לְהוֹרָדַת טוֹפִי"))
                Text(tr("סִרְקוּ עִם הַמַּצְלֵמָה שֶׁל הָאַיְפוֹן כְּדֵי לְהוֹרִיד אֶת טוֹפִי"))
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $acknowledgedNoOtherParent) {
                Text(tr("הֵבַנְתִּי — לְהַמְשִׁיךְ בְּכָל זֹאת"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
            }
            .tint(AppColor.starGold)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPane(radius: 16, tint: AppColor.almostWarm)
    }

    private var convertButton: some View {
        Button {
            guard let child = selectedChild else { return }
            Haptic.medium()
            convert(to: child.id)
        } label: {
            Group {
                if working {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text(tr("מְחַבְּרִים…"))
                    }
                } else {
                    Text(selectedChild.map { tr("לַהֲפֹךְ לְמַכְשִׁיר שֶׁל \($0.name)") }
                         ?? tr("לַהֲפֹךְ אֶת הָאַיְפֵּד הַזֶּה לְמַכְשִׁיר שֶׁל יֶלֶד"))
                }
            }
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassFill(AppGradient.gold, radius: 16)
        }
        .buttonStyle(.juicy)
        .disabled(!canConvert)
        .opacity(canConvert || working ? 1 : 0.5)
        .padding(.top, 4)
    }

    private func convert(to childID: UUID) {
        working = true
        errorText = nil
        Task {
            let ok = await household.convertThisParentDeviceToChild(childID: childID)
            working = false
            if ok {
                Haptic.success()
                onConverted()
            } else {
                Haptic.warning()
                errorText = tr("לֹא הִצְלַחְנוּ לְהָכִין אֶת הַחִבּוּר. בִּדְקוּ אֶת הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב.")
            }
        }
    }
}
