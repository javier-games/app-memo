//
//  DeckImportPlan.swift
//  Memo
//
//  What importing a file would do to the library, worked out before anything
//  is written. A deck in the file whose identifier matches one in the library
//  updates that deck instead of being added beside it.
//

import Foundation
import SwiftData

struct DeckImportPlan: Identifiable {

    let id = UUID()

    /// How the file's version of something compares with the library's.
    enum Standing {
        /// The two say the same thing.
        case unchanged
        /// They differ and the file is newer, so it simply wins.
        case update
        /// They differ and the file is not newer: taking it would discard an
        /// edit made here, so the user decides.
        case conflict
    }

    struct CardChange {
        let card: Card
        let incoming: DeckTransferCard
    }

    /// What the file would do to one deck already in the library.
    struct DeckChange {
        let deck: Deck
        let incoming: DeckTransferDeck

        /// The deck's own name, icon and colour.
        var details = Standing.unchanged

        var newCards: [DeckTransferCard] = []
        var updatedCards: [CardChange] = []
        var conflictingCards: [CardChange] = []
    }

    /// One disagreement, in a form that can be shown.
    struct Conflict: Identifiable {
        let id = UUID()
        let deckName: String
        let mine: String
        let theirs: String
    }

    /// Decks in the file that match nothing in the library.
    var newDecks: [DeckTransferDeck] = []

    var changes: [DeckChange] = []

    /// Cards found but left out because they had no front or no back.
    var skippedCardCount = 0

    // MARK: - Counts

    var newDeckCount: Int { newDecks.count }

    var newCardCount: Int {
        newDecks.reduce(0) { $0 + $1.cardList.count }
            + changes.reduce(0) { $0 + $1.newCards.count }
    }

    var updatedDeckCount: Int { changes.filter { $0.details == .update }.count }

    var updatedCardCount: Int { changes.reduce(0) { $0 + $1.updatedCards.count } }

    var conflicts: [Conflict] {
        changes.flatMap { change -> [Conflict] in
            var found: [Conflict] = []

            if change.details == .conflict {
                found.append(Conflict(
                    deckName: change.deck.name,
                    mine: "\(change.deck.icon) \(change.deck.name)",
                    theirs: "\(change.incoming.icon) \(change.incoming.name)"
                ))
            }

            found += change.conflictingCards.map { conflict in
                Conflict(
                    deckName: change.deck.name,
                    mine: Self.describe(DeckTransferCard(card: conflict.card)),
                    theirs: Self.describe(conflict.incoming)
                )
            }

            return found
        }
    }

    var hasConflicts: Bool {
        changes.contains { $0.details == .conflict || !$0.conflictingCards.isEmpty }
    }

    /// Whether there is anything to do besides settling conflicts.
    var hasChangesToApply: Bool {
        newDeckCount + newCardCount + updatedDeckCount + updatedCardCount > 0
    }

    private static func describe(_ card: DeckTransferCard) -> String {
        let sides = "\(card.frontText) → \(card.backText)"
        let hints = [card.frontHintText, card.backHintText].filter { !$0.isEmpty }

        return hints.isEmpty ? sides : "\(sides) (\(hints.joined(separator: ", ")))"
    }
}

extension DeckImporter {

    // MARK: - Planning

    /// Works out what `preview` would do to a library holding `decks`.
    static func plan(_ preview: Preview, against decks: [Deck]) -> DeckImportPlan {
        var plan = DeckImportPlan(skippedCardCount: preview.skippedCardCount)

        // The first deck with an identifier wins, in the unlikely event that
        // two share one.
        let library = Dictionary(decks.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })

        for incoming in preview.decks {
            guard let id = incoming.uuid, let deck = library[id] else {
                plan.newDecks.append(incoming)
                continue
            }

            plan.changes.append(change(to: deck, from: incoming))
        }

