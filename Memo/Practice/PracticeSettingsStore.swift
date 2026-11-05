//
//  PracticeSettingsStore.swift
//  Memo
//

import Foundation
import OSLog

/// Holds the practice settings that are not a deck's own, and keeps them on
/// disk.
///
/// Each deck carries its own options. What is read from here is the one
/// choice made for every deck at once: the mode a deck with no bookmarks falls
/// back to.
///
/// Kept as one encoded value so adding a rule needs no new key and no
/// migration — an older payload simply decodes with the new property at its
/// default — and shared between the user's devices; see ``SettingsStorage``.
@Observable
final class PracticeSettingsStore {

    var settings: PracticeSettings {
        didSet {
            guard settings != oldValue else { return }
            save()
        }
    }

    /// The options for Quick Practice, kept and shared the same way.
    var quickPractice: QuickPracticeSettings {
        didSet {
            guard quickPractice != oldValue else { return }
            saveQuickPractice()
        }
    }

    /// How learned cards' progress fades over time. App-wide.
    var reviewSchedule: ReviewScheduleSettings {
        didSet {
            guard reviewSchedule != oldValue else { return }
            Self.save(reviewSchedule, to: reviewScheduleStorage)
        }
    }

    @ObservationIgnored private let storage: SettingsStorage
    @ObservationIgnored private let reviewScheduleStorage: SettingsStorage
    @ObservationIgnored private let quickPracticeStorage: SettingsStorage

    @ObservationIgnored
    private static let storageKey = "PracticeSettings"

    @ObservationIgnored
    private static let quickPracticeKey = "QuickPracticeSettings"

    @ObservationIgnored
    private static let reviewScheduleKey = "ReviewScheduleSettings"

    @ObservationIgnored
    private static let logger = Logger(
        subsystem: AppConfiguration.loggingSubsystem,
        category: "PracticeSettings"
    )

    init(defaults: UserDefaults = .standard, cloud: SettingsCloud? = nil) {
        let storage = SettingsStorage(key: Self.storageKey, defaults: defaults, cloud: cloud)
        let quickPracticeStorage = SettingsStorage(key: Self.quickPracticeKey, defaults: defaults, cloud: cloud)
        let reviewScheduleStorage = SettingsStorage(key: Self.reviewScheduleKey, defaults: defaults, cloud: cloud)

        self.storage = storage
        self.quickPracticeStorage = quickPracticeStorage
        self.settings = Self.decode(storage.load())
        self.quickPractice = Self.decodeQuickPractice(quickPracticeStorage.load())
        self.reviewScheduleStorage = reviewScheduleStorage
        self.reviewSchedule = Self.decoded(reviewScheduleStorage.load()) ?? .default

        storage.onRemoteChange { [weak self] data in
            self?.settings = Self.decode(data)
        }
        quickPracticeStorage.onRemoteChange { [weak self] data in
            self?.quickPractice = Self.decodeQuickPractice(data)
        }
        reviewScheduleStorage.onRemoteChange { [weak self] data in
            self?.reviewSchedule = Self.decoded(data) ?? .default
        }
    }

    /// Restores every rule to its default.
    func reset() {
        settings = .default
    }

    private static func decode(_ data: Data?) -> PracticeSettings {
        guard let data else { return .default }

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
            let encoder = JSONEncoder()
            // Stable bytes, so the same settings are recognised as the same.
            encoder.outputFormatting = .sortedKeys
            storage.save(try encoder.encode(settings))
        } catch {
            Self.logger.error("Could not save practice settings: \(error.localizedDescription)")
        }
    }

    private static func decodeQuickPractice(_ data: Data?) -> QuickPracticeSettings {
        guard let data else { return .default }
        return (try? JSONDecoder().decode(QuickPracticeSettings.self, from: data)) ?? .default
    }

    private func saveQuickPractice() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        if let data = try? encoder.encode(quickPractice) {
            quickPracticeStorage.save(data)
        }
    }

    private static func decoded<Value: Decodable>(_ data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value, to storage: SettingsStorage) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        if let data = try? encoder.encode(value) {
            storage.save(data)
        }
    }
}
