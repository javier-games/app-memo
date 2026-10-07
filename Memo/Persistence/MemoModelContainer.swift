//
//  MemoModelContainer.swift
//  Memo
//

import Foundation
import SwiftData
import OSLog

/// Builds the app's SwiftData stack.
///
/// The container degrades rather than traps. If the CloudKit-backed store cannot
/// be opened — no iCloud entitlement, no signed-in account, a provisioning
/// mistake — the app falls back to a local store and finally to an in-memory
/// one, so a sync misconfiguration can never present itself to the user as a
/// launch crash.
enum MemoModelContainer {

    /// How the live store ended up being opened.
    ///
    /// `cloudKitConfigured` means the store was opened with the CloudKit
    /// configuration — not that it is currently syncing. SwiftData opens such a
    /// store happily even with no iCloud entitlement and no signed-in account;
    /// it simply never replicates. Ask ``CloudSyncStatus`` whether sync is
    /// actually available.
    enum Mode: String {
        case cloudKitConfigured = "iCloud sync configured"
        case localOnly          = "On this device only"
        case inMemory           = "Temporary (not saved)"
    }

    /// Whether the store this app opened is capable of syncing at all.
    static var isCloudConfigured: Bool { mode == .cloudKitConfigured }

    private(set) static var mode: Mode = .localOnly

    private static let logger = Logger(subsystem: AppConfiguration.loggingSubsystem, category: "Persistence")

    /// Must match the identifier in `Memo.entitlements`.
    ///
    /// Deliberately not derived from the bundle identifier: a CloudKit
    /// container is a separate identifier registered in the developer portal,
    /// and it stays fixed even when the bundle identifier changes for signing
    /// reasons. Changing this string orphans every record already synced.
    static let cloudKitContainerIdentifier = "iCloud.com.javier.memo"

    static let schema = Schema([Deck.self, Card.self])

    /// Creates the container used by the app.
    static func make() -> ModelContainer {
        let isSyncWanted = CloudSyncPreference.isOn()

        if isSyncWanted, let container = makeCloudKitContainer() {
            mode = .cloudKitConfigured
            logger.info("Opened store with CloudKit configuration.")
            return container
        }

        if let container = makeLocalContainer() {
            mode = .localOnly
            if isSyncWanted {
                logger.warning("CloudKit unavailable; opened local-only store.")
            } else {
                logger.info("Sync is off; opened local-only store.")
            }
            return container
        }

        mode = .inMemory
        logger.error("Persistent store unavailable; falling back to in-memory store.")
        return makeInMemoryContainer()
    }

    /// A container for previews and tests. Never touches the user's data.
    static func makeInMemoryContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // An in-memory store has no external dependencies; a failure here
            // means the schema itself is invalid, which is a programmer error.
            fatalError("Invalid SwiftData schema: \(error)")
        }
    }

    private static func makeCloudKitContainer() -> ModelContainer? {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("CloudKit store unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    private static func makeLocalContainer() -> ModelContainer? {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("Local store unavailable: \(error.localizedDescription)")
            return nil
        }
    }
}
