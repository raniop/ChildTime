import SwiftUI
import Combine

// MARK: - Invite (existing parent shows a code)

/// The parent who ALREADY has the family taps "add a parent" and shows this:
/// a QR + code, with clear steps for what the other parent does. Detects when
/// the second parent joins and celebrates.
struct AddParentView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var code: String?
    @State private var working = false
    @State private var error: String?
    /// How many parents were linked when we opened — so we can detect a NEW join.
    @State private var baselineParents = 0
    @State private var justJoined = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: 0) {
                LinkHeader(title: "הוֹסָפַת הוֹרֶה") { dismiss() }
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if justJoined { joinedBanner } else { content }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            baselineParents = household.linkedParentSummaries.count
            if code == nil { generate() }
        }
        .onChangeCompat(of: household.linkedParentSummaries.count) { _, now in
            if now > baselineParents { withAnimation(.spring) { justJoined = true } }
        }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 8) {
            Text("👨‍👩‍👧‍👦").font(.system(size: 52))
            Text("הוֹסִיפוּ הוֹרֶה לַמִּשְׁפָּחָה")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("שְׁנֵיכֶם תִּרְאוּ אֶת אוֹתָם יְלָדִים וְאֶת אוֹתָהּ הַהִתְקַדְּמוּת.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }

        // ✉️ The friction-free path: pre-invite the co-parent's EMAIL — when
        // that email signs in (Apple/Google/email, whatever), it gets a
        // one-tap "המשפחה מחכה לך" join. No QR, no prior knowledge (Rani).
        emailInviteCard

        StepsCard(title: "אוֹ — בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה הַשֵּׁנִי:", steps: [
            "הַתְקִינוּ אֶת אַפְּלִיקַצְיַת טוֹפִי",
            "בְּמָסַךְ הַפְּתִיחָה הַקִּישׁוּ \u{201C}כְּבָר יֵשׁ לָכֶם מִשְׁפָּחָה? הִצְטָרְפוּ\u{201D}",
            "הִתְחַבְּרוּ, וְסִרְקוּ אֶת הַקּוֹד שֶׁכָּאן (אוֹ הַקְלִידוּ אוֹתוֹ)",
            // The joiner hits the parent-code gate right after — and nobody
            // told them a code exists. Say it here, to the person who KNOWS it
            // (verbally — a gate code doesn't belong in a WhatsApp message).
            "בַּכְּנִיסָה יִתְבַּקֵּשׁ קוֹד הַהוֹרֶה — מִסְרוּ לוֹ אֶת הַקּוֹד שֶׁלָּכֶם בְּעַל־פֶּה 🔑",
        ])

        codeCard
    }

    @ViewBuilder private var codeCard: some View {
        VStack(spacing: AppSpacing.md) {
            if let code {
                QRCodeView(text: code, size: 190)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                Text(code)
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .kerning(6)
                    .foregroundStyle(.white)
                ShareLink(item: "הִצְטָרְפוּ אֵלַי בְּטוֹפִי! קוֹד הַמִּשְׁפָּחָה: \(code)") {
                    Label("שִׁתּוּף הַקּוֹד", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                HStack(spacing: 6) {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text("מַמְתִּין שֶׁהַהוֹרֶה יִצְטָרֵף…")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 4)
            } else if working {
                ProgressView().tint(.white)
            } else if let error {
                Text(error).font(.caption).foregroundStyle(.white.opacity(0.8))
                Button("נַסּוּ שׁוּב") { generate() }.foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
        .environment(\.layoutDirection, .leftToRight)
    }

    @State private var inviteEmail = ""
    @State private var inviteSent = false
    @State private var inviting = false

    private var emailInviteCard: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("✉️ הַדֶּרֶךְ הַקַּלָּה: הַזְמִינוּ בְּאִימֵּיְל")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("הַהוֹרֶה הַשֵּׁנִי פָּשׁוּט יִתְחַבֵּר עִם הָאִימֵּיְל הַזֶּה — וְהַמִּשְׁפָּחָה תְּחַכֶּה לוֹ שָׁם, בְּלִי קוֹדִים.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            if inviteSent {
                Label("הַהַזְמָנָה נִשְׁמְרָה! אֶפְשָׁר לְהַזְמִין עוֹד אִימֵּיְל", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.successMint)
            }
            HStack(spacing: 8) {
                TextField("אִימֵּיְל שֶׁל הַהוֹרֶה הַשֵּׁנִי", text: $inviteEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .environment(\.layoutDirection, .leftToRight)
                Button {
                    guard !inviting else { return }
                    inviting = true
                    inviteSent = false
                    Task {
                        let ok = await HouseholdManager.shared.inviteParentByEmail(inviteEmail)
                        inviting = false
                        if ok { inviteSent = true; inviteEmail = ""; Haptic.success() }
                        else { Haptic.warning() }
                    }
                } label: {
                    if inviting { ProgressView().tint(.white) }
                    else {
                        Text("הַזְמִינוּ")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(AppGradient.gold, in: Capsule())
                .disabled(!inviteEmail.contains("@"))
                .opacity(inviteEmail.contains("@") ? 1 : 0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
    }

    private var joinedBanner: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🎉").font(.system(size: 64))
            Text("הוֹרֶה נוֹסָף לַמִּשְׁפָּחָה!")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("מֵעַכְשָׁיו שְׁנֵיכֶם רוֹאִים אֶת אוֹתָם הַיְּלָדִים.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button { dismiss() } label: {
                Text("סִיּוּם")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.success, in: Capsule())
            }
            .padding(.top, 6)
        }
        .padding(.top, 40)
    }

    private func generate() {
        Task {
            working = true; error = nil
            let c = await household.createInvite()
            code = c
            if c == nil { error = household.lastError ?? "לֹא נִיתָּן לִיצוֹר קוֹד כָּעֵת" }
            working = false
        }
    }
}

// MARK: - Join (new parent enters a code)

/// The NEW parent (who chose "join an existing family") sees this right after
/// sign-in: clear steps + a code entry / QR scan. On success they enter the
/// shared family; they can also choose to start their own family instead.
struct JoinFamilyFlowView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @EnvironmentObject private var settings: ParentSettings

    @State private var joinCode = ""
    @State private var working = false
    @State private var error: String?
    @State private var showScanner = false
    @State private var joined = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: 0) {
                LinkHeader(title: "הִצְטָרְפוּת לְמִשְׁפָּחָה", showClose: false) {}
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if joined { joinedBanner } else { content }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showScanner) { scannerSheet }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 8) {
            Text("🔗").font(.system(size: 52))
            Text("הִצְטָרְפוּ לְמִשְׁפָּחָה קַיֶּמֶת")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }

        StepsCard(title: "בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה שֶׁכְּבָר רָשׁוּם:", steps: [
            "פִּתְחוּ אֶת טוֹפִי → הַגְדָּרוֹת ⚙️",
            "הַקִּישׁוּ \u{201C}הוֹסִיפוּ הוֹרֶה\u{201D}",
            "יוֹפִיעַ קוֹד / QR — סִרְקוּ אוֹתוֹ כָּאן אוֹ הַקְלִידוּ:",
        ])

        // Scan + manual entry
        VStack(spacing: AppSpacing.md) {
            Button { showScanner = true } label: {
                Label("סִרְקוּ קוֹד QR", systemImage: "qrcode.viewfinder")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.purpleDream, in: Capsule())
            }

            Text("אוֹ הַקְלִידוּ אֶת הַקּוֹד").font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            TextField("", text: $joinCode, prompt: Text("6 תָּוִים").foregroundColor(.white.opacity(0.5)))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .kerning(6)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.12)))
                .environment(\.layoutDirection, .leftToRight)

            Button { JoinCoordinator.shared.present(joinCode) } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(.white) }
                    Text("הִצְטָרְפוּ")
                }
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(AppGradient.gold, in: Capsule())
            }
            .disabled(working || joinCode.trimmingCharacters(in: .whitespaces).count < 6)
            .opacity(joinCode.trimmingCharacters(in: .whitespaces).count < 6 ? 0.5 : 1)

            if let error {
                Text(error).font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.almostWarm).multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))

        Button {
            settings.pendingJoinFamily = false   // fall through to their own dashboard
        } label: {
            Text("אֵין לִי קוֹד — אֶצּוֹר מִשְׁפָּחָה מִשֶּׁלִּי")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85)).underline()
        }
        .padding(.top, 4)
    }

    private var joinedBanner: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🎉").font(.system(size: 64))
            Text("הִצְטָרַפְתֶּם לַמִּשְׁפָּחָה!")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("הַיְּלָדִים וְהַהִתְקַדְּמוּת יוֹפִיעוּ תּוֹךְ כַּמָּה שְׁנִיּוֹת.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
            Button { settings.pendingJoinFamily = false } label: {
                Text("הַמְשִׁיכוּ")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.success, in: Capsule())
            }
            .padding(.top, 6)
        }
        .padding(.top, 40)
    }

    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView { scanned in showScanner = false; JoinCoordinator.shared.present(scanned) }
                .ignoresSafeArea()
                .navigationTitle("סְרִיקַת קוֹד").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("בִּטּוּל") { showScanner = false } } }
        }
    }

    private func redeem(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return }
        Task {
            working = true; error = nil
            let ok = await household.redeemInvite(code: trimmed)
            if ok { Haptic.success(); withAnimation(.spring) { joined = true } }
            else { error = household.lastError ?? "קוֹד לֹא תָּקִין"; Haptic.warning() }
            working = false
        }
    }
}

