//
//  DeckTransferTests.swift
//  MemoTests
//

import XCTest
import SwiftData
import SwiftUI
@testable import Memo

final class DeckTransferTests: XCTestCase {

    // The exact shape the README documents.
    private static let documentedJSON = """
    {
      "deckList": [
        {
          "name": "Food",
          "icon": "🥩",
          "color": "253,251,102,255",
          "cardList": [
            {"frontText":"Tea","frontHintText":"a hot drink","backText":"Té","backHintText":""},
            {"frontText":"Sushi","frontHintText":"","backText":"お寿司","backHintText":"🍣"}
          ]
        }
      ]
    }
    """

    @MainActor
    private func makeContext() -> ModelContext {
        ModelContext(MemoModelContainer.makeInMemoryContainer())
    }

    // MARK: - Colour

    func testColourRoundTrip() {
        let encoded = DeckTransferColor.string(red: 1, green: 0.5, blue: 0, alpha: 1)
        XCTAssertEqual(encoded, "255,128,0,255")

        let decoded = DeckTransferColor.components(from: encoded)
        XCTAssertEqual(decoded.red, 1, accuracy: 0.01)
        XCTAssertEqual(decoded.green, 0.5, accuracy: 0.01)
        XCTAssertEqual(decoded.blue, 0, accuracy: 0.01)
    }

    func testMalformedColourFallsBack() {
        XCTAssertEqual(DeckTransferColor.components(from: "not a colour").alpha, 1)
        XCTAssertEqual(DeckTransferColor.components(from: "1,2").red, 0)
    }

    func testColourIsClamped() {
        XCTAssertEqual(DeckTransferColor.components(from: "999,-4,0,255").red, 1)
        XCTAssertEqual(DeckTransferColor.components(from: "999,-4,0,255").green, 0)
    }

    // MARK: - JSON

    func testDecodesTheDocumentedFormat() throws {
        let preview = try DeckImporter.preview(
            data: Data(Self.documentedJSON.utf8),
            kind: .json,
            fallbackDeckName: "ignored"
        )

        XCTAssertEqual(preview.deckCount, 1)
        XCTAssertEqual(preview.cardCount, 2)
        XCTAssertEqual(preview.decks.first?.name, "Food")
        XCTAssertEqual(preview.decks.first?.icon, "🥩")
        XCTAssertEqual(preview.decks.first?.cardList.last?.backHintText, "🍣")
    }

