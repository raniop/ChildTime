import SwiftUI
import AuthenticationServices

/// First screen the family ever sees. Required login so kid profiles,
/// progress, and cosmetics all sync across devices from day one.
///
/// Replaces the old optional `accountSync` step inside onboarding —
/// now that login is mandatory upfront, by the time the parent reaches
/// onboarding/profile-picker they're already authenticated.
struct LoginGateView: View {
    /// When false, hides the "play without an account" button (e.g. after the
    /// free-trial limit is reached — registration is now required).
    /// Shows the "you've used your 30 free questions" banner.
    var limitBanner: Bool = false

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.horizontalSizeClass) private var hsc
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var companion = CompanionController()
    @State private var heroAppear = false
    @State private var ctaAppear = false
    @State private var bubbleVisible = false
    @State private var burst = 0
    @State private var showEmailAuth = false

    private var isCompact: Bool { hsc == .compact }
    private var companionSize: CGFloat { isCompact ? 130 : 170 }
    private var titleSize: CGFloat { isCompact ? 54 : 78 }
    private var subtitleSize: CGFloat { isCompact ? 28 : 36 }

    var body: some View {
        ZStack {
            // Magical background
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.companionGlow,
                         AppColor.gemPurple, AppColor.dreamyTeal],
                count: 7, maxSize: 300, opacity: 0.45
            )
            SparkleField(count: 30, size: 16)
            StarBurst(count: 14, color: AppColor.starGold, trigger: burst)

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer(minLength: AppSpacing.md)

                        hero
                        if limitBanner { limitBannerView }
                        valueProps
                        if settings.pendingJoinFamily { joinFamilyBanner }
                        signInButtons
                        Spacer(minLength: AppSpacing.lg)
                        footer
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }

            // Back to the device-role choice (in case "parent" was tapped by
            // mistake). Only shown when a role is already set.
            if settings.deviceRole != .unset {
                VStack {
                    HStack {
                        Button {
                            Haptic.light()
                            settings.pendingJoinFamily = false
                            settings.deviceRole = .unset
                        } label: {
                            // Icon-only (Rani): the chevron says it all.
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.16), in: Circle())
                        }
                        .accessibilityLabel("חזרה")
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                // Vertically centered against the "היי! אני טופי" bubble
                // (Rani) — the two share the same top band.
                .padding(.top, 22)
            }
        }
        .onAppear { runEntranceSequence() }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
                .environmentObject(auth)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack(alignment: .top) {
                CompanionView(controller: companion, size: companionSize)
                    .scaleEffect(heroAppear ? 1 : 0.3)
                    .opacity(heroAppear ? 1 : 0)
                    .offset(y: 34)   // drop the lion so there's a gap below the bubble
                if bubbleVisible {
                    // Centered above the lion's head; centered tail points straight
                    // down at it — width-independent, so it always lines up.
                    BubbleSpeech(text: "היי! אני טופי 💫")
                        .offset(y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: companionSize * 1.5)

            // Brand
            VStack(spacing: 0) {
                Text("טופי")
                    .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: AppColor.starGold.opacity(0.7), radius: 16)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            }
            .scaleEffect(heroAppear ? 1 : 0.4)
            .opacity(heroAppear ? 1 : 0)
            .rotationEffect(.degrees(heroAppear ? 0 : -6))
        }
    }

    // MARK: - Value props

    // Benefit-first card (Rani settled on B) — three SHORT lines of matching
    // length, so the card reads as a tidy block instead of a ragged list.
    private var valueProps: some View {
        VStack(spacing: 10) {
            Text("היכנסו כדי להתחיל")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 3)

            VStack(spacing: 8) {
                bullet("📚", "לומדים — ומרוויחים זמן מסך")
                bullet("👀", "רואים הכל, מכל מכשיר")
                bullet("🔒", "פרטי לגמרי, רק שלכם")
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: 360)   // match the sign-in buttons' width
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .opacity(ctaAppear ? 1 : 0)
        .offset(y: ctaAppear ? 0 : 14)
    }

    private func bullet(_ emoji: String, _ text: String) -> some View {
        // CENTERED (Rani) — the equal-length lines read as one tidy block.
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: 20))
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var limitBannerView: some View {
        VStack(spacing: 6) {
            Text("🎉 כָּל הַכָּבוֹד!")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("שִׂחַקְתָּ אֶת 30 הַשְּׁאֵלוֹת הַחִנָּם. הִירָשְׁמוּ כְּדֵי לְהַמְשִׁיךְ לְשַׂחֵק לְלֹא הַגְבָּלָה — וְלִשְׁמוֹר אֶת הַהִתְקַדְּמוּת.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: 460)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(.white.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(AppColor.starGold.opacity(0.5), lineWidth: 1.5))
        )
    }

    // MARK: - Sign-in buttons

    private var signInButtons: some View {
        VStack(spacing: AppSpacing.md) {
            // Apple — native
            SignInWithAppleButton(.signIn) { request in
                auth.configureAppleRequest(request)
            } onCompletion: { result in
                auth.handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: 360)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 5, y: 2)

            // Google
            GoogleSignInBranded(surface: .onColor) {
                Task {
                    await auth.signInWithGoogle(
                        presenting: AuthManager.topMostViewController()
                    )
                }
            }
            .frame(maxWidth: 360)

            // Email / password
            Button {
                auth.lastError = nil
                showEmailAuth = true
            } label: {
                Label("המשך עם אימייל", systemImage: "envelope.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 360)
                    .frame(height: 52)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.3), lineWidth: 1))
            }

            // "כבר יש לכם משפחה? הצטרפו" REMOVED (Rani): the post-sign-in fork
            // (FamilyChoiceView) now asks new-vs-join at the right moment for
            // anyone without a family, and email invites skip even that — the
            // login screen stays minimal: just pick how to sign in.

            // Guest mode REMOVED (Rani): no using Tofy without an account. The
            // only trial is 30 days of טופי+ after signing up.

            if let err = auth.lastError {
                Text(err)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, 6)
            }
        }
        .opacity(ctaAppear ? 1 : 0)
        .offset(y: ctaAppear ? 0 : 18)
    }

    private var joinFamilyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(AppColor.successMint)
            Text("הִתְחַבְּרוּ עִם הַחֶשְׁבּוֹן שֶׁלָּכֶם — וּמִיָּד תַּזִּינוּ אֶת קוֹד הַמִּשְׁפָּחָה שֶׁקִּבַּלְתֶּם.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: 440)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(AppColor.successMint.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Text("בהתחברות אתם מסכימים לתנאי השימוש ולמדיניות הפרטיות")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Link("תנאי שימוש",
                     destination: URL(string: "https://tofyapp.com/terms")!)
                Text("•").foregroundStyle(.white.opacity(0.4))
                Link("מדיניות פרטיות",
                     destination: URL(string: "https://tofyapp.com/privacy")!)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
        }
        .opacity(ctaAppear ? 1 : 0)
    }

    // MARK: - Entrance animation

    private func runEntranceSequence() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.15)) {
            heroAppear = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            burst += 1
            companion.cheer()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                bubbleVisible = true
            }
        }
        withAnimation(.easeOut(duration: 0.6).delay(1.4)) {
            ctaAppear = true
        }
    }
}

#Preview {
    LoginGateView()
        .environmentObject(AuthManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
