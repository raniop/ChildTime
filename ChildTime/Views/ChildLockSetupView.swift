import SwiftUI

/// 🧭 Step ④ of the new-parent flow, on the CHILD's phone, right after it
/// joins — before the child's home ever shows.
///
/// The new-parent walk-through (2026-10-05) found the one thing that makes Tofy
/// work — Apple's Screen Time grant — hiding in a small strip addressed to the
/// child ("בקשו מאבא או מאמא…"), while the parent holding the phone thought
/// they were done. Now it is a screen of its own, said to the parent:
///
///   1. approve Screen Time (Apple's own sheet), then
///   2. the recommended Screen Time passcode, with the drawings of Apple's pages
///
/// and then the child's home. Parent-facing: no niqqud.
enum ChildLockSetup {
    static let pendingKey = "childLockSetup.pending"
    static var isPending: Bool { UserDefaults.standard.bool(forKey: pendingKey) }
    static func markPending() { UserDefaults.standard.set(true, forKey: pendingKey) }
    static func done() {
        UserDefaults.standard.set(false, forKey: pendingKey)
        // The Apple Screen Time tips sheet said the same — never show it on top.
        UserDefaults.standard.set(false, forKey: AppleScreenTimeTips.pendingKey)
    }
}

struct ChildLockSetupView: View {
    let onDone: () -> Void

    @ObservedObject private var shields = ShieldManager.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @State private var asking = false
    @State private var failed = false
    @State private var approved = false
    /// 📍 The optional last step: location, while the parent holds the phone.
    @State private var askLocation = false
    @State private var savingLocation = false

