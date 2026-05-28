import SwiftUI
import AuthenticationServices

/// A sign-in sheet shown from Parent Settings.
struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Spacer().frame(height: 30)

                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .padding(AppSpacing.md)
                        .background(.tint.opacity(0.15), in: Circle())

                    Text("סנכרון בין מכשירים")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))

                    Text("התחבר כדי שהילד יראה את אותה התקדמות גם ב-iPad וגם ב-iPhone.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer().frame(height: 12)

                    // Apple Sign-In — black on light surface, white on dark.
                    SignInWithAppleButton(.signIn) { request in
                        auth.configureAppleRequest(request)
                    } onCompletion: { result in
                        auth.handleAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: 360)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                    // Google Sign-In — mirrors Apple's surface choice.
                    GoogleSignInBranded(surface: colorScheme == .dark ? .onColor : .onLight) {
                        Task {
                            await auth.signInWithGoogle(presenting: AuthManager.topMostViewController())
                        }
                    }
                    .frame(maxWidth: 360)

                    if let err = auth.lastError {
                        Text(err)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer()

                    Text("הסנכרון אופציונלי. אפשר להמשיך לעבוד מקומית בלי להתחבר.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.lg)
                }
                .padding(AppSpacing.lg)
            }
            .navigationTitle("חיבור חשבון")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") { dismiss() }
                }
            }
            .onChange(of: auth.isSignedIn) { _, signed in
                if signed { dismiss() }
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
