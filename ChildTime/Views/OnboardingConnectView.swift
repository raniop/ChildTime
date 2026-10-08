import SwiftUI

/// 🧭 Step ③ → ④ of the new-parent flow, on the PARENT's phone: the QR for the
/// child's phone, a live "waiting for the scan" line, and — the moment the
/// child's phone joins — the same screen turns into "✓ נועה מחוברת" and waits
/// for the last step, approving Screen Time on her phone. When that device
/// reports the grant (`ChildDevice.shieldAuthorized`, ~15s heartbeat) the flow
/// ends by itself with `onLocked`.
///
/// The old QR sheet closed two seconds after the scan and said nothing about
/// the lock, so a parent walked away from a child's phone that locked nothing.
/// Parent side: no niqqud.
struct OnboardingConnectView: View {
    let child: Profile
    let onLocked: () -> Void
    let onLater: () -> Void

    @ObservedObject private var household = HouseholdManager.shared
    @State private var qrCode: String?
    @State private var linked = false
    @State private var ended = false

    private var name: String { Question.stripNiqqud(child.name) }
    private var girl: Bool { child.gender == .girl }

    private var childDevices: [ChildDevice] {
        (household.devicesByChild[child.id.uuidString] ?? []).filter { $0.role != "parent" }
    }
    private var lockApproved: Bool { childDevices.contains { $0.shieldAuthorized == true } }

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            SparkleField(count: 14, size: 12)
            VStack(spacing: DisplayGeometry.shared.isShort ? 10 : 16) {
                // The steps bar sits exactly where it sits on every other step…
                OnboardingStepsBar(current: linked ? 4 : 3)
                    .padding(.top, 8)
                // …and the page under it is ONE column beside the foldable's
                // clock, everything centred in it (Rani: "עקום").
                // If the page is taller than the glass it scrolls under the bar —
                // it never pushes the bar up (the bar sits at the same height on
                // every step).
                ViewThatFits(in: .vertical) {
                    page
                    ScrollView { page }.scrollIndicators(.hidden)
                }
            }
        }
        .environment(\.layoutDirection, .app)
        .task(id: child.id) {
            if AppInfo.isDemoRun {
                qrCode = "8QWRKE"
                linked = ProcessInfo.processInfo.environment["DEMO_LINKED"] == "1"
                return
            }
            if !childDevices.isEmpty { linked = true; return }
            qrCode = await household.makeChildJoinCode(for: child.id.uuidString)
            if let code = qrCode { household.watchInviteRedemption(payload: code) }
        }
        .onChangeCompat(of: household.redeemedInviteCode) { _, redeemed in
            guard redeemed != nil, !linked else { return }
            Haptic.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { linked = true }
        }
        // A device can also land through the live listener before the
        // redemption watch fires (or after a relaunch) — either way it is linked.
        .onChangeCompat(of: childDevices.count) { _, n in
            guard n > 0, !linked else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { linked = true }
        }
        .onChangeCompat(of: lockApproved) { _, ok in
            guard ok, !ended else { return }
            ended = true
            Haptic.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onLocked() }
        }
        .onDisappear { household.stopWatchingInviteRedemption() }
    }

    /// How far the column's centre sits from the glass's centre on the
    /// foldable, as an offset in the CURRENT layout direction.
    static var glassCentreShift: CGFloat {
        let d = DisplayGeometry.shared
        guard d.hasBarStrip else { return 0 }
        let physical = (d.barOnLeft ? -1 : 1) * d.barInset / 2      // + = toward the right
        return LayoutDirection.app == .rightToLeft ? -physical : physical
    }

    private var page: some View {
        Group { if linked { linkedBody } else { qrBody } }
            .padding(.horizontal, OnboardingFooter.sidePadding)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
    }

    // MARK: ③ — the QR

    private var qrBody: some View {
        VStack(spacing: DisplayGeometry.shared.isShort ? 9 : 14) {
            // Centred in the middle of the page, like a person would place it.
            Spacer(minLength: 0)
            Text(tr("חיבור הטלפון של \(name)"))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1).minimumScaleFactor(0.8)
                // Everything centred on the whole glass, like the lock step (Rani).
                .padding(.horizontal, DisplayGeometry.shared.hasBarStrip ? DisplayGeometry.shared.barInset : 0)
                .padding(.top, DisplayGeometry.shared.isShort ? 18 : 0)
            VStack(alignment: .leading, spacing: 7) {
                step(1, tr("בטלפון של \(name): מורידים את טופי מה-App Store"))
                step(2, tr("פותחים, בוחרים \"המכשיר של הילד\" וסורקים את הקוד"))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPane(radius: 16)
            // Full width — so it starts below the foldable's clock.
            .padding(.top, DisplayGeometry.shared.hasBarStrip ? 16 : 0)

            VStack(spacing: 10) {
                if let code = qrCode {
                    // A short screen (the closed foldable) takes a smaller code so
                    // the whole step fits — it was pushed off the top.
                    QRCodeView(text: JoinLink.url(forPayload: code), size: DisplayGeometry.shared.isShort ? 116 : 190)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
                    Text(String(code.split(separator: "|").first ?? ""))
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .kerning(4)
                        .foregroundStyle(.white)
                } else {
                    ProgressView().tint(.white).scaleEffect(1.3).frame(width: 214, height: 214)
                }
            }

            waitingPill(girl ? tr("מחכים שתסרקו בטלפון של \(name)…") : tr("מחכים שתסרקו בטלפון של \(name)…"))

            ShareLink(item: URL(string: "https://apps.apple.com/app/id6773805449")!) {
                Label(tr("שליחת טופי לטלפון של \(name)"), systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.14)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            Spacer(minLength: 4)
            laterFooter(tr("אחבר אחר כך"))
        }
    }

    // MARK: ④ — linked, waiting for the lock on the child's phone

    private var linkedBody: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 84))
                .foregroundStyle(AppColor.successMint)
                .glow(AppColor.successMint, radius: 16)
            Text(girl ? tr("\(name) מחוברת!") : tr("\(name) מחובר!"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("צעד אחרון, בטלפון של \(name):\nלאשר זמן מסך כדי שהנעילה תעבוד"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            waitingPill(tr("מחכים לאישור בטלפון של \(name)…"))
            Text(tr("המסך הזה יתעדכן לבד כשתסיימו שם"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 8)
            laterFooter(tr("אמשיך אחר כך"))
        }
    }

    // MARK: Bits

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(n)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "2A1E5C"))
                .frame(width: 24, height: 24)
                .background(Circle().fill(AppColor.starGold))
            Text(text)
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func waitingPill(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().tint(.white).scaleEffect(0.8)
            Text(text)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Capsule().fill(.white.opacity(0.16)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }

    /// No gold button while waiting on the other phone — only the link, in
    /// the very row the link takes on every other screen of the flow.
    private func laterFooter(_ text: String) -> some View {
        VStack(spacing: 12) {
            Color.clear.frame(height: 56)
            laterButton(text).frame(height: 20)
        }
        .padding(.bottom, 10)
    }

    private func laterButton(_ text: String) -> some View {
        Button {
            Haptic.light()
            guard !ended else { return }
            ended = true
            onLater()
        } label: {
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .underline()
        }
        .buttonStyle(.plain)
    }
}