// MARK: - Shared bits

// MARK: - Join coordinator (detect parent-vs-child on EVERY scan/code + confirm)

/// Every scanned QR / typed family-or-child code goes through here FIRST. It
/// looks up the invite to learn whether it's a CHILD-join code (`childID != nil`)
/// or a CO-PARENT family code, and `JoinConfirmView` shows a confirmation BEFORE
/// anything changes — and BLOCKS turning an existing parent device into a child
/// (the accident where a parent scanned a child QR and families got mixed).
@MainActor
final class JoinCoordinator: ObservableObject {
    static let shared = JoinCoordinator()

    @Published var active = false
    @Published private(set) var resolving = false
    @Published private(set) var resolved = false
    @Published private(set) var invite: Invite?     // after resolve: nil = invalid/expired
    private(set) var rawPayload = ""

    /// The bare invite code (drops the "|childID" suffix a scanned child QR adds).
    var code: String {
        String(rawPayload.split(separator: "|").first ?? Substring(rawPayload))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Entry point for ANY scan / typed code that might be a family/child code.
    func present(_ scanned: String) {
        rawPayload = JoinLink.payload(from: scanned)
        invite = nil; resolved = false; resolving = true; active = true
        Task {
            let inv = await HouseholdManager.shared.inspectInvite(code: code)
            invite = (inv?.isExpired == true) ? nil : inv
            resolving = false; resolved = true
        }
    }

    func dismiss() {
        active = false; rawPayload = ""
        invite = nil; resolved = false; resolving = false
    }

    /// DEMO only (screenshots): seed a resolved invite without hitting Firestore.
    func seedDemo(childCode: Bool) {
        rawPayload = "DEMO12"
        invite = Invite(id: "DEMO12", householdID: "demo", createdBy: "demo",
                        createdAt: Date(), expiresAt: Date().addingTimeInterval(3600),
                        redeemedBy: nil, childID: childCode ? "demo-child" : nil)
        resolving = false; resolved = true; active = true
    }
}

/// The always-on confirmation shown over everything when a code is scanned/typed.
struct JoinConfirmView: View {
    @ObservedObject private var coord = JoinCoordinator.shared
    @ObservedObject private var household = HouseholdManager.shared
    @EnvironmentObject private var settings: ParentSettings
    @State private var working = false
    @State private var note: String?
    @State private var joined = false

