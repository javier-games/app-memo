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

    /// Practice rules live alongside the store rather than inside it: they are
    /// per-device preferences, not user content, so they are not synced.
    @State private var practiceSettings = PracticeSettingsStore()

    /// Which AI tool is connected, for AI-assisted import. Per-device for the
    /// same reason, and because the key behind it never leaves the Keychain.
    @State private var aiSettings = AISettingsStore()

    /// Created before the store, so no sync event is missed.
    @State private var syncMonitor = CloudSyncMonitor()

    init() {
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
