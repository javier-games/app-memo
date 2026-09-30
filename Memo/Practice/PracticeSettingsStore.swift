//
//  PracticeSettingsStore.swift
//  Memo
//

import Foundation
import OSLog

/// Holds the practice settings and keeps them on disk.
///
/// `UserDefaults` is the right home for these: they are small, per-device
/// preferences rather than user content. They are stored as one encoded value
/// so adding a rule needs no new key and no migration — an older payload simply
/// decodes with the new property at its default.
@Observable
final class PracticeSettingsStore {

    var settings: PracticeSettings {
        didSet {
            guard settings != oldValue else { return }
            save()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    @ObservationIgnored
    private static let storageKey = "PracticeSettings"

    @ObservationIgnored
    private static let logger = Logger(
        subsystem: AppConfiguration.loggingSubsystem,
        category: "PracticeSettings"
    )

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.load(from: defaults)
    }

    /// Restores every rule to its default.
    func reset() {
        settings = .default
    }

    private static func load(from defaults: UserDefaults) -> PracticeSettings {
        guard let data = defaults.data(forKey: storageKey) else { return .default }

        do {
            return try JSONDecoder().decode(PracticeSettings.self, from: data)
        } catch {
            // Falling back to defaults rather than trapping: unreadable
            // preferences should never stop someone practising.
            logger.error("Unreadable practice settings, using defaults: \(error.localizedDescription)")
            return .default
        }
    }

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: Self.storageKey)
        } catch {
            Self.logger.error("Could not save practice settings: \(error.localizedDescription)")
        }
    }
}
