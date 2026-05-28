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

                    // Apple Sign-In button (Apple's native)
                    SignInWithAppleButton(.signIn) { request in
                        auth.configureAppleRequest(request)
                    } onCompletion: { result in
                        auth.handleAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: 360)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Google Sign-In button
                    Button {
                        Task {
                            await auth.signInWithGoogle(presenting: AuthManager.topMostViewController())
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("G")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 22, height: 22)
                                .background(.white, in: Circle())
                                .foregroundStyle(.black)
                            Text("התחבר עם Google")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: 360, minHeight: 48)
                        .background(Color(hex: "4285F4"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

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
