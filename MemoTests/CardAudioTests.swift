//
//  CardAudioTests.swift
//  MemoTests
//

import XCTest
import SwiftData
@testable import Memo

@MainActor
final class CardAudioTests: XCTestCase {

    private func makeContext() -> ModelContext {
        ModelContext(MemoModelContainer.makeInMemoryContainer())
    }

    private func makeCard(in context: ModelContext) -> Card {
        let card = Card(frontText: "食べる", backText: "To Eat")
        context.insert(card)
        return card
    }

    private func recording(_ byte: UInt8, seconds: Double = 2) -> CardDraft.Recording {
        CardDraft.Recording(data: Data([byte, byte, byte]), duration: seconds, fileExtension: "m4a")
    }

    // MARK: - Playback mode

    func testWhenAudioPlaysByItself() {
        XCTAssertTrue(AudioPlaybackMode.automatic.playsAutomatically(headphonesConnected: false))
        XCTAssertFalse(AudioPlaybackMode.manual.playsAutomatically(headphonesConnected: true))
        XCTAssertTrue(AudioPlaybackMode.automaticWithHeadphones.playsAutomatically(headphonesConnected: true))
        XCTAssertFalse(AudioPlaybackMode.automaticWithHeadphones.playsAutomatically(headphonesConnected: false))
    }

    func testAudioPlaysByItselfUnlessToldOtherwise() throws {
        XCTAssertEqual(PracticeSettings.default.audioPlayback, .automatic)

        let older = try JSONDecoder().decode(PracticeSettings.self, from: Data(#"{"mode":"inOrder"}"#.utf8))
        XCTAssertEqual(older.audioPlayback, .automatic)
    }

    // MARK: - Which recording each face plays

    func testFacesPlayTheRecordingOfTheirOwnSide() {
        let card = Card(frontText: "食べる", backText: "To Eat")

        let normal = CardFaces(card: card, inverted: false)
        XCTAssertEqual(normal.promptSlot, .back)
        XCTAssertEqual(normal.promptHintSlot, .backHint)
        XCTAssertEqual(normal.answerSlot, .front)
        XCTAssertEqual(normal.answerHintSlot, .frontHint)

        let inverted = CardFaces(card: card, inverted: true)
        XCTAssertEqual(inverted.promptSlot, .front)
        XCTAssertEqual(inverted.answerHintSlot, .backHint)
    }

    // MARK: - Editing

    func testARecordingIsSavedOnlyWhenTheCardIs() {
        let context = makeContext()
        let card = makeCard(in: context)

        var draft = CardDraft(card: card)
        draft.audio[.front] = recording(1)
        XCTAssertNil(card.audio(for: .front), "a cancelled edit leaves nothing behind")

        draft.apply(to: card)

        XCTAssertEqual(card.audio(for: .front)?.data, Data([1, 1, 1]))
        XCTAssertEqual(card.audio(for: .front)?.duration, 2)
        XCTAssertNil(card.audio(for: .back))
    }

    func testRecordingAgainReplacesAndRemovingDeletes() {
        let context = makeContext()
        let card = makeCard(in: context)

        var draft = CardDraft(card: card)
        draft.audio[.front] = recording(1)
        draft.audio[.backHint] = recording(2)
        draft.apply(to: card)

        var second = CardDraft(card: card)
        XCTAssertEqual(second.audio[.backHint]?.data, Data([2, 2, 2]), "the editor opens with what is saved")

        second.audio[.front] = recording(3)
        second.audio[.backHint] = nil
        second.apply(to: card)

        XCTAssertEqual(card.audio(for: .front)?.data, Data([3, 3, 3]))
        XCTAssertNil(card.audio(for: .backHint))
    }

    func testChangingAudioCountsAsAnEdit() {
        let context = makeContext()
        let card = makeCard(in: context)
        let before = Date.distantPast
        card.modifiedAt = before

        var draft = CardDraft(card: card)
        draft.apply(to: card)
        XCTAssertEqual(card.modifiedAt, before, "nothing changed, so no edit")

        draft.audio[.front] = recording(1)
        draft.apply(to: card)
        XCTAssertGreaterThan(card.modifiedAt, before)
    }

    // MARK: - Recording

    func testClipsAreShortAndSmall() {
        XCTAssertEqual(VoiceRecorder.limit, 30)
        XCTAssertEqual(VoiceRecorder.normalized(-160), 0)
        XCTAssertEqual(VoiceRecorder.normalized(0), 1)
        XCTAssertEqual(VoiceRecorder.normalized(-25), 0.5, accuracy: 0.001)
    }
}
