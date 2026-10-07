//
//  AISettingsStore.swift
//  Memo
//

import Foundation
import OSLog

/// The AI preferences that are safe to keep in `UserDefaults`. The API keys
/// are not here; see ``SecretStore``.
struct AISettings: Codable, Equatable {

    /// The tool AI-assisted import uses. None until the user picks one: the
    /// feature costs money, so it is never on by default.
    var provider: AIProvider?

    /// Keyed by ``AIProvider/rawValue``.
    var selectedModels: [String: String] = [:]

    /// What each service said the key can use, for the model picker.
    var availableModels: [String: [String]] = [:]

    static let `default` = AISettings()
}

/// Holds which AI tool is in use and whether it is connected.
@Observable
final class AISettingsStore {

    var settings: AISettings {
        didSet {
            guard settings != oldValue else { return }
            save()
        }
    }

    /// Mirrors which keys are in the Keychain, which cannot be observed.
    private(set) var connectedProviders: Set<AIProvider>

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let secrets: SecretStore

    @ObservationIgnored
    private static let storageKey = "AISettings"

    @ObservationIgnored
    private static let logger = Logger(
        subsystem: AppConfiguration.loggingSubsystem,
        category: "AISettings"
    )

    init(
        defaults: UserDefaults = .standard,
        secrets: SecretStore = KeychainSecretStore()
    ) {
        self.defaults = defaults
        self.secrets = secrets
        self.settings = Self.load(from: defaults)
        self.connectedProviders = Set(
            AIProvider.allCases.filter { secrets.secret(for: $0.rawValue) != nil }
        )
    }

    /// Whether the selected tool can be used right now.
    var isConnected: Bool {
        guard let provider = settings.provider else { return false }
        return connectedProviders.contains(provider)
    }

    func isConnected(_ provider: AIProvider) -> Bool {
        connectedProviders.contains(provider)
    }

    func apiKey(for provider: AIProvider) -> String? {
        secrets.secret(for: provider.rawValue)
    }

    func model(for provider: AIProvider) -> String {
        settings.selectedModels[provider.rawValue] ?? provider.defaultModel
    }

    func setModel(_ model: String, for provider: AIProvider) {
        settings.selectedModels[provider.rawValue] = model
    }

    func availableModels(for provider: AIProvider) -> [String] {
        settings.availableModels[provider.rawValue] ?? []
    }

    /// Stores a key that has already been checked against the service.
    func connect(_ provider: AIProvider, apiKey: String, models: [String]) throws {
        try secrets.setSecret(apiKey, for: provider.rawValue)

        connectedProviders.insert(provider)
        settings.availableModels[provider.rawValue] = models
        settings.selectedModels[provider.rawValue] = provider.preferredModel(among: models)
    }

    /// Replaces the model list with a fresh one from the service, keeping the
    /// user's choice for as long as the service still offers it.
    func updateModels(_ models: [String], for provider: AIProvider) {
        guard !models.isEmpty else { return }

        settings.availableModels[provider.rawValue] = models
        if !models.contains(model(for: provider)) {
            settings.selectedModels[provider.rawValue] = provider.preferredModel(among: models)
        }
    }

    func disconnect(_ provider: AIProvider) {
        do {
            try secrets.setSecret(nil, for: provider.rawValue)
        } catch {
            Self.logger.error("Could not remove the API key: \(error.localizedDescription)")
        }

        connectedProviders.remove(provider)
        settings.availableModels[provider.rawValue] = nil
        settings.selectedModels[provider.rawValue] = nil
    }

    private static func load(from defaults: UserDefaults) -> AISettings {
        guard let data = defaults.data(forKey: storageKey) else { return .default }

        do {
            return try JSONDecoder().decode(AISettings.self, from: data)
        } catch {
            logger.error("Unreadable AI settings, using defaults: \(error.localizedDescription)")
            return .default
        }
    }

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: Self.storageKey)
        } catch {
            Self.logger.error("Could not save AI settings: \(error.localizedDescription)")
        }
    }
}
