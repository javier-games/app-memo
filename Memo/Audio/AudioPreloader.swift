//
//  AudioPreloader.swift
//  Memo
//

import Foundation
import SwiftData

/// Reads recordings from the store away from the main thread.
///
/// Recordings are kept outside the database file, so reading one is a trip to
/// disk. Made at the moment a side is shown, that trip landed in the middle of
/// the card's animation.
@ModelActor
actor AudioPreloader {

    /// The sound of each recording that has some, by its id.
    func load(_ ids: [PersistentIdentifier]) -> [UUID: Data] {
        var loaded: [UUID: Data] = [:]

        for id in ids {
            guard let recording = self[id, as: CardAudio.self], let data = recording.data else { continue }
            loaded[recording.uuid] = data
        }

        return loaded
    }
}
