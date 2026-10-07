//
//  CloudSyncPreference.swift
//  Memo
//

import Foundation

/// The user's choice to sync their decks through iCloud.
///
/// Off until they turn it on in Settings. Read once, when the store is opened:
/// a store cannot change how it is backed while it is in use, so a change
/// takes effect the next time the app starts.
enum CloudSyncPreference {

    static let storageKey = "CloudSyncEnabled"

    static func isOn(in defaults: UserDefaults = .standard) -> Bool {
        AppConfiguration.isCloudSyncAvailable && defaults.bool(forKey: storageKey)
    }
}
