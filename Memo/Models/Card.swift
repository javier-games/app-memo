//
//  Card.swift
//  Memo
//

import Foundation
import SwiftData

/// A single flash card belonging to a ``Deck``.
///
/// Every stored property carries a default value and the `deck` relationship is
/// optional: both are hard requirements of the CloudKit-backed store, which has
/// to be able to materialise a record before its fields arrive from the server.
@Model
final class Card {

    /// Stable, content-independent identity that survives a sync round trip.
    ///
    /// Distinct from `persistentModelID`, which is local to one store. This is
    /// the identity used for export/import and cross-device de-duplication.
    ///
    /// CloudKit does not support `@Attribute(.unique)`, so uniqueness is a local
    /// invariant maintained by the import path rather than a store constraint.
    var uuid: UUID = UUID()

    var frontText: String = ""
    var frontHintText: String = ""
    var backText: String = ""
    var backHintText: String = ""

    /// Explicit ordering. CloudKit relationships are unordered sets, so card
    /// order has to be a stored property rather than an array position.
    var sortIndex: Int = 0

    var createdAt: Date = Date.distantPast

    /// Consecutive correct answers, reset to zero by a wrong one.
    ///
    /// Defaulted like every other property so the CloudKit-backed store can
    /// materialise a record before its fields arrive, which also makes this a
    /// lightweight SwiftData migration for anyone upgrading.
    var practiceProgress: Int = 0

    /// When the card's text was last changed, here or by an import. What an
    /// import compares to tell a newer version of the card from an older one.
    var modifiedAt: Date = Date.distantPast

    /// Marked by the user for the Bookmarked practice mode.
    var isBookmarked: Bool = false

    // MARK: Review Schedule
    //
    // Kept on this device and in iCloud only: none of these are part of a
    // deck's JSON, since they describe the user's practice, not the card.

    /// When the card was last answered, right or wrong. A Review Schedule
    /// period in which the card was answered takes nothing off.
    var lastAnsweredAt: Date?

    /// Whether the Review Schedule lowers this card's progress over time.
    /// Turned on the first time the card is fully learned.
    var isReviewScheduleEnabled: Bool = false

    /// When the card was fully learned: where its Review Schedule starts.
    /// The user can move it to today from the card editor.
    var learnedAt: Date?

    /// The last Review Schedule checkpoint already dealt with, so none is
    /// applied twice.
    var reviewCheckedAt: Date?

    var deck: Deck?

    /// Recordings for the card's sides and hints; see ``CardAudio``. Deleting
    /// the card deletes them, on every device.
    @Relationship(deleteRule: .cascade, inverse: \CardAudio.card)
    var audios: [CardAudio]? = []

    init(
        uuid: UUID = UUID(),
        frontText: String = "",
        backText: String = "",
        frontHintText: String = "",
        backHintText: String = "",
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        practiceProgress: Int = 0
    ) {
        self.uuid = uuid
        self.frontText = frontText
        self.backText = backText
        self.frontHintText = frontHintText
        self.backHintText = backHintText
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.practiceProgress = practiceProgress
    }
}

extension Card {

    /// Whether the card carries enough content to be worth practising.
    var isComplete: Bool {
        !frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasFrontHint: Bool { !frontHintText.isEmpty }
    var hasBackHint: Bool { !backHintText.isEmpty }
}
