//
//  Deck.swift
//  Memo
//

import Foundation
import SwiftData

/// A named collection of ``Card``s.
///
/// The model layer stores colour as four plain components rather than a
/// `SwiftUI.Color`. Keeping UI types out of the model means the stored value is
/// lossless and appearance-independent; the previous `"r,g,b,a"` string format
/// silently flattened adaptive colours to whatever the current trait collection
/// happened to resolve to. Bridging to `Color` lives in `Color+Memo.swift`.
@Model
final class Deck {

    /// Stable, content-independent identity that survives a sync round trip.
    ///
    /// Distinct from `persistentModelID`, which is local to one store. This is
    /// the identity used for export/import and cross-device de-duplication.
    var uuid: UUID = UUID()

    var name: String = ""
    var icon: String = ""

    var colorRed: Double = 1
    var colorGreen: Double = 1
    var colorBlue: Double = 1
    var colorAlpha: Double = 1

    /// Explicit ordering; see the note on ``Card/sortIndex``.
    var sortIndex: Int = 0

    var createdAt: Date = Date.distantPast

    /// This deck's own practice options, encoded, or `nil` while it follows
    /// the app-wide defaults. Read and written through ``practiceSettings``.
    ///
    /// Stored as one encoded value, like the defaults are, so adding a rule
    /// needs no new property here and no change to the CloudKit schema.
    var practiceSettingsData: Data?

    /// Optional-and-inverse is required by CloudKit. Deleting a deck cascades to
    /// its cards so no orphan records are left behind on other devices.
    @Relationship(deleteRule: .cascade, inverse: \Card.deck)
    var cards: [Card]? = []

    init(
        uuid: UUID = UUID(),
        name: String = "",
        icon: String = "",
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.uuid = uuid
        self.name = name
        self.icon = icon
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.cards = []
    }
}

extension Deck {

    /// The deck's cards in their authored order.
    ///
    /// `cards` is an optional, unordered relationship because of CloudKit, so
    /// every read goes through here rather than touching the raw array.
    var orderedCards: [Card] {
        (cards ?? []).sorted { lhs, rhs in
            lhs.sortIndex == rhs.sortIndex
                ? lhs.createdAt < rhs.createdAt
                : lhs.sortIndex < rhs.sortIndex
        }
    }

    var cardCount: Int { cards?.count ?? 0 }

    var hasBookmarkedCards: Bool {
        (cards ?? []).contains(where: \.isBookmarked)
    }

    /// The options set for this deck, or `nil` while it has none of its own
    /// and uses ``PracticeSettings/default``.
    var practiceSettings: PracticeSettings? {
        get {
            practiceSettingsData.flatMap { try? JSONDecoder().decode(PracticeSettings.self, from: $0) }
        }
        set {
            practiceSettingsData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    /// The options a practice run of this deck uses.
    ///
    /// What to do when a deck has no bookmarks is the one choice made for
    /// every deck at once, in Settings, so it is passed in and replaces
    /// whatever the deck's own options carry.
    func resolvedPracticeSettings(bookmarkFallback: PracticeMode) -> PracticeSettings {
        var settings = practiceSettings ?? .default
        settings.bookmarkFallbackMode = bookmarkFallback
        return settings
    }

    /// Appends a card, assigning it the next free sort index.
    func append(_ card: Card) {
        card.sortIndex = (cards?.map(\.sortIndex).max() ?? -1) + 1
        card.deck = self
        if cards == nil { cards = [] }
        cards?.append(card)
    }

    /// The cards complete enough to practise, in the deck's own order.
    ///
    /// Selecting and ordering a run is ``PracticePlanner``'s job; this is only
    /// the pool it draws from.
    var practisableCards: [Card] {
        orderedCards.filter(\.isComplete)
    }

    var hasPractisableCards: Bool {
        orderedCards.contains(where: \.isComplete)
    }
}
