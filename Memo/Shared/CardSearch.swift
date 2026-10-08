//
//  CardSearch.swift
//  Memo
//

import Foundation

/// Finding decks and cards by what they say.
///
/// Matching ignores case and accents, as search fields on the system do: a
/// deck of Spanish or Japanese is searched by people who will not always type
/// the accent.
enum CardSearch {

    /// A card found in a search across decks, with the deck it is in.
    struct Hit: Identifiable {
        let card: Card
        let deck: Deck

        var id: UUID { card.uuid }
    }

    /// The query as typed, without the spaces round it. Empty means there is
    /// no search.
    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(_ card: Card, _ query: String) -> Bool {
        [card.frontText, card.backText, card.frontHintText, card.backHintText]
            .contains { $0.localizedStandardContains(query) }
    }

    static func cards(in cards: [Card], matching query: String) -> [Card] {
        let query = normalized(query)
        guard !query.isEmpty else { return [] }

        return cards.filter { matches($0, query) }
    }

    static func decks(in decks: [Deck], matching query: String) -> [Deck] {
        let query = normalized(query)
        guard !query.isEmpty else { return [] }

        return decks.filter { $0.name.localizedStandardContains(query) }
    }

    /// Matching cards from every deck, in the decks' order. Capped: a short
    /// query in a large library matches most of it, and nobody scrolls
    /// through hundreds of results to find one card.
    static func hits(in decks: [Deck], matching query: String, limit: Int = 50) -> [Hit] {
        let query = normalized(query)
        guard !query.isEmpty else { return [] }

        var hits: [Hit] = []

        for deck in decks {
            for card in deck.orderedCards where matches(card, query) {
                hits.append(Hit(card: card, deck: deck))
                if hits.count == limit { return hits }
            }
        }

        return hits
    }
}
