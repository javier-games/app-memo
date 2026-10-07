//
//  SettingsStorageTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class SettingsStorageTests: XCTestCase {

    /// Stands in for iCloud's key-value store.
    private final class MemoryCloud: SettingsCloud {
        var values: [String: Data] = [:]
        var writeCount = 0
        private var handlers: [String: (Data) -> Void] = [:]

        func data(forKey key: String) -> Data? { values[key] }

        func set(_ data: Data, forKey key: String) {
            values[key] = data
            writeCount += 1
        }

        func onChange(of key: String, _ handler: @escaping (Data) -> Void) {
            handlers[key] = handler
        }

        /// What happens when another device writes `data`.
        func receive(_ data: Data, forKey key: String) {
            values[key] = data
            handlers[key]?(data)
        }
    }

    private final class MemorySecretStore: SecretStore {
        var secrets: [String: String] = [:]

        func secret(for account: String) -> String? { secrets[account] }
        func setSecret(_ secret: String?, for account: String) throws { secrets[account] = secret }
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.settings.storage.\(UUID().uuidString)")!
    }

    private func encoded(_ settings: PracticeSettings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(settings)
    }

    private var inOrderFallback: PracticeSettings {
        var settings = PracticeSettings()
        settings.bookmarkFallbackMode = .inOrder
        return settings
    }

    // MARK: - Practice settings

    func testAChangeIsSentToTheCloud() throws {
        let cloud = MemoryCloud()
        let store = PracticeSettingsStore(defaults: makeDefaults(), cloud: cloud)

        store.settings.bookmarkFallbackMode = .inOrder

        let shared = try XCTUnwrap(cloud.values["PracticeSettings"])
        XCTAssertEqual(
            try JSONDecoder().decode(PracticeSettings.self, from: shared).bookmarkFallbackMode,
            .inOrder
        )
    }

    func testANewDeviceStartsFromTheCloud() throws {
        let cloud = MemoryCloud()
        cloud.values["PracticeSettings"] = try encoded(inOrderFallback)

        let store = PracticeSettingsStore(defaults: makeDefaults(), cloud: cloud)

        XCTAssertEqual(store.settings.bookmarkFallbackMode, .inOrder)
    }

    func testADeviceWithSettingsTheCloudLacksOffersItsOwn() throws {
        let defaults = makeDefaults()
        PracticeSettingsStore(defaults: defaults).settings.bookmarkFallbackMode = .inOrder

        let cloud = MemoryCloud()
        _ = PracticeSettingsStore(defaults: defaults, cloud: cloud)

        XCTAssertNotNil(cloud.values["PracticeSettings"])
    }

    func testAChangeFromAnotherDeviceIsAppliedAndNotSentBack() throws {
        let cloud = MemoryCloud()
        let defaults = makeDefaults()
        let store = PracticeSettingsStore(defaults: defaults, cloud: cloud)
        let writesBefore = cloud.writeCount

        cloud.receive(try encoded(inOrderFallback), forKey: "PracticeSettings")

        XCTAssertEqual(store.settings.bookmarkFallbackMode, .inOrder)
        XCTAssertEqual(cloud.writeCount, writesBefore, "echoing it would loop between devices")

        // And it is kept for the next launch, cloud or no cloud.
        XCTAssertEqual(PracticeSettingsStore(defaults: defaults).settings.bookmarkFallbackMode, .inOrder)
    }

    func testWithoutACloudSettingsStayOnTheDevice() {
        let defaults = makeDefaults()
        PracticeSettingsStore(defaults: defaults).settings.bookmarkFallbackMode = .inOrder

        XCTAssertEqual(PracticeSettingsStore(defaults: defaults).settings.bookmarkFallbackMode, .inOrder)
    }

    // MARK: - AI settings

    func testTheAssistantChoiceIsSharedButTheKeyIsNot() throws {
        let cloud = MemoryCloud()
        let first = AISettingsStore(defaults: makeDefaults(), secrets: MemorySecretStore(), cloud: cloud)
        first.settings.provider = .claude
        try first.connect(.claude, apiKey: "key", models: ["claude-opus-5-5"])

        let second = AISettingsStore(defaults: makeDefaults(), secrets: MemorySecretStore(), cloud: cloud)

        XCTAssertEqual(second.settings.provider, .claude)
        XCTAssertEqual(second.model(for: .claude), "claude-opus-5-5")
        XCTAssertNil(second.apiKey(for: .claude))
        XCTAssertFalse(second.isConnected, "each device connects with its own key")

        let shared = try XCTUnwrap(cloud.values["AISettings"])
        XCTAssertFalse(String(decoding: shared, as: UTF8.self).contains("key\""))
    }
}
