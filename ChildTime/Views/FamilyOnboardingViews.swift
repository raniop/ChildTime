import SwiftUI

/// Post-sign-in fork for an account with NO family yet (Rani): nobody gets a
/// silently-created empty household anymore. A spouse who naturally tapped
/// "Sign in with Google" lands here and gets the question in human words,
/// instead of a mysterious empty family.
struct FamilyChoiceView: View {
    @EnvironmentObject var settings: ParentSettings
    @StateObject private var household = HouseholdManager.shared
    @State private var creating = false
    @State private var familyName = ""
    @State private var prefilled = false

    /// 🧭 Step ① of the new-parent flow (`ParentOnboarding`), and the first
    /// screen after sign-up. It used to be a fork — "new to Tofy / the other
    /// parent already set up" — then a naming screen, then a separate privacy
    /// screen. Now it is one screen: the family's name, already filled in from
    /// the parent's own name, with the consent line under it; joining an
    /// existing family is a link at the bottom (Rani, 2026-10-05).
    private var parentName: String {
        #if DEBUG
        // 🧪 DEMO_PARENT_NAME — the name Apple/Google would hand over at sign-up
        // (the DEMO_NEWPARENT walk-through signs in without one).
        if let n = ProcessInfo.processInfo.environment["DEMO_PARENT_NAME"] { return n }
        #endif
        return AuthManager.shared.displayName ?? ""
    }
    private var firstName: String {
        parentName.split(separator: " ").first.map(String.init) ?? ""
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            VStack(spacing: AppSpacing.lg) {
                OnboardingStepsBar(current: 1)
                    .padding(.top, 8)
                Spacer(minLength: 8)
                Text("👪").font(.system(size: 60))
                Text(firstName.isEmpty ? tr("איך קוראים למשפחה?")
                                       : tr("ברוכים הבאים, \(firstName)! 👋\nאיך קוראים למשפחה?"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tr("השם יופיע במסך הבית ובעדכונים"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                nameField
                Spacer(minLength: 8)
                consentLine
                OnboardingFooter(title: tr("המשך"), busy: creating,
                                 link: tr("הוזמנתם על ידי הורה אחר? הצטרפו למשפחה"),
                                 onLink: { settings.pendingJoinFamily = true }) {
                    createFamily(named: familyName)
                }
            }
            .padding(.horizontal, OnboardingFooter.sidePadding)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .dismissKeyboardOnTap()
        .environment(\.layoutDirection, .app)
        .onAppear {
            guard !prefilled else { return }
            prefilled = true
            familyName = household.suggestedFamilyName ?? ""
            #if DEBUG
            let words = parentName.split(separator: " ")
            if familyName.isEmpty, words.count >= 2, let last = words.last { familyName = tr("משפחת \(String(last))") }
            #endif
        }
    }

    // The field arrives PRE-FILLED with a guess from the parent's own name, so
    // it holds a value, not a placeholder — with an explicit clear button, since
    // a centred field gives iOS nowhere to put one.
    private var nameField: some View {
        HStack(spacing: 8) {
            if !familyName.isEmpty {
                Button {
                    Haptic.light()
                    familyName = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("ניקוי השם"))
            }
            TextField("", text: $familyName,
                      prompt: Text(tr("למשל: משפחת גולן")).foregroundColor(.white.opacity(0.55)))
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .frame(maxWidth: .infinity)
            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassPane(radius: AppRadius.large)
    }

    /// The parental consent the separate privacy screen used to take — the
    /// same record (`consentVersionAccepted` + the account's consent stamp),
    /// given by continuing (Rani: "לאחד עם ההרשמה").
    private var consentLine: some View {
        VStack(spacing: 4) {
            Text(tr("בהמשך אתם מאשרים כהורים את תנאי השימוש ואת מדיניות הפרטיות"))
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            HStack(spacing: 14) {
                Link(tr("תנאי שימוש"), destination: URL(string: "https://tofyapp.com/terms")!)
                Text("•").foregroundStyle(.white.opacity(0.4))
                Link(tr("מדיניות פרטיות"), destination: URL(string: "https://tofyapp.com/privacy")!)
            }
            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
            .foregroundStyle(AppColor.starGold)
        }
    }

    private func createFamily(named name: String) {
        guard !creating else { return }
        creating = true
        Haptic.medium()
        settings.consentVersionAccepted = Consent.currentVersion
        ParentOnboarding.begin()
        Task {
            await household.createOwnHousehold()
            household.recordConsent(version: Consent.currentVersion)
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { household.setFamilyName(trimmed) }
            creating = false
        }
    }

}

/// "משפחת X מחכה לך" — the account's email was pre-invited by the family
/// owner, so joining is ONE tap: no QR, no codes, no prior knowledge.
struct EmailInviteWelcomeView: View {
    @StateObject private var household = HouseholdManager.shared
    @State private var joining = false

    private var familyName: String {
        let names = (household.pendingEmailInvite?.parentNames ?? [:]).values
            .filter { !$0.isEmpty }.sorted()
        return names.first.map { tr("המשפחה של \($0)") } ?? tr("המשפחה שלכם")
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            VStack(spacing: AppSpacing.xl) {
                Text("🎉").font(.system(size: 64))
                Text(tr("\(familyName) מחכה לכם!"))
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(tr("הזמנתם להצטרף כהורה — תראו את הילדים, ההתקדמות והשליטה, בדיוק כמו ההורה שהזמין אתכם."))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                Button {
                    guard !joining else { return }
                    joining = true
                    Haptic.success()
                    Task {
                        await household.acceptEmailInvite()
                        joining = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        if joining { ProgressView().tint(.white) }
                        Text(tr("הצטרפו למשפחה"))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassFill(AppGradient.gold, radius: 22)
                }
                .buttonStyle(.juicy)
                .frame(maxWidth: 420)

                Button {
                    Haptic.light()
                    household.pendingEmailInvite = nil
                    household.needsFamilyChoice = true
                } label: {
                    Text(tr("לא המשפחה שלי — התחילו מהתחלה"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .underline()
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .environment(\.layoutDirection, .app)
    }
}
