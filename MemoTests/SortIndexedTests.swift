//
//  SortIndexedTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class SortIndexedTests: XCTestCase {

    /// Cards named A, B, C… already numbered 0, 1, 2…
    private func makeCards(_ count: Int) -> [Card] {
        (0..<count).map { index in
            Card(frontText: String(UnicodeScalar(65 + index)!), backText: "b", sortIndex: index)
        }
    }

    /// The list as the UI re-reads it: sorted by the stored index.
    private func order(_ cards: [Card]) -> String {
        cards.sorted { $0.sortIndex < $1.sortIndex }.map(\.frontText).joined()
    }

    private func indices(_ cards: [Card]) -> [Int] {
        cards.map(\.sortIndex).sorted()
    }

    func testMovingARowDown() {
        let cards = makeCards(5)
        cards.applyMove(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(order(cards), "BCADE")
        XCTAssertEqual(indices(cards), [0, 1, 2, 3, 4])
    }

    func testMovingARowUp() {
        let cards = makeCards(5)
        cards.applyMove(from: IndexSet(integer: 4), to: 1)

        XCTAssertEqual(order(cards), "AEBCD")
        XCTAssertEqual(indices(cards), [0, 1, 2, 3, 4])
    }

    func testMovingToEitherEnd() {
        let toTop = makeCards(4)
        toTop.applyMove(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(order(toTop), "CABD")

        let toBottom = makeCards(4)
        toBottom.applyMove(from: IndexSet(integer: 0), to: 4)
        XCTAssertEqual(order(toBottom), "BCDA")
    }

    func testMovingSeveralRowsKeepsTheirRelativeOrder() {
        let cards = makeCards(6)
        cards.applyMove(from: IndexSet([0, 1]), to: 4)

        XCTAssertEqual(order(cards), "CDABEF")
        XCTAssertEqual(indices(cards), [0, 1, 2, 3, 4, 5])
    }

    func testNothingIsLostOrDuplicated() {
        let cards = makeCards(6)
        cards.applyMove(from: IndexSet([1, 4]), to: 0)

        XCTAssertEqual(Set(cards.map(\.frontText)).count, 6)
        XCTAssertEqual(Set(cards.map(\.sortIndex)).count, 6, "no two rows share a position")
    }

    func testANoOpMoveStillRenumbersCleanly() {
        let cards = makeCards(3)
        cards.applyMove(from: IndexSet(integer: 1), to: 1)

        XCTAssertEqual(order(cards), "ABC")
        XCTAssertEqual(indices(cards), [0, 1, 2])
    }

    func testRepairsAnOrderingWithGapsAndDuplicates() {
        let cards = makeCards(3)
        cards[0].sortIndex = 7
        cards[1].sortIndex = 7
        cards[2].sortIndex = 99

        cards.applyMove(from: IndexSet(integer: 0), to: 0)

        XCTAssertEqual(indices(cards), [0, 1, 2])
    }

    func testDecksReorderTheSameWay() {
        let decks = (0..<3).map { index in
            Deck(name: String(UnicodeScalar(65 + index)!), sortIndex: index)
        }

        decks.applyMove(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(
            decks.sorted { $0.sortIndex < $1.sortIndex }.map(\.name).joined(),
            "CAB"
        )
    }

    func testASingleRowIsSafe() {
        let cards = makeCards(1)
        cards.applyMove(from: IndexSet(integer: 0), to: 0)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].sortIndex, 0)
    }

    // MARK: - Moving one place at a time

    func testMoveDownByOne() {
        let cards = makeCards(4)                     // A B C D
        cards.applyMove(at: 0, by: 1)

        XCTAssertEqual(order(cards), "BACD")
    }

    func testMoveUpByOne() {
        let cards = makeCards(4)
        cards.applyMove(at: 2, by: -1)

        XCTAssertEqual(order(cards), "ACBD")
    }

    func testMovingDownRepeatedlyWalksToTheEnd() {
        let cards = makeCards(4)

        // Mirrors the view, which re-reads the sorted order between moves.
        // `applyMove` renumbers sortIndex; it does not reorder the array it is
        // called on, so moving by array index twice in a row would otherwise
        // move two different elements.
        func sorted() -> [Card] { cards.sorted { $0.sortIndex < $1.sortIndex } }

        sorted().applyMove(at: 0, by: 1)
        sorted().applyMove(at: 1, by: 1)
        sorted().applyMove(at: 2, by: 1)

        XCTAssertEqual(order(cards), "BCDA")
    }

    func testMovingPastEitherEndDoesNothing() {
        let top = makeCards(3)
        top.applyMove(at: 0, by: -1)
        XCTAssertEqual(order(top), "ABC", "the first row cannot move up")

        let bottom = makeCards(3)
        bottom.applyMove(at: 2, by: 1)
        XCTAssertEqual(order(bottom), "ABC", "the last row cannot move down")
    }

    func testMovingAnIndexThatDoesNotExistDoesNothing() {
        let cards = makeCards(3)
        cards.applyMove(at: 9, by: 1)

        XCTAssertEqual(order(cards), "ABC")
        XCTAssertEqual(indices(cards), [0, 1, 2])
    }

    func testReorderingChangesWhatInOrderPracticeDeals() {
        // Card order is user-visible in practice, not only in the list.
        let cards = makeCards(4)
        cards.applyMove(from: IndexSet(integer: 3), to: 0)

        var settings = PracticeSettings()
        settings.mode = .inOrder
        let sorted = cards.sorted { $0.sortIndex < $1.sortIndex }

        XCTAssertEqual(
            PracticePlanner.plan(from: sorted, settings: settings).map(\.frontText),
            ["D", "A", "B", "C"]
        )
    }
}
