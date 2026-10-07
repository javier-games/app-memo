//
//  SettingsStorage.swift
//  Memo
//
//  Where the app's settings are kept. They are small preferences rather than
//  user content, so they live in `UserDefaults`, not in the SwiftData store —
//  and are copied through iCloud's key-value store so that a choice made on
//  one device is the choice on all of them.
//

import Foundation

/// The settings shared between the user's devices.
///
/// A protocol so the stores can be tested against a dictionary: the real one
/// only does anything in a build signed for iCloud.
protocol SettingsCloud: AnyObject {

    func data(forKey key: String) -> Data?

    func set(_ data: Data, forKey key: String)

    /// Calls `handler` with the new value when another device changes `key`.
    func onChange(of key: String, _ handler: @escaping (Data) -> Void)
}

/// iCloud's key-value store.
///
/// Made for exactly this: a few kilobytes of preferences, last writer wins,
/// no schema. Without the iCloud entitlement or an account it behaves as a
/// local store that never hears from anyone, which is harmless.
final class UbiquitousSettingsCloud: SettingsCloud {

    private let store = NSUbiquitousKeyValueStore.default
    private var handlers: [String: (Data) -> Void] = [:]
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            self?.changed(keys ?? [])
        }

        // Asks for whatever other devices have written since the last launch.
        store.synchronize()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func data(forKey key: String) -> Data? {
        store.data(forKey: key)
    }

    func set(_ data: Data, forKey key: String) {
        store.set(data, forKey: key)
    }

    func onChange(of key: String, _ handler: @escaping (Data) -> Void) {
        handlers[key] = handler
    }

    private func changed(_ keys: [String]) {
        for key in keys {
            guard let handler = handlers[key], let data = store.data(forKey: key) else { continue }
            handler(data)
        }
    }
}

/// One encoded value, kept on this device and, when there is a cloud, in it.
final class SettingsStorage {

    private let key: String
    private let defaults: UserDefaults
    private let cloud: SettingsCloud?

    init(key: String, defaults: UserDefaults, cloud: SettingsCloud?) {
        self.key = key
        self.defaults = defaults
        self.cloud = cloud
    }

    /// The value to start from.
    ///
    /// The cloud's wins when it has one, since it is at least as recent as
    /// anything saved here before. A device with a value the cloud lacks
    /// offers its own.
    func load() -> Data? {
        let local = defaults.data(forKey: key)

        guard let cloud else { return local }

        if let shared = cloud.data(forKey: key) {
            defaults.set(shared, forKey: key)
            return shared
        }

        if let local { cloud.set(local, forKey: key) }
        return local
    }

    func save(_ data: Data) {
        defaults.set(data, forKey: key)

        // Skipped when the cloud already holds this, which is the case right
        // after a change arrived from it. Writing it back would send every
        // device's change round all the others a second time.
        if let cloud, cloud.data(forKey: key) != data {
            cloud.set(data, forKey: key)
        }
    }

    /// Calls `handler` when another device changes the value.
    func onRemoteChange(_ handler: @escaping (Data) -> Void) {
        cloud?.onChange(of: key, handler)
    }
}
