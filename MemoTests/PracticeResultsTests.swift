//
//  PracticeResultsTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class PracticeResultsTests: XCTestCase {

    private func makeCards(_ count: Int) -> [Card] {
        (0..<count).map { Card(frontText: "F\($0)", backText: "B\($0)") }
    }

    /// Three cards: the first skipped twice, then everything answered.
    private func makeFinishedSession() -> PracticeSession {
        var session = PracticeSession(cards: makeCards(3))
        session.record(.skipped)    // F0 to the back
        session.record(.correct)    // F1
        session.record(.incorrect)  // F2
        session.record(.skipped)    // F0 is the only one left, so this does nothing
        session.record(.correct)    // F0
        return session
    }

    // MARK: - What happened to each card

    func testTheSessionRemembersWhichCardEachAnswerWas() {
        let session = makeFinishedSession()

        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.reviewedCards(.correct).map(\.card.frontText), ["F1", "F0"])
        XCTAssertEqual(session.reviewedCards(.incorrect).map(\.card.frontText), ["F2"])
        XCTAssertEqual(session.reviewedCards(.skipped).map(\.card.frontText), ["F0"])
    }

    func testASkipThatDoesNothingIsNotRemembered() {
        let session = makeFinishedSession()

        XCTAssertEqual(session.skippedCount, 1)
        XCTAssertEqual(session.outcomes, [.skipped, .correct, .incorrect, .correct])
    }

    func testACardSkippedTwiceIsListedOnce() {
        var session = PracticeSession(cards: makeCards(2))
        session.record(.skipped)    // F0 to the back
        session.record(.skipped)    // F1 to the back
        session.record(.skipped)    // F0 again

        let skipped = session.reviewedCards(.skipped)

        XCTAssertEqual(skipped.map(\.card.frontText), ["F0", "F1"])
        XCTAssertEqual(skipped.map(\.times), [2, 1])
    }

    func testStartingAgainForgetsTheLastRun() {
        var session = makeFinishedSession()

        session.restart(with: makeCards(2))

        XCTAssertTrue(session.outcomes.isEmpty)
        XCTAssertTrue(session.reviewedCards(.correct).isEmpty)
    }

    // MARK: - Counting up

    func testPlayingTheSessionBackArrivesAtItsTallies() {
        let session = makeFinishedSession()

        let tally = PracticeResultsTally.total(of: session.outcomes)

        XCTAssertEqual(tally.practiced, session.totalCount)
        XCTAssertEqual(tally.correct, session.correctCount)
        XCTAssertEqual(tally.incorrect, session.incorrectCount)
        XCTAssertEqual(tally.skipped, session.skippedCount)
    }

    func testCountsClimbInTheOrderTheAnswersWereGiven() {
        var tally = PracticeResultsTally()

        tally.count(.skipped)
        XCTAssertEqual(tally, PracticeResultsTally(practiced: 0, correct: 0, incorrect: 0, skipped: 1))

        tally.count(.correct)
        XCTAssertEqual(tally, PracticeResultsTally(practiced: 1, correct: 1, incorrect: 0, skipped: 1))

        tally.count(.incorrect)
        XCTAssertEqual(tally, PracticeResultsTally(practiced: 2, correct: 1, incorrect: 1, skipped: 1))
    }

    func testTheCountingTakesAboutAsLongHoweverLongTheSession() {
        typealias Timing = PracticeResultsReveal.Timing

        XCTAssertEqual(Timing.step(for: 1), 0.16, "a short session does not crawl")
        XCTAssertEqual(Timing.step(for: 1_000), 0.03, "a long one is still seen to count")
        XCTAssertEqual(Timing.step(for: 20) * 20, Timing.counting, accuracy: 0.001)
    }

    // MARK: - The reveal

    @MainActor
    func testSkippingTheAnimationShowsEverythingAtOnce() {
        let session = makeFinishedSession()
        let reveal = PracticeResultsReveal(log: session.outcomes)
        XCTAssertFalse(reveal.isFinished)
        XCTAssertEqual(reveal.tally, PracticeResultsTally())

        reveal.finish()

        XCTAssertTrue(reveal.isFinished)
        XCTAssertTrue(reveal.showsIcon)
        XCTAssertEqual(reveal.tally, .total(of: session.outcomes))
    }

    @MainActor
    func testASessionWithNothingInItHasNothingToAnimate() {
        let reveal = PracticeResultsReveal(log: [])

        reveal.start()

        XCTAssertTrue(reveal.isFinished)
    }
}
