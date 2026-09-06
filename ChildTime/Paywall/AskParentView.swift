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
    /// The world the child tapped (nil → a generic Tofy+ ask, e.g. from games).
    var world: World? = nil
    let onClose: () -> Void
    @State private var sent = false
    @State private var sending = false

    private var child: Profile? { ProfileStore.shared.active }
    private var isGirl: Bool { child?.gender == .girl }
    private func g(_ m: String, _ f: String) -> String { isGirl ? f : m }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            VStack(spacing: 18) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.22), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                    }
                    Spacer()
                }
                Spacer(minLength: 0)

                Text(world?.emoji ?? "👑").font(.system(size: 72))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                Text(world.map { "\(g("רוֹצֶה", "רוֹצָה")) לִלְמֹד \($0.topic.displayName)?" } ?? "טוֹפִי+")
                    .font(.system(size: world == nil ? 34 : 27, weight: .black, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .shadow(color: .black.opacity(0.18), radius: 7, y: 2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(world.map { "\($0.name) וְכָל הָעוֹלָמוֹת נִפְתָּחִים עִם טוֹפִי+ לְכָל הַמִּשְׁפָּחָה — וְאַבָּא אוֹ אִמָּא פּוֹתְחִים אֶת זֶה מֵהַטֶּלֶפוֹן שֶׁלָּהֶם." }
                     ?? "הַמִּשְׂחָקִים, הַזִּירָה, הַמַּטְלוֹת וְכָל הָעוֹלָמוֹת נִפְתָּחִים לְכָל הַמִּשְׁפָּחָה — וְאַבָּא אוֹ אִמָּא פּוֹתְחִים אֶת זֶה מֵהַטֶּלֶפוֹן שֶׁלָּהֶם.")
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
                    .foregroundStyle(Color(hex: "4B3FBF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.92)))
                    .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
                }
                .buttonStyle(.juicy)
                .disabled(sent)
                Text(sent ? "הֵם יְקַבְּלוּ הוֹדָעָה בַּטֶּלֶפוֹן 📱" : "הַבַּקָּשָׁה מַגִּיעָה יָשָׁר לַטֶּלֶפוֹן שֶׁל הַהוֹרֶה")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
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
        var fields: [String: Any] = ["premiumRequestedAt": Date().timeIntervalSince1970,
                                     "premiumRequestedBy": DeviceIdentity.friendlyName]
        // Which world the child wanted — the parent's banner and push say it.
        fields["premiumRequestedTopic"] = world?.topic.rawValue ?? FieldValue.delete()
        _ = await confirmedMerge(ref, fields)
        #endif
    }
}