        return plan
    }

    private static func change(to deck: Deck, from incoming: DeckTransferDeck) -> DeckImportPlan.DeckChange {
        var change = DeckImportPlan.DeckChange(deck: deck, incoming: incoming)

        change.details = standing(
            differs: detailsDiffer(deck, incoming),
            fileDate: incoming.modifiedDate,
            libraryDate: deck.modifiedAt
        )

        let cards = Dictionary(
            (deck.cards ?? []).map { ($0.uuid, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for incomingCard in incoming.cardList {
            guard let id = incomingCard.uuid, let card = cards[id] else {
                change.newCards.append(incomingCard)
                continue
            }

            let pair = DeckImportPlan.CardChange(card: card, incoming: incomingCard)

            switch standing(
                differs: textDiffers(card, incomingCard),
                fileDate: incomingCard.modifiedDate,
                libraryDate: card.modifiedAt
            ) {
            case .unchanged: break
            case .update:    change.updatedCards.append(pair)
            case .conflict:  change.conflictingCards.append(pair)
            }
        }

        return change
    }

    /// A difference is an update only when the file is strictly newer. A file
    /// with no date, or the same date, cannot claim to be: the same date with
    /// different text means one side was changed without the date moving.
    private static func standing(
        differs: Bool,
        fileDate: Date?,
        libraryDate: Date
    ) -> DeckImportPlan.Standing {
        guard differs else { return .unchanged }
        guard let fileDate, fileDate > libraryDate else { return .conflict }
        return .update
    }

    /// A field the file leaves out is not a difference: a hand-written file
    /// may give only what its author cares about.
    private static func detailsDiffer(_ deck: Deck, _ incoming: DeckTransferDeck) -> Bool {
        let current = DeckTransferDeck(details: deck)

        if !incoming.name.isEmpty, incoming.name != current.name { return true }
        if !incoming.icon.isEmpty, incoming.icon != current.icon { return true }
        if let color = normalizedColor(incoming.color), color != current.color { return true }

        return false
    }

    /// The colour re-encoded, so spacing in the file is not a difference, or
    /// `nil` if the file gives none.
    private static func normalizedColor(_ string: String) -> String? {
        guard string.split(separator: ",").count == 4 else { return nil }

        let color = DeckTransferColor.components(from: string)
        return DeckTransferColor.string(
            red: color.red, green: color.green, blue: color.blue, alpha: color.alpha
        )
    }

    private static func textDiffers(_ card: Card, _ incoming: DeckTransferCard) -> Bool {
        let trimmed = { (text: String) in text.trimmingCharacters(in: .whitespacesAndNewlines) }

        return trimmed(incoming.frontText) != card.frontText
            || trimmed(incoming.frontHintText) != card.frontHintText
            || trimmed(incoming.backText) != card.backText
            || trimmed(incoming.backHintText) != card.backHintText
    }

    // MARK: - Applying

    /// Carries out `plan`.
    ///
    /// New decks and cards are added and newer versions are taken either way.
    /// `overwritingConflicts` decides only the conflicts: taken from the file,
    /// or left as they are in the library. Nothing is ever deleted — a card
    /// missing from the file stays.
    static func apply(
        _ plan: DeckImportPlan,
        overwritingConflicts: Bool,
        into context: ModelContext,
        after existingDeckCount: Int
    ) {
        var takenIDs = existingIDs(in: context)

        for (offset, transferDeck) in plan.newDecks.enumerated() {
            _ = insert(
                transferDeck,
                sortIndex: existingDeckCount + offset,
                takenIDs: &takenIDs,
                into: context
            )
        }

        for change in plan.changes {
            if change.details == .update || (change.details == .conflict && overwritingConflicts) {
                applyDetails(of: change.incoming, to: change.deck)
            }

            let cards = change.updatedCards + (overwritingConflicts ? change.conflictingCards : [])
            for pair in cards {
                applyText(of: pair.incoming, to: pair.card)
            }

            for incoming in change.newCards {
                let card = makeCard(from: incoming, sortIndex: 0, takenIDs: &takenIDs)
                context.insert(card)
                change.deck.append(card)
            }
        }
    }

    private static func applyDetails(of incoming: DeckTransferDeck, to deck: Deck) {
        if !incoming.name.isEmpty { deck.name = incoming.name }
        if !incoming.icon.isEmpty { deck.icon = incoming.icon }

        if normalizedColor(incoming.color) != nil {
            let color = DeckTransferColor.components(from: incoming.color)
            deck.colorRed = color.red
            deck.colorGreen = color.green
            deck.colorBlue = color.blue
            deck.colorAlpha = color.alpha
        }

        deck.modifiedAt = incoming.modifiedDate ?? Date()
    }

    /// Progress and bookmarks are left alone: they belong to whoever is
    /// practising here, and the file does not carry them.
    private static func applyText(of incoming: DeckTransferCard, to card: Card) {
        let trimmed = { (text: String) in text.trimmingCharacters(in: .whitespacesAndNewlines) }

        card.frontText = trimmed(incoming.frontText)
        card.frontHintText = trimmed(incoming.frontHintText)
        card.backText = trimmed(incoming.backText)
        card.backHintText = trimmed(incoming.backHintText)
        card.modifiedAt = incoming.modifiedDate ?? Date()
    }
}
