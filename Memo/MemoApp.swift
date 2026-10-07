//
//  MemoApp.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/01/25.
//

import SwiftUI
import SwiftData

@main
struct MemoApp: App {

    /// The single source of truth for the whole app.
    ///
    /// Views reach it through `@Environment(\.modelContext)` and `@Query`, so
    /// there is no global mutable state and no manual save calls scattered
    /// through the UI layer.
    private let modelContainer: ModelContainer

    /// The settings that are not a deck's own. Preferences rather than user
    /// content, so they live beside the store, not in it, and reach the
    /// user's other devices through iCloud's key-value store.
    @State private var practiceSettings: PracticeSettingsStore

    /// Which AI tool is chosen, for AI-assisted import. Shared the same way;
    /// the key behind it never leaves this device's Keychain.
    @State private var aiSettings: AISettingsStore

    /// Created before the store, so no sync event is missed.
    @State private var syncMonitor = CloudSyncMonitor()

    init() {
        let cloud: SettingsCloud? = AppConfiguration.isCloudSyncAvailable
            ? UbiquitousSettingsCloud()
            : nil
        _practiceSettings = State(initialValue: PracticeSettingsStore(cloud: cloud))
        _aiSettings = State(initialValue: AISettingsStore(cloud: cloud))

        let container = MemoModelContainer.make()
        LegacyStoreImport.runIfNeeded(in: container.mainContext)
        self.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            DecksView()
                .environment(practiceSettings)
                .environment(aiSettings)
                .environment(syncMonitor)
                .task {
                    // Logged at launch so "my decks didn't sync" is
                    // diagnosable: the store opens fine whether or not sync is
                    // actually running, so the account status is the real signal.
                    _ = await CloudSyncStatus.current()
                }
        }
        .modelContainer(modelContainer)
    }
}
