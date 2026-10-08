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
                LinkHeader(title: tr("הוספת הורה")) { dismiss() }
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
        .environment(\.layoutDirection, .app)
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
            Text(tr("הוסיפו הורה למשפחה"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("שניכם תראו את אותם הילדים ואת אותה ההתקדמות."))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }

        // ✉️ The friction-free path: pre-invite the co-parent's EMAIL — when
        // that email signs in (Apple/Google/email, whatever), it gets a
        // one-tap "המשפחה מחכה לך" join. No QR, no prior knowledge (Rani).
        emailInviteCard

        StepsCard(title: tr("או — במכשיר של ההורה השני:"), steps: [
            tr("התקינו את אפליקצית טופי"),
            tr("במסך הפתיחה הקישו \u{201C}כבר יש לכם משפחה? הצטרפו\u{201D}"),
            tr("התחברו, וסרקו את הקוד שכאן (או הקלידו אותו)"),
            // The joiner hits the parent-code gate right after — and nobody
            // told them a code exists. Say it here, to the person who KNOWS it
            // (verbally — a gate code doesn't belong in a WhatsApp message).
            tr("בכניסה יתבקש קוד ההורה — מסרו לו את הקוד שלכם בעלפה 🔑"),
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
                ShareLink(item: tr("הצטרפו אלי בטופי! קוד המשפחה: \(code)")) {
                    Label(tr("שתוף הקוד"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                HStack(spacing: 6) {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text(tr("ממתין שההורה יצטרף…"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 4)
            } else if working {
                ProgressView().tint(.white)
            } else if let error {
                Text(error).font(.caption).foregroundStyle(.white.opacity(0.8))
                Button(tr("נסו שוב")) { generate() }.foregroundStyle(.white)
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
            Text(tr("✉️ הדרך הקלה: הזמינו באימיל"))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("ההורה השני פשוט יתחבר עם האימיל הזה — והמשפחה תחכה לו שם, בלי קודים."))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            if inviteSent {
                Label(tr("ההזמנה נשמרה! אפשר להזמין עוד אימיל"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.successMint)
            }
            HStack(spacing: 8) {
                TextField(tr("אימיל של ההורה השני"), text: $inviteEmail)
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
                        Text(tr("הזמינו"))
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
            Text(tr("הורה נוסף למשפחה!"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("מעכשיו שניכם רואים את אותם הילדים."))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button { dismiss() } label: {
                Text(tr("סיום"))
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
            if c == nil { error = household.lastError ?? tr("לא ניתן ליצור קוד כעת") }
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
                LinkHeader(title: tr("הצטרפות למשפחה"), showClose: false) {}
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
        .environment(\.layoutDirection, .app)
        .sheet(isPresented: $showScanner) { scannerSheet }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 8) {
            Text("🔗").font(.system(size: 52))
            Text(tr("הצטרפו למשפחה קימת"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }

        StepsCard(title: tr("במכשיר של ההורה שכבר רשום:"), steps: [
            tr("פתחו את טופי → הגדרות ⚙️"),
            tr("הקישו \u{201C}הוסיפו הורה\u{201D}"),
            tr("יופיע קוד / QR — סרקו אותו כאן או הקלידו:"),
        ])

        // Scan + manual entry
        VStack(spacing: AppSpacing.md) {
            Button { showScanner = true } label: {
                Label(tr("סרקו קוד QR"), systemImage: "qrcode.viewfinder")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.purpleDream, in: Capsule())
            }

            Text(tr("או הקלידו את הקוד")).font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            TextField("", text: $joinCode, prompt: Text(tr("6 תוים")).foregroundColor(.white.opacity(0.5)))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)   // Latin code on a Hebrew-only keyboard (see ChildJoinView)
                .multilineTextAlignment(.center)
                // Spaced monospace only for the code itself — the Arabic placeholder
                // broke into isolated letters under it.
                .font(.system(size: 26, weight: .heavy, design: joinCode.isEmpty ? .rounded : .monospaced))
                .kerning(joinCode.isEmpty ? 0 : 6)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.12)))
                .environment(\.layoutDirection, .leftToRight)

            Button { JoinCoordinator.shared.present(joinCode) } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(.white) }
                    Text(tr("הצטרפו"))
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
            Text(tr("אין לי קוד — אצור משפחה משלי"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85)).underline()
        }
        .padding(.top, 4)
    }

    private var joinedBanner: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🎉").font(.system(size: 64))
            Text(tr("הצטרפתם למשפחה!"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("הילדים וההתקדמות יופיעו תוך כמה שניות."))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
            Button { settings.pendingJoinFamily = false } label: {
                Text(tr("המשיכו"))
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
                .navigationTitle(tr("סריקת קוד")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(tr("בטול")) { showScanner = false } } }
        }
    }

    private func redeem(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return }
        Task {
            working = true; error = nil
            let ok = await household.redeemInvite(code: trimmed)
            if ok { Haptic.success(); withAnimation(.spring) { joined = true } }
            else { error = household.lastError ?? tr("קוד לא תקין"); Haptic.warning() }
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
            // 🧭 A CHILD code typed or scanned on a device that already chose
            // "המכשיר של הילד": the question "לחבר את המכשיר הזה כמכשיר של ילד?"
            // only repeated that choice (seen in the new-parent walk-through).
            // Join straight away. The guard against a PARENT device turning
            // into a child is untouched — that one still asks.
            if invite?.childID != nil, ParentSettings.shared.deviceRole == .child {
                ParentSettings.shared.pendingJoinPayload = rawPayload
                dismiss()
            }
        }
    }

    func dismiss() {
        // Only close. Clearing `invite` here re-rendered the cover — while it was
        // still sliding away — as "הקוד לא תקין" (no invite = invalid), the flash
        // Rani saw on every successful child join. `present` resets it all anyway.
        active = false
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
        .environment(\.layoutDirection, .app)
    }

    @ViewBuilder private var content: some View {
        if coord.resolving || working {
            ProgressView().tint(.white).scaleEffect(1.3)
            Text(working ? tr("מחברים…") : tr("בודקים את הקוד…"))
                .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        } else if joined {
            panel(emoji: "🎉", title: tr("הצטרפתם למשפחה!"),
                  body: tr("הילדים וההתקדמות יופיעו תוך כמה שניות.")) {
                primaryButton(tr("המשיכו")) { settings.pendingJoinFamily = false; coord.dismiss() }
            }
        } else if coord.invite == nil {
            panel(emoji: "⚠️", title: tr("הקוד לא תקין"),
                  body: tr("הקוד שסרקתם לא נמצא או פג תוקף. בקשו קוד חדש ונסו שוב.")) {
                secondaryButton(tr("סגירה")) { coord.dismiss() }
            }
        } else if let inv = coord.invite, inv.childID != nil {
            if isParentDevice {
                // ⚠️ THE ACCIDENT: a parent device must NOT become a child.
                panel(emoji: "🛑", title: tr("אי אפשר להוסיף הורה כילד"),
                      body: tr("למכשיר הזה כבר יש משפחה משלך, והקוד שסרקת הוא קוד של ילד.\n\nכדי להוסיף הורה נוסף — במכשיר שלו: הגדרות ⚙️ ← \u{201C}הוסיפו הורה\u{201D}, וסרקו את הקוד שמופיע.")) {
                    secondaryButton(tr("הבנתי")) { coord.dismiss() }
                }
            } else {
                panel(emoji: "🎮", title: tr("לחבר את המכשיר הזה כמכשיר של ילד?"),
                      body: tr("המכשיר הזה יהפך למכשיר המשחק של הילד ויתחבר למשפחה. אפשר תמיד לשנות בהגדרות.")) {
                    primaryButton(tr("כן, חברו")) {
                        settings.deviceRole = .child
                        settings.pendingJoinPayload = coord.rawPayload
                        coord.dismiss()
                    }
                    secondaryButton(tr("בטול")) { coord.dismiss() }
                }
            }
        } else if settings.deviceRole == .child {
            // ⚠️ THE MIRROR ACCIDENT: a CHILD device scanned a PARENT family code
            // (e.g. from the co-parent share). Joining as a parent would put the
            // child's anonymous uid on parentUIDs and stream strangers' kids.
            panel(emoji: "🛑", title: tr("זה קוד של הורה"),
                  body: tr("המכשיר הזה הוא מכשיר של ילד. כדי לחבר אותו למשפחה — בקשו מההורה קוד ילד מהדשבורד.")) {
                secondaryButton(tr("הבנתי")) { coord.dismiss() }
            }
        } else {
            // CO-PARENT family code.
            panel(emoji: "👨‍👩‍👧‍👦", title: tr("להצטרף למשפחה כהורה?"),
                  body: tr("תהיו הורה נוסף במשפחה ותראו את אותם הילדים ואת אותה ההתקדמות.")) {
                primaryButton(tr("כן, הצטרפו")) { joinAsCoParent() }
                secondaryButton(tr("בטול")) { coord.dismiss() }
            }
        }
    }

    private func joinAsCoParent() {
        Task {
            working = true; note = nil
            let ok = await household.redeemInvite(code: coord.code, bringLocalChildren: true)
            working = false
            if ok { Haptic.success(); withAnimation(.spring) { joined = true } }
            else { note = household.lastError ?? tr("לא הצלחנו להצטרף"); Haptic.warning() }
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
                    .environment(\.layoutDirection, .appMirrored)
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
