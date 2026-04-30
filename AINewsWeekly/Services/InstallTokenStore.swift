import Foundation
import Security

// InstallTokenStore — generates an opaque per-install UUID on first launch
// and persists it in the iOS Keychain. Read on every Tutor call to populate
// the X-Install-Token header that the Worker uses for rate limits.
//
// CRITICAL DESIGN DECISION (eng review fix #1):
//   Do NOT use UserDefaults for this token. UserDefaults is wiped when
//   iOS offloads the app and the user reinstalls — that would let a single
//   install rotate tokens to bypass the Worker's per-install rate limit.
//   Keychain (with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
//   survives offload-then-reinstall AND survives reboots, but never syncs
//   to iCloud Keychain (we want per-install, not per-Apple-ID).
//
// Token format: UUID().uuidString (lowercase with hyphens), e.g.
// "b3a1c2d4-5e67-8901-2345-6789abcdef01".
enum InstallTokenStore {
    private static let service = "ainews.tutor.install-token"
    private static let account = "default"

    // Returns the token, generating + persisting it on first call.
    // Idempotent: subsequent calls always return the same token until the
    // app is uninstalled (Keychain entries scoped by app bundle).
    static func token() -> String {
        if let existing = readFromKeychain() {
            return existing
        }
        let new = UUID().uuidString
        writeToKeychain(new)
        return new
    }

    // For tests: clear the persisted token so the next `token()` call
    // generates fresh.
    static func clearForTests() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Keychain primitives

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8),
              !str.isEmpty
        else {
            return nil
        }
        return str
    }

    private static func writeToKeychain(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // After first unlock, this-device-only — survives reboots,
            // never syncs to iCloud Keychain.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        // Try add; on duplicate, update.
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            let attrs: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(updateQuery as CFDictionary, attrs as CFDictionary)
        }
    }
}
