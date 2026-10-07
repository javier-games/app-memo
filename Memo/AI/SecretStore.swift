//
//  SecretStore.swift
//  Memo
//

import Foundation
import Security

/// Somewhere to keep an API key.
///
/// A protocol so tests can use a dictionary: the Keychain is not available to
/// an unsigned test run.
protocol SecretStore {
    func secret(for account: String) -> String?
    func setSecret(_ secret: String?, for account: String) throws
}

/// API keys live in the Keychain, never in `UserDefaults`: defaults are a
/// plain file that ends up in backups.
struct KeychainSecretStore: SecretStore {

    var service = "games.javier.memo.ai"

    func secret(for account: String) -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    func setSecret(_ secret: String?, for account: String) throws {
        SecItemDelete(baseQuery(for: account) as CFDictionary)

        guard let secret else { return }

        var query = baseQuery(for: account)
        query[kSecValueData as String] = Data(secret.utf8)
        // This device only: a key the user pasted here should not travel to
        // their other devices through iCloud Keychain.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw AIFailure.keychain(status) }
    }

    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