    private var child: Profile? { profiles.active }
    private var name: String { child.map { Question.stripNiqqud($0.name) } ?? "" }
    private var girl: Bool { child?.gender == .girl }

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            SparkleField(count: 12, size: 11)
            VStack(spacing: 16) {
                OnboardingStepsBar(current: 4, note: tr("רק הורה"))
                    .padding(.top, 8)
                if askLocation { locationBody } else if approved { passcodeBody } else { approveBody }
            }
            .padding(.horizontal, OnboardingFooter.sidePadding)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            if AppInfo.isDemoRun {
                approved = ProcessInfo.processInfo.environment["DEMO_APPROVED"] == "1"
                askLocation = ProcessInfo.processInfo.environment["DEMO_LOCATION_STEP"] == "1"
                failed = ProcessInfo.processInfo.environment["DEMO_FAILED"] == "1"
                return
            }
            shields.refreshStatus()
            if shields.isAuthorized { approved = true }
        }
    }

    // MARK: 1 — approve Screen Time

    private var approveBody: some View {
        VStack(spacing: 14) {
            if !name.isEmpty {
                pill(girl ? tr("✓ מחובר ל\(name)") : tr("✓ מחובר ל\(name)"), mint: true)
            }
            Text(tr("מאשרים זמן מסך"))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(name.isEmpty ? tr("כך טופי נועל את שאר האפליקציות עד שמרוויחים זמן")
                 : (girl ? tr("כך טופי נועל את שאר האפליקציות עד ש\(name) מרוויחה זמן")
                         : tr("כך טופי נועל את שאר האפליקציות עד ש\(name) מרוויח זמן")))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                Text(tr("יופיע חלון של אפל"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text(tr("לוחצים \"המשך\" ומאשרים עם הקוד של הטלפון או Face ID"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color(hex: "1C1C1E"))
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "F2F2F7")))

            if failed {
                Text(shields.authorizationError ?? tr("האישור לא הושלם. נסו שוב ואשרו בחלון של אפל."))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "FFE28A"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            // Never a dead end — but said for what it is.
            OnboardingFooter(title: failed ? tr("נסו שוב") : tr("אישור זמן מסך"), busy: asking,
                             link: failed ? tr("להמשיך בלי נעילה (לא מומלץ)") : nil,
                             onLink: { finish() }) { approve() }
        }
    }

    // MARK: 2 — the Screen Time passcode

    private var passcodeBody: some View {
        VStack(spacing: 14) {
            pill(tr("✓ הנעילה פועלת"), mint: true)
            Text("🔐").font(.system(size: 44))
            Text(tr("מומלץ: קוד ל\"זמן מסך\""))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(name.isEmpty ? tr("בלי קוד, אפשר לכבות את טופי בהגדרות של האייפון — ואז הכל נפתח. לוקח דקה:")
                 : (girl ? tr("בלי קוד, \(name) יכולה לכבות את טופי בהגדרות של האייפון — ואז הכל נפתח. לוקח דקה:")
                         : tr("בלי קוד, \(name) יכול לכבות את טופי בהגדרות של האייפון — ואז הכל נפתח. לוקח דקה:")))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity)
                .glassPane(radius: 16)
            ScreenTimeShowMeButton()
            Spacer(minLength: 8)
            OnboardingFooter(title: name.isEmpty ? tr("סיימתי") : (girl ? tr("סיימתי — \(name) יכולה להתחיל") : tr("סיימתי — \(name) יכול להתחיל")),
                             link: tr("אעשה את זה אחר כך"), onLink: { toLocation() }) { toLocation() }
        }
    }

    // MARK: 3 — 📍 location (optional)

    /// The parent is holding the child's phone right now — the one moment
    /// Apple's location question is answered by an adult, not by a child
    /// reading system dialogs. Skippable; it can be switched on later from the
    /// parent's map.
    private var locationBody: some View {
        VStack(spacing: 14) {
            pill(tr("✓ הנעילה פועלת"), mint: true)
            Text("📍").font(.system(size: 44))
            Text(name.isEmpty ? tr("לדעת איפה הטלפון? (לא חובה)") : tr("לדעת איפה \(name)? (לא חובה)"))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                Text(girl ? tr("מה נשמר: המיקום האחרון של הטלפון שלה, והגעה או יציאה מהמקומות שסימנתם. לא מסלול של כל היום.")
                          : tr("מה נשמר: המיקום האחרון של הטלפון שלו, והגעה או יציאה מהמקומות שסימנתם. לא מסלול של כל היום."))
                Text(tr("מי רואה: רק ההורים במשפחה. שום דבר לא עובר לאף גורם אחר."))
                Text(tr("כיבוי: מוחק מיד את המיקום השמור."))
            }
            .font(.system(size: 14.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPane(radius: 16)
            Text(tr("יופיע חלון של אפל — מאשרים בו את המיקום"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "1C1C1E"))
                .padding(12).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "F2F2F7")))
            Spacer(minLength: 8)
            OnboardingFooter(title: tr("אישור והפעלת מיקום"), busy: savingLocation,
                             link: tr("אולי אחר כך"), onLink: { finish() }) { enableLocation() }
        }
    }

    private func toLocation() {
        // Already shared (a re-pair) → straight on.
        guard let cid = profiles.activeID?.uuidString, LocationSharing.shared.sharing[cid] != true else { finish(); return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { askLocation = true }
    }

    private func enableLocation() {
        guard let cid = profiles.activeID?.uuidString, !savingLocation else { return }
        savingLocation = true
        Task { @MainActor in
            _ = await LocationSharing.shared.setSharing(childID: cid, on: true)
            // Apple's question now, while the parent holds the phone — and the
            // kid's own explanation later counts it as asked once.
            LocationSharing.shared.requestPermission()
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "location.promptCount") + 1, forKey: "location.promptCount")
            savingLocation = false
            finish()
        }
    }


    // MARK: Actions

    private func approve() {
        guard !asking else { return }
        asking = true
        Haptic.light()
        Task { @MainActor in
            await shields.requestAuthorizationIfNeeded(userInitiated: true)
            asking = false
            if shields.isAuthorized {
                Haptic.success()
                // Tell the parent's phone right away — its "waiting for the
                // lock" screen ends on this report, not on the next heartbeat.
                if let cid = profiles.activeID {
                    Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { approved = true; failed = false }
            } else {
                Haptic.warning()
                withAnimation { failed = true }
            }
        }
    }

    private func finish() {
        Haptic.success()
        ChildLockSetup.done()
        onDone()
    }

    private func pill(_ text: String, mint: Bool) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(mint ? Color(hex: "053B26") : .white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(mint ? AppColor.successMint : .white.opacity(0.16)))
    }
}