    func testJSONToleratesMissingOptionalFields() throws {
        let minimal = Data(#"{"deckList":[{"name":"X","cardList":[{"frontText":"a","backText":"b"}]}]}"#.utf8)

        let preview = try DeckImporter.preview(data: minimal, kind: .json, fallbackDeckName: "f")

        XCTAssertEqual(preview.cardCount, 1)
        XCTAssertEqual(preview.decks.first?.cardList.first?.frontHintText, "")
    }

    func testMalformedJSONIsReportedNotSwallowed() {
        XCTAssertThrowsError(
            try DeckImporter.preview(data: Data("{ nope".utf8), kind: .json, fallbackDeckName: "f")
        ) { error in
            XCTAssertNotNil((error as? DeckImporter.Failure)?.errorDescription)
        }
    }

    func testAFileWithNoUsableCardsIsRejected() {
        let empty = Data(#"{"deckList":[{"name":"X","cardList":[]}]}"#.utf8)

        XCTAssertThrowsError(
            try DeckImporter.preview(data: empty, kind: .json, fallbackDeckName: "f")
        )
    }

    func testIncompleteCardsAreSkippedAndCounted() throws {
        let mixed = Data("""
        {"deckList":[{"name":"X","cardList":[
          {"frontText":"a","backText":"b"},
          {"frontText":"","backText":"b"},
          {"frontText":"c","backText":"   "}
        ]}]}
        """.utf8)

        let preview = try DeckImporter.preview(data: mixed, kind: .json, fallbackDeckName: "f")

        XCTAssertEqual(preview.cardCount, 1)
        XCTAssertEqual(preview.skippedCardCount, 2)
    }

    // MARK: - CSV

    func testCSVRoundTrip() {
        let cards = [
            DeckTransferCard(frontText: "Tea", frontHintText: "hot", backText: "Té", backHintText: ""),
            DeckTransferCard(frontText: "Bread", frontHintText: "", backText: "Pan", backHintText: "b"),
        ]

        let parsed = DeckCSVFormat.parse(DeckCSVFormat.serialize(cards))

        XCTAssertEqual(parsed.map(\.frontText), ["Tea", "Bread"])
        XCTAssertEqual(parsed.map(\.backText), ["Té", "Pan"])
        XCTAssertEqual(parsed.map(\.frontHintText), ["hot", ""])
        XCTAssertEqual(parsed.map(\.backHintText), ["", "b"])
    }

    func testCSVQuotesFieldsThatNeedIt() {
        let cards = [
            DeckTransferCard(frontText: "a,b", frontHintText: "say \"hi\"", backText: "line\nbreak", backHintText: "")
        ]

        let text = DeckCSVFormat.serialize(cards)
        let parsed = DeckCSVFormat.parse(text)

        XCTAssertEqual(parsed.first?.frontText, "a,b", "a comma must not split the field")
        XCTAssertEqual(parsed.first?.frontHintText, "say \"hi\"", "quotes survive doubling")
        XCTAssertEqual(parsed.first?.backText, "line\nbreak", "a newline inside quotes is not a new row")
    }

    func testCSVHeaderIsOptional() {
        let withHeader = "front,frontHint,back,backHint\r\nTea,,Té,\r\n"
        let without = "Tea,,Té,\r\n"

        XCTAssertEqual(DeckCSVFormat.parse(withHeader).map(\.frontText), ["Tea"])
        XCTAssertEqual(DeckCSVFormat.parse(without).map(\.frontText), ["Tea"])
    }

    func testCSVShortRowsArePadded() {
        let parsed = DeckCSVFormat.parse("Tea,,Té\nBread,,Pan\n")

        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed.first?.backHintText, "")
    }

    func testATwoColumnCSVIsFrontAndBack() {
        // A hand-written two-column file should still import.
        let parsed = DeckCSVFormat.parse("Tea,Té\nBread,Pan\n")

        XCTAssertEqual(parsed.map(\.frontText), ["Tea", "Bread"])
        XCTAssertEqual(parsed.map(\.backText), ["Té", "Pan"])
        XCTAssertTrue(parsed.allSatisfy(\.isComplete))
    }

    func testCSVToleratesAByteOrderMark() throws {
        // Spreadsheets write one as a matter of course; unhandled it rides
        // along on the first field and breaks both the first card and header
        // detection.
        let data = Data("\u{FEFF}".utf8)
            + Data("front,frontHint,back,backHint\r\nTea,,Té,\r\n".utf8)

        let preview = try DeckImporter.preview(data: data, kind: .csv, fallbackDeckName: "x")

        XCTAssertEqual(preview.cardCount, 1)
        XCTAssertEqual(preview.decks.first?.cardList.first?.frontText, "Tea")
        XCTAssertEqual(preview.decks.first?.cardList.first?.backText, "Té")
    }

    func testCSVKeepsDeliberateLineBreaksInsideFields() {
        // Material that puts kanji and kana on separate lines depends on this.
        let text = "front,frontHint,back,backHint\r\n\"I\nyo\",,\"私\nわたし\",\r\n"

        let parsed = DeckCSVFormat.parse(text)

        XCTAssertEqual(parsed.first?.backText, "私\nわたし")
        XCTAssertEqual(parsed.first?.frontText, "I\nyo")
    }

    func testCSVIgnoresBlankRows() {
        XCTAssertEqual(DeckCSVFormat.parse("Tea,,Té,\n\n\nBread,,Pan,\n").count, 2)
    }

    func testCSVImportNamesTheDeckAfterTheFile() throws {
        let preview = try DeckImporter.preview(
            data: Data("Tea,,Té,\n".utf8),
            kind: .csv,
            fallbackDeckName: "Spanish Food"
        )

        XCTAssertEqual(preview.decks.first?.name, "Spanish Food")
    }

    // MARK: - Inserting

    @MainActor
    func testImportAppendsAfterExistingDecks() throws {
        let context = makeContext()
        context.insert(Deck(name: "Existing", sortIndex: 0))

        let preview = try DeckImporter.preview(
            data: Data(Self.documentedJSON.utf8), kind: .json, fallbackDeckName: "f"
        )
        let imported = DeckImporter.insert(preview, into: context, after: 1)

        XCTAssertEqual(imported.first?.sortIndex, 1, "imported decks go after what is already there")

        let all = try context.fetch(FetchDescriptor<Deck>())
        XCTAssertEqual(all.count, 2, "import adds, it never replaces")
    }

    @MainActor
    func testImportedCardsKeepTheirOrderAndColour() throws {
        let context = makeContext()
        let preview = try DeckImporter.preview(
            data: Data(Self.documentedJSON.utf8), kind: .json, fallbackDeckName: "f"
        )

        let deck = try XCTUnwrap(DeckImporter.insert(preview, into: context, after: 0).first)

        XCTAssertEqual(deck.orderedCards.map(\.frontText), ["Tea", "Sushi"])
        XCTAssertEqual(deck.colorRed, 253.0 / 255, accuracy: 0.01)
        XCTAssertEqual(deck.colorGreen, 251.0 / 255, accuracy: 0.01)
    }

    @MainActor
    func testADeckWithNoNameStillGetsOne() throws {
        let context = makeContext()
        let preview = try DeckImporter.preview(
            data: Data(#"{"deckList":[{"cardList":[{"frontText":"a","backText":"b"}]}]}"#.utf8),
            kind: .json,
            fallbackDeckName: "f"
        )

        let deck = try XCTUnwrap(DeckImporter.insert(preview, into: context, after: 0).first)

        XCTAssertFalse(deck.name.isEmpty)
        XCTAssertFalse(deck.icon.isEmpty)
    }

    // MARK: - Export

    @MainActor
    func testExportedJSONReimportsIdentically() throws {
        let context = makeContext()
        let original = Deck(name: "Spanish Food", icon: "🥩", sortIndex: 0)
        original.colorRed = 1; original.colorGreen = 0.5; original.colorBlue = 0
        context.insert(original)
        for (index, pair) in [("Tea", "Té"), ("Bread", "Pan")].enumerated() {
            let card = Card(frontText: pair.0, backText: pair.1, frontHintText: "h,1", sortIndex: index)
            context.insert(card)
            card.deck = original
        }

        let data = try DeckExporter.jsonData(for: original)
        let preview = try DeckImporter.preview(data: data, kind: .json, fallbackDeckName: "f")
        let reimported = try XCTUnwrap(DeckImporter.insert(preview, into: context, after: 1).first)

        XCTAssertEqual(reimported.name, "Spanish Food")
        XCTAssertEqual(reimported.icon, "🥩")
        XCTAssertEqual(reimported.orderedCards.map(\.frontText), ["Tea", "Bread"])
        XCTAssertEqual(reimported.orderedCards.first?.frontHintText, "h,1")
        XCTAssertEqual(reimported.colorRed, 1, accuracy: 0.01)
        XCTAssertEqual(reimported.colorGreen, 0.5, accuracy: 0.01)
    }

    @MainActor
    func testExportedCSVReimportsIdentically() throws {
        let context = makeContext()
        let original = Deck(name: "Tricky", sortIndex: 0)
        context.insert(original)
        let card = Card(frontText: "a,b", backText: "say \"hi\"", frontHintText: "x", sortIndex: 0)
        context.insert(card)
        card.deck = original

        let text = DeckExporter.csvText(for: original)
        let preview = try DeckImporter.preview(
            data: Data(text.utf8), kind: .csv, fallbackDeckName: "Tricky"
        )
        let reimported = try XCTUnwrap(DeckImporter.insert(preview, into: context, after: 1).first)

        XCTAssertEqual(reimported.orderedCards.first?.frontText, "a,b")
        XCTAssertEqual(reimported.orderedCards.first?.backText, "say \"hi\"")
    }

    @MainActor
    func testFileNameIsSafeForTheFileSystem() {
        let deck = Deck(name: "Spanish / Food: 1?")

        let name = DeckExporter.fileName(for: deck, kind: .json)

        XCTAssertTrue(name.hasSuffix(".json"))
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertFalse(name.contains("?"))
    }

    @MainActor
    func testAnUnnamedDeckStillProducesAFileName() {
        XCTAssertFalse(DeckExporter.fileName(for: Deck(name: "   "), kind: .csv).isEmpty)
        XCTAssertTrue(DeckExporter.fileName(for: Deck(name: "   "), kind: .csv).hasSuffix(".csv"))
    }
}

// MARK: - Deck editing

final class DeckDraftTests: XCTestCase {

    func testDraftCarriesTheDecksDetails() {
        let deck = Deck(name: "Spanish Food", icon: "🥩")
        deck.setColor(.red)

        let draft = DeckDraft(deck: deck)

        XCTAssertEqual(draft.name, "Spanish Food")
        XCTAssertEqual(draft.icon, "🥩")
    }

    func testRenamingAndRecolouringWritesBack() {
        let deck = Deck(name: "Old", icon: "📝")
        var draft = DeckDraft(deck: deck)

        draft.name = "  New Name  "
        draft.icon = "🇯🇵"
        draft.color = Color(red: 0, green: 1, blue: 0)
        draft.apply(to: deck)

        XCTAssertEqual(deck.name, "New Name", "surrounding space is trimmed")
        XCTAssertEqual(deck.icon, "🇯🇵")
        XCTAssertEqual(deck.colorGreen, 1, accuracy: 0.01)
        XCTAssertEqual(deck.colorRed, 0, accuracy: 0.01)
    }

    func testANamelessDraftCannotBeSaved() {
        var draft = DeckDraft()

        draft.name = "   "
        XCTAssertFalse(draft.isValid)

        draft.name = "Something"
        XCTAssertTrue(draft.isValid)
    }

    func testTheIconFieldKeepsOnlyTheLastCharacterTyped() {
        XCTAssertEqual(EmojiTextField.icon(afterTyping: "🥩"), "🥩")
        XCTAssertEqual(EmojiTextField.icon(afterTyping: "🥩😀"), "😀")
        // One emoji, however many code points it is built from.
        XCTAssertEqual(EmojiTextField.icon(afterTyping: "👩🏽‍🍳"), "👩🏽‍🍳")
        XCTAssertEqual(EmojiTextField.icon(afterTyping: ""), "", "deleting clears it")
    }

    func testANewDraftSuggestsAnIcon() {
        XCTAssertFalse(DeckDraft().icon.isEmpty, "a new deck should never be iconless")
    }

    func testEditingDoesNotDisturbTheDecksCards() {
        let deck = Deck(name: "Old")
        let card = Card(frontText: "a", backText: "b")
        deck.append(card)

        var draft = DeckDraft(deck: deck)
        draft.name = "New"
        draft.apply(to: deck)

        XCTAssertEqual(deck.cardCount, 1)
        XCTAssertEqual(deck.orderedCards.first?.frontText, "a")
    }
}
