//
//  CloudSyncStatus.swift
//  Memo
//

import Foundation
import CloudKit
import OSLog

/// Reports whether iCloud sync can actually run right now.
///
/// This is deliberately separate from ``MemoModelContainer/mode``. SwiftData
/// will open a CloudKit-configured store even when the app has no iCloud
/// entitlement and the device has no signed-in account — it just never
/// replicates, silently. The only honest signal is the account status, and it
/// is the first thing to check when decks fail to appear on a second device.
enum CloudSyncStatus: Equatable {

    /// Signed in and able to sync.
    case available

    /// No iCloud account on the device; the user needs to sign in in Settings.
    case noAccount

    /// Parental controls or an MDM profile block iCloud.
    case restricted

    /// Status could not be determined — usually offline.
    case unknown

    /// The app is not provisioned for CloudKit, so sync can never run.
    case notConfigured(String)

    var isSyncing: Bool { self == .available }

    /// A short line suitable for showing in a settings row.
    var userDescription: String {
        switch self {
        case .available:            "Syncing with iCloud"
        case .noAccount:            "Sign in to iCloud to sync your decks"
        case .restricted:           "iCloud is restricted on this device"
        case .unknown:              "Can't reach iCloud right now"
        case .notConfigured:        "iCloud sync isn't set up for this build"
        }
    }

    private static let logger = Logger(subsystem: AppConfiguration.loggingSubsystem, category: "Sync")

    /// Whether the device has an iCloud account at all.
    ///
    /// Plain Foundation, so it is safe to call from any build. Used as a
    /// pre-check because CloudKit is not: see the note on ``current()``.
    private static var hasSignedInAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Queries the current account status.
    ///
    /// Always constructs the container from an explicit identifier.
    /// `CKContainer.default()` derives it from the `application-identifier`
    /// entitlement and raises an *Objective-C* `CKException` when that is
    /// absent — on unsigned builds, for instance. That exception is not
    /// catchable from Swift, so it terminates the app; the only defence is not
    /// to trigger it.
    static func current() async -> CloudSyncStatus {
        // The build switch is checked first, so a build without the
        // entitlements never reaches a CloudKit symbol at all.
        guard AppConfiguration.isCloudSyncEnabled else {
            logger.info("iCloud sync is disabled in this build.")
            return .notConfigured("Sync is turned off in this build")
        }

        // Deliberately answered without touching CloudKit when no account is
        // present. CloudKit does not report a missing entitlement as an error,
        // it traps (SIGTRAP), and the entitlement cannot be read back at
        // runtime on iOS — so the safest thing is to call it as rarely as
        // possible. This covers both the simulator and the common
        // "not signed in" case.
        //
        // Residual caveat: a build that is signed *without* the iCloud
        // entitlement but runs on a device with an account will still trap
        // inside CloudKit. That combination means the capability was dropped
        // from the target, which the checklist in the README covers.
        guard hasSignedInAccount else {
            logger.info("No iCloud account on this device; sync unavailable.")
            return .noAccount
        }

        do {
            let container = CKContainer(
                identifier: MemoModelContainer.cloudKitContainerIdentifier
            )
            let status = try await container.accountStatus()

            let result: CloudSyncStatus = switch status {
            case .available:                    .available
            case .noAccount:                    .noAccount
            case .restricted:                   .restricted
            case .couldNotDetermine, .temporarilyUnavailable: .unknown
            @unknown default:                   .unknown
            }

            logger.info("iCloud account status: \(result.userDescription, privacy: .public)")
            return result
        } catch {
            // A missing or misconfigured container surfaces here rather than at
            // store-open time.
            logger.error("iCloud unavailable: \(error.localizedDescription, privacy: .public)")
            return .notConfigured(error.localizedDescription)
        }
    }
}
