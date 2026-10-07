//
//  CloudSyncPreferenceTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class CloudSyncPreferenceTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.sync.preference.\(UUID().uuidString)")!
    }

    func testSyncIsOffUntilTheUserTurnsItOn() {
        let defaults = makeDefaults()
        XCTAssertFalse(CloudSyncPreference.isOn(in: defaults))

        defaults.set(true, forKey: CloudSyncPreference.storageKey)
        XCTAssertEqual(CloudSyncPreference.isOn(in: defaults), AppConfiguration.isCloudSyncAvailable)
    }
}
