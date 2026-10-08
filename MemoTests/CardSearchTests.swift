//
//  CardSearchTests.swift
//  MemoTests
//

import XCTest
import SwiftData
@testable import Memo

@MainActor
final class CardSearchTests: XCTestCase {

    private func makeDeck(_ name: String, in context: ModelContext, cards: [(String, String)]) -> Deck {
        let deck = Deck(name: name, icon: "🥩", sortIndex: 0)
        context.insert(deck)

        for (index, pair) in cards.enumerated() {
            let card = Card(frontText: pair.0, backText: pair.1, sortIndex: index)
            context.insert(card)
            card.deck = deck
        }

        return deck
    }

    private func makeContext() -> ModelContext {
        ModelContext(MemoModelContainer.makeInMemoryContainer())
    }

    func testEitherSideAndTheHintsAreSearched() {
        let card = Card(
            frontText: "食べる", backText: "To Eat",
            frontHintText: "たべる", backHintText: "a meal"
        )

        XCTAssertTrue(CardSearch.matches(card, "食べ"))
        XCTAssertTrue(CardSearch.matches(card, "eat"))
        XCTAssertTrue(CardSearch.matches(card, "たべ"))
        XCTAssertTrue(CardSearch.matches(card, "meal"))
        XCTAssertFalse(CardSearch.matches(card, "drink"))
    }

    func testCaseAndAccentsAreIgnored() {
        let card = Card(frontText: "Tea", backText: "Té")

        XCTAssertTrue(CardSearch.matches(card, "TEA"))
        XCTAssertTrue(CardSearch.matches(card, "te"))
    }

    func testABlankQueryFindsNothing() {
        let cards = [Card(frontText: "Tea", backText: "Té")]

        XCTAssertTrue(CardSearch.cards(in: cards, matching: "").isEmpty)
        XCTAssertTrue(CardSearch.cards(in: cards, matching: "   ").isEmpty)
        XCTAssertEqual(CardSearch.cards(in: cards, matching: " tea ").count, 1)
    }

    func testDecksAreFoundByName() {
        let context = makeContext()
        let food = makeDeck("Spanish Food", in: context, cards: [("Tea", "Té")])
        let verbs = makeDeck("Verbs", in: context, cards: [("Eat", "Comer")])

        XCTAssertEqual(CardSearch.decks(in: [food, verbs], matching: "food").map(\.name), ["Spanish Food"])
        XCTAssertTrue(CardSearch.decks(in: [food, verbs], matching: "").isEmpty)
    }

    func testCardsAreFoundAcrossDecksWithTheirDeck() {
        let context = makeContext()
        let food = makeDeck("Food", in: context, cards: [("Tea", "Té"), ("Bread", "Pan")])
        let verbs = makeDeck("Verbs", in: context, cards: [("Eat", "Comer"), ("Teach", "Enseñar")])

        let hits = CardSearch.hits(in: [food, verbs], matching: "tea")

        XCTAssertEqual(hits.map(\.card.frontText), ["Tea", "Teach"])
        XCTAssertEqual(hits.map(\.deck.name), ["Food", "Verbs"])
    }

    func testResultsAreCapped() {
        let context = makeContext()
        let deck = makeDeck("Many", in: context, cards: (0..<30).map { ("Card \($0)", "Back") })

        XCTAssertEqual(CardSearch.hits(in: [deck], matching: "card", limit: 10).count, 10)
    }
}
