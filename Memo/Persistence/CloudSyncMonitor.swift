//
//  CloudSyncMonitor.swift
//  Memo
//

import CoreData
import Foundation
import OSLog

/// What sync has been doing, as far as the events it reports show.
///
/// A plain value, apart from the notifications that feed it, so the rules can
/// be tested without CloudKit.
struct CloudSyncActivity: Equatable {

    /// Uploads and downloads that have started and not yet finished.
    private(set) var running: Set<UUID> = []

    private(set) var lastSuccess: Date?

    /// The most recent failure, cleared by the next success.
    private(set) var lastError: String?

    var isSyncing: Bool { !running.isEmpty }

    mutating func started(_ id: UUID) {
        running.insert(id)
    }

    mutating func finished(_ id: UUID, at date: Date, error: String?) {
        running.remove(id)

        if let error {
            lastError = error
        } else {
            lastError = nil
            lastSuccess = date
        }
    }

    /// A short line for a settings row.
    var summary: String {
        if isSyncing { return String(localized: "Syncing…") }
        if lastError != nil { return String(localized: "Not syncing") }
        if lastSuccess != nil { return String(localized: "Up to date") }
        return String(localized: "Waiting")
    }
}

/// Listens to the store's sync events for as long as the app runs.
///
/// ``CloudSyncStatus`` only says whether an iCloud account is there. This says
/// whether anything is actually moving, and what went wrong if it is not —
/// which is otherwise invisible, because a store that cannot reach CloudKit
/// carries on working locally without complaint.
///
/// SwiftData syncs through Core Data's CloudKit container, so its events
/// arrive as that container's notification.
@Observable
final class CloudSyncMonitor {

    private(set) var activity = CloudSyncActivity()

    @ObservationIgnored private var observer: NSObjectProtocol?

    @ObservationIgnored
    private static let logger = Logger(
        subsystem: AppConfiguration.loggingSubsystem,
        category: "Sync"
    )

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event
            else { return }

            self?.record(event)
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private func record(_ event: NSPersistentCloudKitContainer.Event) {
        guard let endDate = event.endDate else {
            activity.started(event.identifier)
            return
        }

        if let error = event.error {
            // The full error goes to the log: its description is often only a
            // code, and the detail is what identifies a schema problem.
            Self.logger.error("Sync event failed: \(String(describing: error), privacy: .public)")
        }

        activity.finished(
            event.identifier,
            at: endDate,
            error: event.error?.localizedDescription
        )
    }
}
