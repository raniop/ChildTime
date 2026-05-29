import Foundation
import Security
import CryptoKit
import LocalAuthentication

/// Secure parent-PIN storage. The PIN is never stored in clear text — only a
/// salted SHA-256 hash lives in the Keychain. Also wraps Face ID / Touch ID as
/// an alternative to typing the PIN at the parent gate.
@MainActor
final class PINManager {
    static let shared = PINManager()

    private let service = "com.childtime.parentpin"
    private let account = "pin"

    private init() { migrateLegacyPlainPINIfNeeded() }

    var isSet: Bool { readBlob() != nil }

    // MARK: - Set / verify

    func setPIN(_ pin: String) {
        let salt = Self.randomSalt()
        let hash = Self.hash(pin: pin, salt: salt)
        let blob = salt + ":" + hash
        writeBlob(blob)
    }

    func verify(_ pin: String) -> Bool {
        guard let blob = readBlob() else { return false }
        let parts = blob.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }
        let salt = parts[0]
        let expected = parts[1]
        return Self.hash(pin: pin, salt: salt) == expected
    }

    // MARK: - Biometrics

    var biometryAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticateBiometric(reason: String = "פתיחת הגדרות הורה") async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "השתמש בקוד"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return await withCheckedContinuation { cont in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }

    // MARK: - Hashing

    private static func hash(pin: String, salt: String) -> String {
        let data = Data((salt + pin).utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomSalt(_ length: Int = 16) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Migration

    /// One-time move of any legacy plain-text PIN (from `ParentSettings.pin`)
    /// into the hashed Keychain store.
    private func migrateLegacyPlainPINIfNeeded() {
        guard readBlob() == nil else { return }
        let legacy = ParentSettings.shared.pin
        if legacy.count == 4, legacy.allSatisfy(\.isNumber) {
            setPIN(legacy)
        }
    }

    // MARK: - Keychain

    private func writeBlob(_ blob: String) {
        let data = Data(blob.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private func readBlob() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
}
