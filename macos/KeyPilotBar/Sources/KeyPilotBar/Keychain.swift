// Master key storage in the macOS keychain.
// The key is stored per backend URL, so different vaults keep separate entries.
import Foundation
import Security
import LocalAuthentication

enum Keychain {
    private static let service = "com.keypilot.bar"

    private static func account(for baseURL: String) -> String { "master-key:\(baseURL)" }

    static func save(masterKey: String, baseURL: String) {
        let acc = account(for: baseURL)
        delete(baseURL: baseURL)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acc,
            kSecAttrLabel as String: "KeyPilot Bar master key",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecValueData as String: Data(masterKey.utf8),
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(baseURL: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: baseURL),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(baseURL: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: baseURL),
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func hasKey(baseURL: String) -> Bool { read(baseURL: baseURL) != nil }
}

enum Biometrics {
    static var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Touch ID (falls back to the login password) before revealing a secret.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
    }
}
