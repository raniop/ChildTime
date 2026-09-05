import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// What a CHILD's device shows where the parent's device shows the paywall.
///
/// Rani: the subscription is per FAMILY and is bought ONCE, on a parent's phone —
/// it then unlocks every child device through `Household.premiumUntil`. So a
/// child device never sells anything: no prices, no StoreKit, no parent gate
/// to type a code into while the kid watches. It says what Tofy+ opens, and lets
/// the child send a nudge to the parent's phone.
///
/// Kids Category: this also keeps commerce entirely off the child's surface.
struct AskParentView: View {
    let onClose: () -> Void
    @State private var sent = false
    @State private var sending = false

    private var child: Profile? { ProfileStore.shared.active }
    private var isGirl: Bool { child?.gender == .girl }
    private func g(_ m: String, _ f: String) -> String { isGirl ? f : m }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 18, size: 12)

            VStack(spacing: 18) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .glassPane(radius: 19, shadow: false)
                    }
                    Spacer()
                }
                Spacer(minLength: 0)

                Text("👑").font(.system(size: 72))
                    .shadow(color: AppColor.starGold.opacity(0.7), radius: 24)
                Text("טוֹפִי+")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("הַמִּשְׂחָקִים, הַזִּירָה, הַמַּטְלוֹת וְכָל הָעוֹלָמוֹת נִפְתָּחִים לְכָל הַמִּשְׁפָּחָה — וְאַבָּא אוֹ אִמָּא פּוֹתְחִים אֶת זֶה מֵהַטֶּלֶפוֹן שֶׁלָּהֶם.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 10) {
                    perk("🎮", "מִשְׂחָקִים וְזִירַת הָעֲנָקִים")
                    perk("🌍", "כָּל הָעוֹלָמוֹת — בְּלִי גְּבוּלוֹת")
                    perk("🧹", "מַטְלוֹת הַבַּיִת עִם פְּרָסִים")
                    perk("👨‍👩‍👧", "פַּעַם אַחַת — לְכָל הַמַּכְשִׁירִים בַּמִּשְׁפָּחָה")
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .glassPane(radius: 22)

                Spacer(minLength: 0)

                // The one thing the child can DO here: tell a parent.
                Button {
                    guard !sent, !sending else { return }
                    Haptic.success()
                    sending = true
                    Task { await sendRequest(); sending = false; sent = true }
                } label: {
                    HStack(spacing: 10) {
                        if sending { ProgressView().tint(AppColor.textOnLight) }
                        Text(sent ? "נִשְׁלַח לְאַבָּא וּלְאִמָּא ✅" : "\(g("בַּקֵּשׁ", "בַּקְּשִׁי")) מֵאַבָּא אוֹ אִמָּא 💌")
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(AppColor.textOnLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [.white, Color(hex: "FFE9A3")],
                                               startPoint: .top, endPoint: .bottom), in: Capsule())
                    .glow(AppColor.starGold, radius: 14)
                }
                .buttonStyle(.juicy)
                .disabled(sent)
                Text(sent ? "הֵם יְקַבְּלוּ הוֹדָעָה בַּטֶּלֶפוֹן 📱" : "הַבַּקָּשָׁה מַגִּיעָה יָשָׁר לַטֶּלֶפוֹן שֶׁל הַהוֹרֶה")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 520)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func perk(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 22))
            Text(text).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }

    /// Stamps `premiumRequestedAt` on the child doc. The parent's dashboard
    /// listens to the child docs already, so this surfaces there as
    /// "🦁 יואב רוצה טופי+" and wakes the parent's phone via the existing
    /// command push. Confirmed write, per [[command-delivery-certainty]].
    private func sendRequest() async {
        #if canImport(FirebaseFirestore)
        guard let id = child?.id else { return }
        let ref = Firestore.firestore().collection("children").document(id.uuidString)
        _ = await confirmedMerge(ref, ["premiumRequestedAt": Date().timeIntervalSince1970,
                                       "premiumRequestedBy": DeviceIdentity.friendlyName])
        #endif
    }
}