/// 🧒 The end of the home tour for a child who plays on the parent's phone:
/// "let her try it now?" (Rani: "להציע לו… בוא תיתן לילד לשחק דרך המכשיר שלך
/// כרגע, ושתראה איך זה נראה").
struct PlayNowOfferView: View {
    let child: Profile
    let onPlay: () -> Void
    let onLater: () -> Void

    private var name: String { Question.stripNiqqud(child.name) }
    private var girl: Bool { child.gender == .girl }

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            SparkleField(count: 12, size: 11)
            VStack(spacing: 14) {
                Spacer(minLength: 8)
                Text("🧒").font(.system(size: 64))
                Text(tr("תנו ל\(name) לשחק עכשיו?"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(girl ? tr("היא תשחק בטלפון שלכם במצב ילד, ותראו בדיוק איך זה נראה אצלה. כדי לצאת — הקוד שלכם.")
                          : tr("הוא ישחק בטלפון שלכם במצב ילד, ותראו בדיוק איך זה נראה אצלו. כדי לצאת — הקוד שלכם."))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                OnboardingFooter(title: girl ? tr("כן, שתשחק עכשיו") : tr("כן, שישחק עכשיו"),
                                 link: tr("אחר כך"), onLink: onLater) {
                    Haptic.success()
                    onPlay()
                }
            }
            .padding(.horizontal, OnboardingFooter.sidePadding)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            // 📐 The foldable: ONE column beside the clock, everything centred in
            // it — narrowing single rows left the rest off-centre (Rani: "עקום").
            .clearOfBar()
        }
        .environment(\.layoutDirection, .app)
    }
}
