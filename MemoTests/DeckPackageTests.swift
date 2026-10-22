//
//  DeckPackageTests.swift
//  MemoTests
//

import XCTest
import SwiftData
@testable import Memo

@MainActor
final class DeckPackageTests: XCTestCase {

    private let sound = Data("not really audio, but bytes are bytes".utf8)

    private func makeContext() -> ModelContext {
        ModelContext(MemoModelContainer.makeInMemoryContainer())
    }

    /// A deck of one card, with a recording on its front if `withAudio`.
    private func makeDeck(in context: ModelContext, withAudio: Bool = true) -> Deck {
        let deck = Deck(name: "Verbs", icon: "🎌", sortIndex: 0)
        context.insert(deck)

        let card = Card(frontText: "食べる", backText: "To Eat")
        context.insert(card)
        card.deck = deck

        if withAudio {
            let audio = CardAudio(slot: .front, data: sound, duration: 1.5)
            context.insert(audio)
            audio.card = card
        }

        return deck
    }

    /// Exports `decks` as a package and reads it straight back.
    private func roundTrip(_ decks: [Deck]) throws -> DeckImporter.Preview {
        let zip = try DeckPackage.write(DeckPackage.contents(for: decks), named: "Verbs")
        defer { try? FileManager.default.removeItem(at: zip.deletingLastPathComponent()) }

        return try DeckPackage.preview(fromZip: Data(contentsOf: zip))
    }

    func testAPackageCarriesTheRecordings() throws {
        let preview = try roundTrip([makeDeck(in: makeContext())])

        let card = try XCTUnwrap(preview.decks.first?.cardList.first)
        let reference = try XCTUnwrap(card.frontAudio)
        XCTAssertEqual(preview.audio[reference], sound)
        XCTAssertNil(card.backAudio)
        XCTAssertEqual(preview.skippedAudioCount, 0)
    }

    func testImportingAPackageGivesNewCardsTheirRecordings() throws {
        let preview = try roundTrip([makeDeck(in: makeContext())])

        let library = makeContext()
        let plan = DeckImporter.plan(preview, against: [])
        XCTAssertEqual(plan.newAudioCount, 1)

        DeckImporter.apply(plan, overwritingConflicts: false, into: library, after: 0)

        let card = try XCTUnwrap(try library.fetch(FetchDescriptor<Card>()).first)
        XCTAssertEqual(card.audio(for: .front)?.data, sound)
        XCTAssertEqual(card.audio(for: .front)?.fileExtension, "m4a")
    }

    func testImportingAgainAddsMissingRecordingsAndKeepsExistingOnes() throws {
        let context = makeContext()
        let deck = makeDeck(in: context)
        let preview = try roundTrip([deck])

        // Already has the recording: nothing to add.
        XCTAssertEqual(DeckImporter.plan(preview, against: [deck]).newAudioCount, 0)

        // A card here without it gets it, and a recording made here stays.
        let card = try XCTUnwrap(deck.orderedCards.first)
        for audio in card.audios ?? [] { context.delete(audio) }
        card.audios = []
        let mine = CardAudio(slot: .back, data: Data([9]), duration: 1)
        context.insert(mine)
        mine.card = card

        let plan = DeckImporter.plan(preview, against: [deck])
        XCTAssertEqual(plan.newAudioCount, 1)

        DeckImporter.apply(plan, overwritingConflicts: false, into: context, after: 1)
        XCTAssertEqual(card.audio(for: .front)?.data, sound)
        XCTAssertEqual(card.audio(for: .back)?.data, Data([9]))
    }

    func testAReferenceThatLeavesThePackageIsIgnored() throws {
        var contents = DeckPackage.contents(for: [makeDeck(in: makeContext(), withAudio: false)])
        contents.file.deckList[0].cardList[0].frontAudio = "../../outside.m4a"

        let zip = try DeckPackage.write(contents, named: "Verbs")
        defer { try? FileManager.default.removeItem(at: zip.deletingLastPathComponent()) }
        let preview = try DeckPackage.preview(fromZip: Data(contentsOf: zip))

        XCTAssertNil(preview.decks.first?.cardList.first?.frontAudio)
        XCTAssertEqual(preview.skippedAudioCount, 1)
        XCTAssertTrue(preview.audio.isEmpty)
    }

    func testPlainJSONLeavesRecordingsOut() throws {
        let context = makeContext()
        let deck = makeDeck(in: context)

        let json = String(decoding: try DeckExporter.jsonData(for: deck), as: UTF8.self)
        XCTAssertFalse(json.contains("frontAudio"), "plain JSON has nowhere to keep the sound")

        let handWritten = Data(#"{"deckList":[{"name":"V","cardList":[{"frontText":"a","backText":"b","frontAudio":"audio/x.m4a"}]}]}"#.utf8)
        let preview = try DeckImporter.preview(data: handWritten, kind: .json, fallbackDeckName: "V")
        XCTAssertNil(preview.decks.first?.cardList.first?.frontAudio)
    }

    func testAZipWithNoDecksIsRefused() throws {
        let contents = DeckPackage.Contents(file: DeckTransferFile(deckList: []), recordings: [])
        let zip = try DeckPackage.write(contents, named: "Empty")
        defer { try? FileManager.default.removeItem(at: zip.deletingLastPathComponent()) }

        XCTAssertThrowsError(try DeckPackage.preview(fromZip: Data(contentsOf: zip)))
    }
}
