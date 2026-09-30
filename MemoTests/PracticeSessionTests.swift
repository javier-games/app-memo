//
//  PracticeSessionTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class PracticeSessionTests: XCTestCase {

    private func makeCards(_ count: Int) -> [Card] {
        (0..<count).map { Card(frontText: "F\($0)", backText: "B\($0)") }
    }

    private func front(_ session: PracticeSession) -> String {
        session.currentCard?.frontText ?? "nil"
    }

    // MARK: - Tally

    func testEachOutcomeLandsInItsOwnBucket() {
        // The original bug: correct, incorrect and skip ran identical code.
        // Skipping first, while more than one card is still unanswered, since
        // skipping the last outstanding card is deliberately refused.
        var session = PracticeSession(cards: makeCards(4))
        session.record(.skipped)
        session.record(.correct)
        session.record(.incorrect)

        XCTAssertEqual(session.correctCount, 1)
        XCTAssertEqual(session.incorrectCount, 1)
        XCTAssertEqual(session.skippedCount, 1)
    }

    func testEveryCardIsAnsweredByTheEnd() {
        var session = PracticeSession(cards: makeCards(5))
        session.record(.skipped)
        session.record(.skipped)
        while !session.isFinished { session.record(.correct) }

        XCTAssertEqual(session.correctCount + session.incorrectCount, session.totalCount)
        XCTAssertEqual(session.progress, 1)
        XCTAssertEqual(session.skippedCount, 2, "skips are counted apart from answers")
    }

    func testRecordingPastTheEndIsIgnored() {
        var session = PracticeSession(cards: makeCards(1))
        session.record(.correct)
        let before = (session.correctCount, session.currentIndex)

        session.record(.correct)

        XCTAssertEqual(session.correctCount, before.0)
        XCTAssertEqual(session.currentIndex, before.1)
    }

    // MARK: - Progress

    func testProgressAdvancesOneCardAtATime() {
        var session = PracticeSession(cards: makeCards(4))
        var readings = [session.progress]
        for _ in 0..<4 {
            session.record(.correct)
            readings.append(session.progress)
        }

        XCTAssertEqual(readings, [0, 0.25, 0.5, 0.75, 1.0])
    }

    func testSkippingDoesNotAdvanceProgress() {
        var session = PracticeSession(cards: makeCards(4))
        session.record(.skipped)

        XCTAssertEqual(session.progress, 0, "a skipped card is deferred, not dealt with")
        XCTAssertEqual(session.resolvedCount, 0)
    }

    // MARK: - Skipping

    func testSkippedCardReturnsAtTheBackOfTheDeck() {
        var session = PracticeSession(cards: makeCards(3))   // F0, F1, F2
        XCTAssertEqual(front(session), "F0")

        session.record(.skipped)
        XCTAssertEqual(front(session), "F1")

        session.record(.correct)
        XCTAssertEqual(front(session), "F2")

        session.record(.correct)
        XCTAssertEqual(front(session), "F0", "the skipped card comes back last")
    }

    func testASessionCannotEndOnSkips() {
        var session = PracticeSession(cards: makeCards(3))
        for _ in 0..<20 { session.record(.skipped) }

        XCTAssertFalse(session.isFinished)
        XCTAssertNotNil(session.currentCard)
        XCTAssertEqual(session.progress, 0)
    }

    func testSkipIsUnavailableWithOneCardLeftToAnswer() {
        var session = PracticeSession(cards: makeCards(2))
        XCTAssertTrue(session.canSkip)

        session.record(.correct)
        XCTAssertFalse(session.canSkip, "sending the last card back would just redeal it")

        let before = (session.currentIndex, session.skippedCount, front(session))
        session.record(.skipped)
        XCTAssertEqual(session.currentIndex, before.0)
        XCTAssertEqual(session.skippedCount, before.1)
        XCTAssertEqual(front(session), before.2)
    }

    func testDeckMembershipSurvivesSkipping() {
        var session = PracticeSession(cards: makeCards(4))
        session.record(.skipped)
        session.record(.skipped)
        session.record(.correct)

        XCTAssertEqual(session.totalCount, 4)
        XCTAssertEqual(Set(session.cards.map(\.frontText)), ["F0", "F1", "F2", "F3"])
    }

    // MARK: - Lifecycle

    func testRestartClearsEveryCounter() {
        var session = PracticeSession(cards: makeCards(3))
        session.record(.skipped)
        session.record(.correct)

        session.restart(with: makeCards(3))

        XCTAssertEqual(session.correctCount, 0)
        XCTAssertEqual(session.incorrectCount, 0)
        XCTAssertEqual(session.skippedCount, 0)
        XCTAssertEqual(session.currentIndex, 0)
        XCTAssertFalse(session.isFinished)
    }

    func testEmptySessionIsFinishedRatherThanBlank() {
        // This is what used to leave a blank screen with no way forward.
        let session = PracticeSession(cards: [])

        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.progress, 1)
        XCTAssertFalse(session.progress.isNaN)
        XCTAssertFalse(session.canSkip)
    }
}
