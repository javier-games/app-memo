//
//  QuickPracticeTests.swift
//  MemoTests
//

import XCTest
import SwiftData
@testable import Memo

@MainActor
final class QuickPracticeTests: XCTestCase {

    private func makeContext() -> ModelContext {
        ModelContext(MemoModelContainer.makeInMemoryContainer())
    }

    private func makeDeck(_ name: String, cards count: Int, in context: ModelContext) -> Deck {
        let deck = Deck(name: name)
        context.insert(deck)

        for index in 0..<count {
            let card = Card(frontText: "\(name) \(index)", backText: "B\(index)", sortIndex: index)
            context.insert(card)
            card.deck = deck
        }

        return deck
    }

    private func makeDefaults(function: String = #function) -> UserDefaults {
        let suite = "test.quick.practice.\(function).\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - Defaults

    func testDefaultsDrawTenCardsFromEveryDeck() {
        let settings = QuickPracticeSettings.default

        XCTAssertNil(settings.deckIDs, "nil means every deck, including ones added later")
        XCTAssertEqual(settings.cardCount, 10)
        XCTAssertFalse(settings.isInverted)
        XCTAssertEqual(settings.errorPenalty, .none)
        XCTAssertEqual(settings.mode, .random)
    }

    // MARK: - Choosing decks

    func testAllDecksIsEveryDeck() {
        let context = makeContext()
        let decks = [makeDeck("A", cards: 1, in: context), makeDeck("B", cards: 1, in: context)]

        XCTAssertEqual(QuickPracticeSettings().decks(from: decks).map(\.name), ["A", "B"])
    }

    func testChosenDecksKeepTheLibraryOrderAndSkipDeletedOnes() {
        let context = makeContext()
        let a = makeDeck("A", cards: 1, in: context)
        let b = makeDeck("B", cards: 1, in: context)
        let c = makeDeck("C", cards: 1, in: context)

        let settings = QuickPracticeSettings(deckIDs: [c.uuid, UUID(), a.uuid])

        XCTAssertEqual(settings.decks(from: [a, b, c]).map(\.name), ["A", "C"])
    }

    // MARK: - The run

    func testRunUsesTheChosenOptions() {
        let quick = QuickPracticeSettings(isInverted: true, mode: .leastPracticed, cardCount: 7, practiceTarget: 4, errorPenalty: .reset)
        let settings = quick.practiceSettings(audioPlayback: .manual, bookmarkFallback: .inOrder)

        XCTAssertEqual(settings.mode, .leastPracticed)
        XCTAssertTrue(settings.isInverted)
        XCTAssertEqual(settings.cardLimit, 7)
        XCTAssertEqual(settings.practiceTarget, 4)
        XCTAssertEqual(settings.errorPenalty, .reset)
        XCTAssertEqual(settings.audioPlayback, .manual)
    }

    func testRunDrawsFromEveryChosenDeckUpToTheCount() {
        let context = makeContext()
        let decks = [makeDeck("A", cards: 8, in: context), makeDeck("B", cards: 8, in: context)]
        let settings = QuickPracticeSettings().practiceSettings(audioPlayback: .manual, bookmarkFallback: .random)

        let cards = PracticeSource.decks(decks).cards(settings: settings)

        XCTAssertEqual(cards.count, 10)
        XCTAssertEqual(Set(cards.map(\.uuid)).count, 10, "no card is dealt twice")
    }

    func testSmallLibraryDealsEveryCard() {
        let context = makeContext()
        let decks = [makeDeck("A", cards: 3, in: context), makeDeck("B", cards: 2, in: context)]
        let settings = QuickPracticeSettings().practiceSettings(audioPlayback: .manual, bookmarkFallback: .random)

        XCTAssertEqual(PracticeSource.decks(decks).cards(settings: settings).count, 5)
    }

    func testInOrderStillDealsTheCardCount() {
        let context = makeContext()
        let decks = [makeDeck("A", cards: 8, in: context), makeDeck("B", cards: 8, in: context)]
        let settings = QuickPracticeSettings(mode: .inOrder)
            .practiceSettings(audioPlayback: .manual, bookmarkFallback: .random)

        let fronts = PracticeSource.decks(decks).cards(settings: settings).map(\.frontText)

        XCTAssertEqual(fronts, (0..<8).map { "A \($0)" } + ["B 0", "B 1"])
    }

    func testLeastPracticedDrawsAcrossDecks() {
        let context = makeContext()
        let a = makeDeck("A", cards: 3, in: context)
        let b = makeDeck("B", cards: 3, in: context)
        a.orderedCards.forEach { $0.practiceProgress = 5 }
        b.orderedCards[2].practiceProgress = 5

        let settings = QuickPracticeSettings(mode: .leastPracticed, cardCount: 2)
            .practiceSettings(audioPlayback: .manual, bookmarkFallback: .random)

        XCTAssertEqual(
            PracticeSource.decks([a, b]).cards(settings: settings).map(\.frontText),
            ["B 0", "B 1"]
        )
    }

    func testBookmarkedDealsOnlyBookmarks() {
        let context = makeContext()
        let a = makeDeck("A", cards: 4, in: context)
        let b = makeDeck("B", cards: 4, in: context)
        a.orderedCards[1].isBookmarked = true
        b.orderedCards[3].isBookmarked = true

        let settings = QuickPracticeSettings(mode: .bookmarked)
            .practiceSettings(audioPlayback: .manual, bookmarkFallback: .random)

        XCTAssertEqual(
            Set(PracticeSource.decks([a, b]).cards(settings: settings).map(\.frontText)),
            ["A 1", "B 3"]
        )
    }

    // MARK: - Saving

    func testOptionsSurviveARelaunch() {
        let defaults = makeDefaults()
        let id = UUID()
        PracticeSettingsStore(defaults: defaults).quickPractice = QuickPracticeSettings(deckIDs: [id], cardCount: 25)

        let reloaded = PracticeSettingsStore(defaults: defaults).quickPractice
        XCTAssertEqual(reloaded.deckIDs, [id])
        XCTAssertEqual(reloaded.cardCount, 25)
    }

    func testMissingFieldsFallBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(QuickPracticeSettings.self, from: Data(#"{"cardCount":5}"#.utf8))

        XCTAssertEqual(decoded.cardCount, 5)
        XCTAssertNil(decoded.deckIDs)
        XCTAssertEqual(decoded.mode, .random)
        XCTAssertEqual(decoded.practiceTarget, QuickPracticeSettings.default.practiceTarget)
    }
}
