//
//  CardAudio.swift
//  Memo
//

import Foundation
import SwiftData

/// Where on a card a recording belongs.
enum AudioSlot: String, CaseIterable, Codable, Identifiable {

    case front
    case frontHint
    case back
    case backHint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front:     String(localized: "Front")
        case .frontHint: String(localized: "Front Hint")
        case .back:      String(localized: "Back")
        case .backHint:  String(localized: "Back Hint")
        }
    }
}

/// One recording on a card.
///
/// Its own model rather than four properties on ``Card``, so a card with no
/// audio carries nothing, and a new kind of recording is a new slot rather
/// than a new column. The sound itself is kept outside the store's database
/// file: loading a deck never reads it, and each clip is read only when it
/// plays. CloudKit carries it as a file attached to the record.
@Model
final class CardAudio {

    var uuid: UUID = UUID()

    /// An ``AudioSlot`` raw value. Stored as text so a slot added later reads
    /// back as nothing rather than failing to load.
    var slotRawValue: String = AudioSlot.front.rawValue

    /// Seconds.
    var duration: Double = 0

    /// `m4a` when recorded here; `mp3` and others when imported.
    var fileExtension: String = "m4a"

    @Attribute(.externalStorage)
    var data: Data?

    var createdAt: Date = Date.distantPast

    var card: Card?

    init(
        uuid: UUID = UUID(),
        slot: AudioSlot,
        data: Data,
        duration: Double,
        fileExtension: String = "m4a",
        createdAt: Date = Date()
    ) {
        self.uuid = uuid
        self.slotRawValue = slot.rawValue
        self.data = data
        self.duration = duration
        self.fileExtension = fileExtension
        self.createdAt = createdAt
    }

    var slot: AudioSlot? { AudioSlot(rawValue: slotRawValue) }
}

extension Card {

    /// The recording in `slot`, if any. The newest wins, should two devices
    /// have each recorded one before syncing.
    func audio(for slot: AudioSlot) -> CardAudio? {
        (audios ?? [])
            .filter { $0.slot == slot && !$0.isDeleted }
            .max { $0.createdAt < $1.createdAt }
    }

    var hasAudio: Bool { (audios ?? []).contains { !$0.isDeleted } }
}
