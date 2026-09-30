//
//  CardPracticeProgressTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class CardPracticeProgressTests: XCTestCase {

    private func makeCard(progress: Int = 0) -> Card {
        Card(frontText: "F", backText: "B", practiceProgress: progress)
    }

    // MARK: - Standing

    func testStandingAgainstATarget() {
        let standing = CardPracticeProgress(completed: 3, target: 10)

        XCTAssertTrue(standing.isTracked)
        XCTAssertFalse(standing.isFulfilled)
        XCTAssertEqual(standing.fraction, 0.3, accuracy: 0.0001)
        XCTAssertEqual(standing.shortDescription, "3/10")
    }

    func testFulfilledWhenTargetIsReached() {
        XCTAssertTrue(CardPracticeProgress(completed: 10, target: 10).isFulfilled)
        XCTAssertTrue(CardPracticeProgress(completed: 12, target: 10).isFulfilled)
    }

    func testATargetOfZeroTurnsTrackingOff() {
        let standing = CardPracticeProgress(completed: 4, target: 0)

        XCTAssertFalse(standing.isTracked)
        XCTAssertFalse(standing.isFulfilled, "an untracked card is never 'learned'")
        XCTAssertEqual(standing.fraction, 0, "no division by zero")
        XCTAssertNil(standing.shortDescription, "nothing to show when untracked")
    }

    func testDescriptionDoesNotOvershootTheTarget() {
        // Possible after the target is lowered below existing progress.
        XCTAssertEqual(CardPracticeProgress(completed: 12, target: 10).shortDescription, "10/10")
        XCTAssertEqual(CardPracticeProgress(completed: 12, target: 10).fraction, 1)
    }

    // MARK: - Recording

    func testCorrectAdvancesByOne() {
        let card = makeCard(progress: 3)

        CardPracticeProgressRecorder.record(.correct, on: card, target: 10)

        XCTAssertEqual(card.practiceProgress, 4)
    }

    func testProgressStopsAtTheTarget() {
        let card = makeCard(progress: 10)

        CardPracticeProgressRecorder.record(.correct, on: card, target: 10)

        XCTAssertEqual(card.practiceProgress, 10)
    }

    func testWrongResetsToZero() {
        let card = makeCard(progress: 9)

        CardPracticeProgressRecorder.record(.incorrect, on: card, target: 10)

        XCTAssertEqual(card.practiceProgress, 0, "one wrong answer undoes the streak")
    }

    func testSkippingLeavesProgressAlone() {
        let card = makeCard(progress: 4)

        CardPracticeProgressRecorder.record(.skipped, on: card, target: 10)

        XCTAssertEqual(card.practiceProgress, 4, "a deferred card has not been answered")
    }

    func testATargetOfZeroRecordsNothing() {
        let card = makeCard(progress: 5)

        CardPracticeProgressRecorder.record(.correct, on: card, target: 0)
        CardPracticeProgressRecorder.record(.incorrect, on: card, target: 0)

        XCTAssertEqual(
            card.practiceProgress, 5,
            "turning tracking off must not wipe progress the user may want back"
        )
    }

    // MARK: - Resolving the target

    func testTheTargetComesFromTheSetting() {
        var settings = PracticeSettings()
        settings.practiceTarget = 7

        XCTAssertEqual(settings.resolvedPracticeTarget, 7)
        XCTAssertEqual(settings.progress(for: makeCard(progress: 2)).target, 7)
    }

    func testDefaultTargetIsTen() {
        XCTAssertEqual(PracticeSettings.default.practiceTarget, 10)
    }

    func testResolvedTargetIsClampedToTheAllowedRange() {
        var settings = PracticeSettings()

        settings.practiceTarget = 500
        XCTAssertEqual(settings.resolvedPracticeTarget, 100)

        settings.practiceTarget = -5
        XCTAssertEqual(settings.resolvedPracticeTarget, 0)
    }

    func testProgressCombinesCardAndSetting() {
        var settings = PracticeSettings()
        settings.practiceTarget = 4

        let standing = settings.progress(for: makeCard(progress: 2))

        XCTAssertEqual(standing.completed, 2)
        XCTAssertEqual(standing.target, 4)
        XCTAssertEqual(standing.shortDescription, "2/4")
    }

    func testNegativeStoredProgressReadsAsZero() {
        XCTAssertEqual(PracticeSettings().progress(for: makeCard(progress: -3)).completed, 0)
    }

    // MARK: - Editing the value by hand

    func testDraftCarriesTheCardsProgress() {
        XCTAssertEqual(CardDraft(card: makeCard(progress: 6)).practiceProgress, 6)
    }

    func testEditingTheValueWritesItBack() {
        // The point of the field: correcting a card practised elsewhere.
        let card = makeCard(progress: 0)
        var draft = CardDraft(card: card)

        draft.practiceProgress = 7
        draft.apply(to: card)

        XCTAssertEqual(card.practiceProgress, 7)
    }

    func testEditingCannotStoreANegativeValue() {
        let card = makeCard(progress: 3)
        var draft = CardDraft(card: card)

        draft.practiceProgress = -4
        draft.apply(to: card)

        XCTAssertEqual(card.practiceProgress, 0)
    }

    func testANewCardStartsWithNoProgress() {
        XCTAssertEqual(CardDraft().practiceProgress, 0)
    }

    func testEditingOtherFieldsLeavesProgressAlone() {
        let card = makeCard(progress: 5)
        var draft = CardDraft(card: card)

        draft.frontText = "changed"
        draft.apply(to: card)

        XCTAssertEqual(card.practiceProgress, 5)
    }

    // MARK: - Persistence of the new setting

    func testTargetSurvivesARoundTrip() throws {
        var settings = PracticeSettings()
        settings.practiceTarget = 42

        let decoded = try JSONDecoder().decode(
            PracticeSettings.self,
            from: JSONEncoder().encode(settings)
        )

        XCTAssertEqual(decoded.practiceTarget, 42)
    }

    func testAPayloadPredatingTheTargetGetsTheDefault() throws {
        // The exact case the tolerant decoder exists for.
        let legacy = Data(#"{"isInverted":true,"mode":"inOrder"}"#.utf8)

        let decoded = try JSONDecoder().decode(PracticeSettings.self, from: legacy)

        XCTAssertEqual(decoded.practiceTarget, 10)
        XCTAssertTrue(decoded.isInverted)
        XCTAssertEqual(decoded.mode, .inOrder)
    }
}
