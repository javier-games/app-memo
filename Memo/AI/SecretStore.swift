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

/// Secrets live in the Keychain, never in `UserDefaults`: defaults are a
/// plain file that ends up in backups.
struct KeychainSecretStore: SecretStore {

    var service = "games.javier.memo.ai"

    /// Whether the secret travels to the user's other devices through iCloud
    /// Keychain, which is encrypted end to end and readable only by them.
    ///
    /// Off for something the user pasted in and may not want elsewhere, like
    /// an API key. On for a sign-in, where having to repeat it on every
    /// device is the nuisance.
    var isSynchronized = false

    func secret(for account: String) -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let found = item as? [String: Any],
              let data = found[kSecValueData as String] as? Data,
              let secret = String(data: data, encoding: .utf8)
        else { return nil }

        // Saved before this store was synchronized, so it has never left
        // this device. Saving it again sends it on its way.
        let isShared = found[kSecAttrSynchronizable as String] as? Bool ?? false
        if isSynchronized, !isShared {
            try? setSecret(secret, for: account)
        }

        return secret
    }

    func setSecret(_ secret: String?, for account: String) throws {
        SecItemDelete(baseQuery(for: account) as CFDictionary)

        guard let secret else { return }

        var query = baseQuery(for: account)
        query[kSecValueData as String] = Data(secret.utf8)

        if isSynchronized {
            query[kSecAttrSynchronizable as String] = true
            // An item kept to one device cannot also be shared.
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        } else {
            query[kSecAttrSynchronizable as String] = false
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw AIFailure.keychain(status) }
    }

    /// Matches the item whether or not it is shared, so a read finds one
    /// saved either way and a delete leaves neither behind. Deleting a
    /// shared item removes it from every device.
    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
    }
}
