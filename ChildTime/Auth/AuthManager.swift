import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit

#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseAuth
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Central auth state manager — wraps Firebase Auth + Apple Sign-In + Google Sign-In.
///
/// The whole AuthManager compiles even without Firebase / Google SDKs installed.
/// Once the SDKs are added via SPM, the real sign-in code activates automatically
/// (see `#if canImport(...)` guards below).
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var userID: String?
    @Published var displayName: String?
    @Published var email: String?
    @Published var provider: AuthProvider?
    @Published var lastError: String?
    /// Local trial mode — play without an account (capped at 30 questions).
    /// Cleared once a real account signs in.
    @Published var isGuest: Bool = UserDefaults.standard.bool(forKey: "isGuestMode") {
        didSet { UserDefaults.standard.set(isGuest, forKey: "isGuestMode") }
    }

    /// Enter the local trial. No cloud account, data stays on-device.
    func continueAsGuest() { isGuest = true }

    /// A child's device joins by scanning the parent's QR — it never sees a
    /// sign-in screen. To still get a uid (needed to join the family + sync), we
    /// sign it in ANONYMOUSLY in the background. Requires the "Anonymous"
    /// provider to be enabled in the Firebase console (Authentication → Sign-in).
    func signInAnonymouslyIfNeeded() {
        #if canImport(FirebaseAuth)
        guard userID == nil else { return }
        Auth.auth().signInAnonymously { [weak self] result, error in
            Task { @MainActor in
                if let user = result?.user {
                    self?.apply(firebaseUser: user)
                } else if let error {
                    self?.lastError = error.localizedDescription
                }
            }
        }
        #endif
    }

    enum AuthProvider: String {
        case apple
        case google
        case emailPassword
    }

    var isSignedIn: Bool { userID != nil }

    /// Apple sign-in nonce (used to verify the ID token).
    private var currentNonce: String?

    private init() {
        loadCachedUser()
        // CRUCIAL: cannot start RemoteSyncManager synchronously here.
        // RemoteSyncManager.start reads back from AuthManager.shared,
        // and we're still inside this very singleton's dispatch_once.
        // Capturing the uid locally + deferring to the next runloop tick
        // breaks the cycle (and start() also accepts an explicit uid so
        // it never needs to touch AuthManager.shared).
        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            apply(firebaseUser: user)   // also deferred internally
        } else if let cachedUID = userID, !cachedUID.isEmpty {
            let mail = email, name = displayName
            DispatchQueue.main.async {
                HouseholdManager.shared.start(uid: cachedUID, email: mail, displayName: name)
                RemoteSyncManager.shared.start(uid: cachedUID)
            }
        }
        #else
        if let cachedUID = userID, !cachedUID.isEmpty {
            let mail = email, name = displayName
            DispatchQueue.main.async {
                HouseholdManager.shared.start(uid: cachedUID, email: mail, displayName: name)
                RemoteSyncManager.shared.start(uid: cachedUID)
            }
        }
        #endif
    }

    // MARK: - Sign out

    func signOut() {
        // Stop remote sync first so we don't fire writes during teardown.
        RemoteSyncManager.shared.stop()
        HouseholdManager.shared.stop()
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        userID = nil
        displayName = nil
        email = nil
        provider = nil
        isGuest = false
        clearCache()
    }

    // MARK: - Apple

    /// Configure the request used by SignInWithAppleButton.
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the result from SignInWithAppleButton.
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            lastError = "Apple Sign-In נכשל: \(error.localizedDescription)"
        case .success(let authorization):
            Task { await self.processApple(authorization) }
        }
    }

    private func processApple(_ authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            lastError = "Unexpected Apple credential type"
            return
        }
        let nameParts: String = {
            let f = credential.fullName?.givenName ?? ""
            let l = credential.fullName?.familyName ?? ""
            return [f, l].filter { !$0.isEmpty }.joined(separator: " ")
        }()

        #if canImport(FirebaseAuth)
        guard let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            lastError = "Apple: missing identity token / nonce"
            return
        }
        let appleCred = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        do {
            let result = try await Auth.auth().signIn(with: appleCred)
            apply(firebaseUser: result.user)
            lastError = nil
        } catch {
            lastError = "Firebase: \(error.localizedDescription)"
        }
        #else
        // Fallback when Firebase isn't installed — use the Apple user ID only.
        userID = credential.user
        displayName = nameParts.isEmpty ? nil : nameParts
        email = credential.email
        provider = .apple
        cacheUser()
        lastError = nil
        #endif
    }

    // MARK: - Email / password

    func signUpWithEmail(_ email: String, password: String, displayName: String?) async {
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            if let displayName, !displayName.isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = displayName
                try? await change.commitChanges()
            }
            apply(firebaseUser: result.user)
            provider = .emailPassword
            lastError = nil
        } catch {
            lastError = mapAuthError(error)
        }
        #else
        lastError = "Firebase Auth לא הותקן"
        #endif
    }

    func signInWithEmail(_ email: String, password: String) async {
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            apply(firebaseUser: result.user)
            provider = .emailPassword
            lastError = nil
        } catch {
            lastError = mapAuthError(error)
        }
        #else
        lastError = "Firebase Auth לא הותקן"
        #endif
    }

    func sendPasswordReset(to email: String) async {
        #if canImport(FirebaseAuth)
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            lastError = nil
        } catch {
            lastError = mapAuthError(error)
        }
        #endif
    }

    private func mapAuthError(_ error: Error) -> String {
        let ns = error as NSError
        switch ns.code {
        case 17007: return "האימייל כבר רשום"
        case 17008: return "כתובת אימייל לא תקינה"
        case 17009: return "סיסמה שגויה"
        case 17011: return "לא נמצא משתמש עם אימייל זה"
        case 17026: return "הסיסמה חלשה מדי (לפחות 6 תווים)"
        default:    return "שגיאת התחברות: \(ns.localizedDescription)"
        }
    }

    // MARK: - Google

    func signInWithGoogle(presenting controller: UIViewController?) async {
        #if canImport(GoogleSignIn) && canImport(FirebaseAuth)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            lastError = "Google: missing Firebase clientID"
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let presenter = controller ?? Self.topMostViewController() else {
            lastError = "Google: no presenter available"
            return
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                lastError = "Google: missing idToken"
                return
            }
            let accessToken = result.user.accessToken.tokenString
            let cred = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let auth = try await Auth.auth().signIn(with: cred)
            apply(firebaseUser: auth.user)
            lastError = nil
        } catch {
            lastError = "Google: \(error.localizedDescription)"
        }
        #else
        lastError = "Google Sign-In SDK עוד לא הותקן"
        #endif
    }

    // MARK: - Helpers

    #if canImport(FirebaseAuth)
    private func apply(firebaseUser user: User) {
        let uid = user.uid
        userID = uid
        isGuest = false   // a real account replaces guest mode
        displayName = user.displayName
        email = user.email
        // Infer provider from the firebase providerData
        if let p = user.providerData.first?.providerID {
            if p.contains("apple") { provider = .apple }
            else if p.contains("google") { provider = .google }
        }
        cacheUser()
        // Defer + pass the uid explicitly. Two layers of defense against
        // singleton re-entry: even when invoked during this AuthManager's
        // own init, the async hop pushes RemoteSyncManager.start outside
        // the dispatch_once window, AND start() no longer needs to read
        // AuthManager.shared.userID.
        let name = user.displayName
        let mail = user.email
        DispatchQueue.main.async {
            HouseholdManager.shared.start(uid: uid, email: mail, displayName: name)
            RemoteSyncManager.shared.start(uid: uid)
        }
    }
    #endif

    // MARK: - Persistence (so quitting the app keeps the user)

    private struct CachedUser: Codable {
        var userID: String
        var displayName: String?
        var email: String?
        var provider: String?
    }

    private let cacheKey = "auth.cachedUser"

    private func cacheUser() {
        guard let id = userID else { return }
        let cached = CachedUser(
            userID: id,
            displayName: displayName,
            email: email,
            provider: provider?.rawValue
        )
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCachedUser() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CachedUser.self, from: data)
        else { return }
        userID = cached.userID
        displayName = cached.displayName
        email = cached.email
        if let p = cached.provider { provider = AuthProvider(rawValue: p) }
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    // MARK: - Apple nonce utilities

    static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    static func topMostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        guard let root = scene?.keyWindow?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
