//
//  LegacyStoreImport.swift
//  Memo
//
//  One-time import of the pre-SwiftData library, which lived as a single JSON
//  blob under the `DeckList` key in UserDefaults.
//

import Foundation
import SwiftData
import OSLog

enum LegacyStoreImport {

    private static let legacyKey = "DeckList"
    private static let backupKey = "DeckList.preSwiftDataBackup"
    private static let completedKey = "LegacyStoreImport.completed"

    private static let logger = Logger(
        subsystem: AppConfiguration.loggingSubsystem,
        category: "Migration"
    )

    /// Imports the legacy library into `context` if it has not been imported yet.
    ///
    /// Safe to call on every launch: it is guarded both by a completion flag and
    /// by the absence of the legacy key.
    ///
    /// The old blob is written in the same shape as an exported deck file, so
    /// this reuses ``DeckTransferFile`` and ``DeckImporter`` rather than keeping
    /// a second parser that could drift from it.
    static func runIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: completedKey) else { return }

        guard let data = defaults.data(forKey: legacyKey) else {
            // Nothing to import — a fresh install. Mark it done so we do not
            // re-check on every launch.
            defaults.set(true, forKey: completedKey)
            return
        }

        do {
            let file = try JSONDecoder().decode(DeckTransferFile.self, from: data)

            // Inserted unfiltered: this is the user's own library being moved,
            // not a file of unknown provenance, so nothing is dropped for being
            // incomplete.
            let imported = DeckImporter.insert(
                DeckImporter.Preview(decks: file.deckList, skippedCardCount: 0),
                into: context,
                after: 0
            )
            try context.save()

            // Keep the original payload rather than deleting it. If anything
            // about the new store goes wrong, the user's library is still here.
            defaults.set(data, forKey: backupKey)
            defaults.removeObject(forKey: legacyKey)
            defaults.set(true, forKey: completedKey)

            logger.info("Imported \(imported.count) legacy deck(s) into SwiftData.")
        } catch {
            // Leave the legacy key untouched so a future build can retry.
            logger.error("Legacy import failed, keeping original data: \(error.localizedDescription)")
        }
    }
}
