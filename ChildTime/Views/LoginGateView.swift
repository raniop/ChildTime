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
    var allowGuest: Bool = true
    /// Shows the "you've used your 30 free questions" banner.
    var limitBanner: Bool = false

    @EnvironmentObject var auth: AuthManager
    @Environment(\.horizontalSizeClass) private var hsc
    @Environment(\.colorScheme) private var colorScheme

    @State private var companion = CompanionController()
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
            ZStack(alignment: .topLeading) {
                if bubbleVisible {
                    BubbleSpeech(text: "היי! אני טופי 💫")
                        .offset(x: companionSize * 0.55, y: -28)
                        .transition(.scale.combined(with: .opacity))
                }
                CompanionView(controller: companion, size: companionSize)
                    .scaleEffect(heroAppear ? 1 : 0.3)
                    .opacity(heroAppear ? 1 : 0)
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

                Text("וחברים")
                    .font(.system(size: titleSize * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: AppColor.starGold.opacity(0.35), radius: 8)
                    .offset(y: -titleSize * 0.10)
            }
            .scaleEffect(heroAppear ? 1 : 0.4)
            .opacity(heroAppear ? 1 : 0)
            .rotationEffect(.degrees(heroAppear ? 0 : -6))
        }
    }

    // MARK: - Value props

    private var valueProps: some View {
        VStack(spacing: 10) {
            Text("היכנסו כדי להתחיל")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 3)

            VStack(spacing: 8) {
                bullet("👨‍👩‍👧‍👦", "עד 4 פרופילים לילדים, נשמרים בענן")
                bullet("📱", "אותה התקדמות ב-iPad וב-iPhone")
                bullet("🔒", "פרטי בלבד — רק אתם ולא משותף")
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: 420)
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
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 22))
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

            // Try without an account (capped at 30 questions).
            if allowGuest {
                Button {
                    Haptic.light()
                    auth.continueAsGuest()
                } label: {
                    Text("שַׂחֵק בְּלִי חֶשְׁבּוֹן")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .underline()
                        .padding(.top, 2)
                }
            }

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

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Text("בהתחברות אתם מסכימים לתנאי השימוש ולמדיניות הפרטיות")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Link("תנאי שימוש",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("•").foregroundStyle(.white.opacity(0.4))
                Link("מדיניות פרטיות",
                     destination: URL(string: "https://github.com/raniop/ChildTime/blob/main/distribution/PRIVACY_POLICY.html")!)
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
