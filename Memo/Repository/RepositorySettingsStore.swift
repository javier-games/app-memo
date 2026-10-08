//
//  RepositorySettingsStore.swift
//  Memo
//

import Foundation
import OSLog

/// Which repository decks are pushed to and pulled from, and how.
struct RepositorySettings: Codable, Equatable {

    /// `owner/name`, or `nil` until one is chosen.
    var repository: String?

    /// One file holding every deck, rather than a file per deck.
    var usesSingleFile = false

    /// The GitHub account, for showing who is signed in.
    var accountLogin: String?

    static let `default` = RepositorySettings()
}

// Declared in an extension so the memberwise initialiser survives.
extension RepositorySettings {

    private enum CodingKeys: String, CodingKey {
        case repository, usesSingleFile, accountLogin
    }

    /// Tolerant for the same reason ``PracticeSettings`` is: a setting added
    /// later must not make a saved payload unreadable.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            repository: try container.decodeIfPresent(String.self, forKey: .repository),
            usesSingleFile: try container.decodeIfPresent(Bool.self, forKey: .usesSingleFile) ?? false,
            accountLogin: try container.decodeIfPresent(String.self, forKey: .accountLogin)
        )
    }
}

/// Holds the repository settings and whether this device is signed in.
///
/// The settings are shared between the user's devices like the others. The
/// token is not: like the AI key it stays in this device's Keychain, so each
/// device signs in for itself.
@Observable
final class RepositorySettingsStore {

    var settings: RepositorySettings {
        didSet {
            guard settings != oldValue else { return }
            save()
        }
    }

    /// Mirrors whether a token is in the Keychain, which cannot be observed.
    private(set) var isSignedIn: Bool

    @ObservationIgnored private let storage: SettingsStorage
    @ObservationIgnored private let secrets: SecretStore

    @ObservationIgnored private static let storageKey = "RepositorySettings"
    @ObservationIgnored private static let tokenAccount = "github"

    @ObservationIgnored
    private static let logger = Logger(
        subsystem: AppConfiguration.loggingSubsystem,
        category: "Repository"
    )

    init(
        defaults: UserDefaults = .standard,
        secrets: SecretStore = KeychainSecretStore(service: "games.javier.memo.github"),
        cloud: SettingsCloud? = nil
    ) {
        let storage = SettingsStorage(key: Self.storageKey, defaults: defaults, cloud: cloud)

        self.storage = storage
        self.secrets = secrets
        self.settings = Self.decode(storage.load())
        self.isSignedIn = secrets.secret(for: Self.tokenAccount) != nil

        storage.onRemoteChange { [weak self] data in
            self?.settings = Self.decode(data)
        }
    }

    var token: String? { secrets.secret(for: Self.tokenAccount) }

    /// Signed in, with somewhere to sync to.
    var isReady: Bool { isSignedIn && settings.repository != nil }

    func signIn(token: String, login: String) throws {
        try secrets.setSecret(token, for: Self.tokenAccount)
        isSignedIn = true
        settings.accountLogin = login
    }

    /// Forgets the token. The repository choice is kept: it is shared with
    /// the user's other devices, and signing out here should not undo it there.
    func signOut() {
        do {
            try secrets.setSecret(nil, for: Self.tokenAccount)
        } catch {
            Self.logger.error("Could not remove the GitHub token: \(error.localizedDescription)")
        }
        isSignedIn = false
    }

    private static func decode(_ data: Data?) -> RepositorySettings {
        guard let data else { return .default }

        do {
            return try JSONDecoder().decode(RepositorySettings.self, from: data)
        } catch {
            logger.error("Unreadable repository settings, using defaults: \(error.localizedDescription)")
            return .default
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            storage.save(try encoder.encode(settings))
        } catch {
            Self.logger.error("Could not save repository settings: \(error.localizedDescription)")
        }
    }
}