    private var isParentDevice: Bool { settings.deviceRole == .parent }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 14, size: 12)
            VStack(spacing: AppSpacing.lg) { content }
                .padding(AppSpacing.xl)
                .frame(maxWidth: 440).frame(maxWidth: .infinity)
            if let note {
                VStack { Spacer()
                    Text(note).font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColor.almostWarm).multilineTextAlignment(.center)
                        .padding(.bottom, AppSpacing.xl)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder private var content: some View {
        if coord.resolving || working {
            ProgressView().tint(.white).scaleEffect(1.3)
            Text(working ? "מְחַבְּרִים…" : "בּוֹדְקִים אֶת הַקּוֹד…")
                .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        } else if joined {
            panel(emoji: "🎉", title: "הִצְטָרַפְתֶּם לַמִּשְׁפָּחָה!",
                  body: "הַיְּלָדִים וְהַהִתְקַדְּמוּת יוֹפִיעוּ תּוֹךְ כַּמָּה שְׁנִיּוֹת.") {
                primaryButton("הַמְשִׁיכוּ") { settings.pendingJoinFamily = false; coord.dismiss() }
            }
        } else if coord.invite == nil {
            panel(emoji: "⚠️", title: "הַקּוֹד לֹא תָּקִין",
                  body: "הַקּוֹד שֶׁסָּרַקְתֶּם לֹא נִמְצָא אוֹ פָּג תּוֹקֶף. בַּקְּשׁוּ קוֹד חָדָשׁ וְנַסּוּ שׁוּב.") {
                secondaryButton("סְגִירָה") { coord.dismiss() }
            }
        } else if let inv = coord.invite, inv.childID != nil {
            if isParentDevice {
                // ⚠️ THE ACCIDENT: a parent device must NOT become a child.
                panel(emoji: "🛑", title: "אִי אֶפְשָׁר לְהוֹסִיף הוֹרֶה כְּיֶלֶד",
                      body: "לַמַּכְשִׁיר הַזֶּה כְּבָר יֵשׁ מִשְׁפָּחָה מִשֶּׁלְּךָ, וְהַקּוֹד שֶׁסָּרַקְתָּ הוּא קוֹד שֶׁל יֶלֶד.\n\nכְּדֵי לְהוֹסִיף הוֹרֶה נוֹסָף — בַּמַּכְשִׁיר שֶׁלּוֹ: הַגְדָּרוֹת ⚙️ ← \u{201C}הוֹסִיפוּ הוֹרֶה\u{201D}, וְסִרְקוּ אֶת הַקּוֹד שֶׁמּוֹפִיעַ.") {
                    secondaryButton("הֵבַנְתִּי") { coord.dismiss() }
                }
            } else {
                panel(emoji: "🎮", title: "לְחַבֵּר אֶת הַמַּכְשִׁיר הַזֶּה כְּמַכְשִׁיר שֶׁל יֶלֶד?",
                      body: "הַמַּכְשִׁיר הַזֶּה יֵהָפֵךְ לְמַכְשִׁיר הַמִּשְׂחָק שֶׁל הַיֶּלֶד וְיִתְחַבֵּר לַמִּשְׁפָּחָה. אֶפְשָׁר תָּמִיד לְשַׁנּוֹת בַּהַגְדָּרוֹת.") {
                    primaryButton("כֵּן, חַבְּרוּ") {
                        settings.deviceRole = .child
                        settings.pendingJoinPayload = coord.rawPayload
                        coord.dismiss()
                    }
                    secondaryButton("בִּטּוּל") { coord.dismiss() }
                }
            }
        } else {
            // CO-PARENT family code.
            panel(emoji: "👨‍👩‍👧‍👦", title: "לְהִצְטָרֵף לַמִּשְׁפָּחָה כְּהוֹרֶה?",
                  body: "תִּהְיוּ הוֹרֶה נוֹסָף בַּמִּשְׁפָּחָה וְתִרְאוּ אֶת אוֹתָם הַיְּלָדִים וְאֶת אוֹתָהּ הַהִתְקַדְּמוּת.") {
                primaryButton("כֵּן, הִצְטָרְפוּ") { joinAsCoParent() }
                secondaryButton("בִּטּוּל") { coord.dismiss() }
            }
        }
    }

    private func joinAsCoParent() {
        Task {
            working = true; note = nil
            let ok = await household.redeemInvite(code: coord.code, bringLocalChildren: true)
            working = false
            if ok { Haptic.success(); withAnimation(.spring) { joined = true } }
            else { note = household.lastError ?? "לֹא הִצְלַחְנוּ לְהִצְטָרֵף"; Haptic.warning() }
        }
    }

    // MARK: building blocks

    @ViewBuilder
    private func panel<Buttons: View>(emoji: String, title: String, body: String,
                                      @ViewBuilder buttons: () -> Buttons) -> some View {
        Text(emoji).font(.system(size: 64))
        Text(title).font(.system(size: 23, weight: .heavy, design: .rounded))
            .foregroundStyle(.white).multilineTextAlignment(.center)
        Text(body).font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        VStack(spacing: 10) { buttons() }.padding(.top, 6)
    }

    private func primaryButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.medium(); action() } label: {
            Text(title).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(AppGradient.gold, in: Capsule()).glow(AppColor.starGold, radius: 10)
        }
    }

    private func secondaryButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.light(); action() } label: {
            Text(title).font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(.white.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }
}

private struct LinkHeader: View {
    let title: String
    var showClose: Bool = true
    let onClose: () -> Void
    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppColor.starGold.opacity(0.6), radius: 8)
            if showClose {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(.white.opacity(0.18), in: Circle())
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.md)
    }
}

private struct StepsCard: View {
    let title: String
    let steps: [String]
    var body: some View {
        // leading == right in this RTL screen — number on the right, text
        // right-aligned beside it.
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle().fill(AppColor.starGold).frame(width: 26, height: 26)
                        Text("\(i + 1)").font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text(step)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
    }
}
