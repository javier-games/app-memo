//
//  BookmarkTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class BookmarkTests: XCTestCase {

    private func makeCards(_ count: Int, bookmarked: Set<Int> = []) -> [Card] {
        (0..<count).map { index in
            let card = Card(frontText: "F\(index)", backText: "B\(index)", sortIndex: index)
            card.isBookmarked = bookmarked.contains(index)
            return card
        }
    }

    private var bookmarkedMode: PracticeSettings {
        var settings = PracticeSettings()
        settings.mode = .bookmarked
        return settings
    }

    // MARK: - Planning

    func testBookmarkedModeDealsOnlyBookmarkedCards() {
        let cards = makeCards(10, bookmarked: [2, 5, 7])

        let plan = PracticePlanner.plan(from: cards, settings: bookmarkedMode)

        XCTAssertEqual(Set(plan.map(\.frontText)), ["F2", "F5", "F7"])
    }

    func testCardLimitCountsAgainstTheBookmarkedCards() {
        var settings = bookmarkedMode
        settings.cardLimit = 2

        let plan = PracticePlanner.plan(from: makeCards(10, bookmarked: [2, 5, 7]), settings: settings)

        XCTAssertEqual(plan.count, 2)
        XCTAssertTrue(plan.allSatisfy(\.isBookmarked))
    }

    func testWithNoBookmarksTheFallbackModeIsUsed() {
        var settings = bookmarkedMode
        settings.bookmarkFallbackMode = .all
        settings.isShuffled = false

        let plan = PracticePlanner.plan(from: makeCards(6), settings: settings)

        XCTAssertEqual(plan.map(\.frontText), ["F0", "F1", "F2", "F3", "F4", "F5"])
    }

    func testFallbackKeepsTheCardLimitWhereItsModeAllowsOne() {
        var settings = bookmarkedMode
        settings.bookmarkFallbackMode = .leastPracticed
        settings.cardLimit = 3

        XCTAssertEqual(PracticePlanner.plan(from: makeCards(6), settings: settings).count, 3)
    }

    func testFallbackCanNeverBeBookmarkedItself() {
        var settings = bookmarkedMode
        settings.bookmarkFallbackMode = .bookmarked

        XCTAssertEqual(settings.resolvedBookmarkFallbackMode, .all)
        XCTAssertEqual(PracticePlanner.plan(from: makeCards(4), settings: settings).count, 4)
        XCTAssertFalse(PracticeMode.fallbacks.contains(.bookmarked))
        XCTAssertFalse(PracticeMode.fallbacks.contains(.review))
    }

    // MARK: - Settings

    func testBookmarkedModeCapabilities() {
        XCTAssertTrue(PracticeMode.bookmarked.needsFallback)
        XCTAssertFalse(PracticeMode.bookmarked.ordersByProgress)
    }

    func testUnshuffledBookmarksKeepDeckOrder() {
        var settings = bookmarkedMode
        settings.isShuffled = false

        let plan = PracticePlanner.plan(from: makeCards(10, bookmarked: [7, 2, 5]), settings: settings)

        XCTAssertEqual(plan.map(\.frontText), ["F2", "F5", "F7"])
    }

    func testFallbackModeSurvivesARoundTrip() throws {
        var settings = bookmarkedMode
        settings.bookmarkFallbackMode = .leastPracticed

        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(PracticeSettings.self, from: data), settings)
    }

    func testAnOlderPayloadGetsTheDefaultFallback() throws {
        let decoded = try JSONDecoder().decode(
            PracticeSettings.self,
            from: Data(#"{"mode":"inOrder","isInverted":true}"#.utf8)
        )

        XCTAssertEqual(decoded.bookmarkFallbackMode, .all)
    }

    // MARK: - Per-deck options

    func testADeckUsesTheStandardOptionsUntilItHasItsOwn() {
        let deck = Deck(name: "Food")
        XCTAssertNil(deck.practiceSettings)
        XCTAssertEqual(deck.resolvedPracticeSettings(bookmarkFallback: .all), .default)

        var own = PracticeSettings()
        own.mode = .leastPracticed
        own.isInverted = true
        deck.practiceSettings = own

        let resolved = deck.resolvedPracticeSettings(bookmarkFallback: .all)
        XCTAssertEqual(resolved.mode, .leastPracticed)
        XCTAssertTrue(resolved.isInverted)

        deck.practiceSettings = nil
        XCTAssertEqual(deck.resolvedPracticeSettings(bookmarkFallback: .all), .default)
    }

    func testTheBookmarkFallbackAlwaysComesFromSettings() {
        var own = PracticeSettings()
        own.mode = .bookmarked
        own.bookmarkFallbackMode = .all

        let deck = Deck(name: "Food")
        deck.practiceSettings = own

        let resolved = deck.resolvedPracticeSettings(bookmarkFallback: .leastPracticed)
        XCTAssertEqual(resolved.mode, .bookmarked)
        XCTAssertEqual(resolved.bookmarkFallbackMode, .leastPracticed)

        // A deck with no options of its own gets it too.
        XCTAssertEqual(
            Deck(name: "Verbs").resolvedPracticeSettings(bookmarkFallback: .leastPracticed).bookmarkFallbackMode,
            .leastPracticed
        )
    }

    func testEditingACardKeepsItsBookmark() {
        let card = Card(frontText: "Tea", backText: "Té")
        card.isBookmarked = true

        var draft = CardDraft(card: card)
        XCTAssertTrue(draft.isBookmarked)

        draft.isBookmarked = false
        draft.apply(to: card)
        XCTAssertFalse(card.isBookmarked)
    }
}
