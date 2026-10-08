//
//  DeckImportPlanTests.swift
//  MemoTests
//

import XCTest
import SwiftData
@testable import Memo

@MainActor
final class DeckImportPlanTests: XCTestCase {

    private let earlier = Date(timeIntervalSince1970: 1_700_000_000)
    private let later = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeContext() -> ModelContext {
        ModelContext(MemoModelContainer.makeInMemoryContainer())
    }

    /// A deck of two cards, all last edited at `date`.
    private func makeDeck(in context: ModelContext, editedAt date: Date) -> Deck {
        let deck = Deck(name: "Food", icon: "🥩", sortIndex: 0, modifiedAt: date)
        context.insert(deck)

        for (index, pair) in [("Tea", "Té"), ("Bread", "Pan")].enumerated() {
            let card = Card(frontText: pair.0, backText: pair.1, sortIndex: index, modifiedAt: date)
            context.insert(card)
            card.deck = deck
        }

        return deck
    }

    /// The deck as a file would hold it, for a test to alter.
    private func exported(_ deck: Deck) -> DeckTransferDeck {
        DeckExporter.transferFile(for: deck).deckList[0]
    }

    private func makePlan(_ decks: [DeckTransferDeck], against library: [Deck]) -> DeckImportPlan {
        DeckImporter.plan(
            DeckImporter.Preview(decks: decks, skippedCardCount: 0),
            against: library
        )
    }

    // MARK: - Export

    func testExportCarriesIdentifiersAndEditDates() throws {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)

        let data = try DeckExporter.jsonData(for: [deck])
        let file = try JSONDecoder().decode(DeckTransferFile.self, from: data)
        let transfer = try XCTUnwrap(file.deckList.first)

        XCTAssertEqual(transfer.uuid, deck.uuid)
        XCTAssertEqual(transfer.modifiedDate, earlier)
        XCTAssertEqual(Set(transfer.cardList.compactMap(\.uuid)), Set(deck.orderedCards.map(\.uuid)))
        XCTAssertTrue(transfer.cardList.allSatisfy { $0.modifiedDate == earlier })
    }

    func testSeveralDecksGoInOneFile() throws {
        let context = makeContext()
        let decks = [makeDeck(in: context, editedAt: earlier), makeDeck(in: context, editedAt: earlier)]

        let data = try DeckExporter.jsonData(for: decks)
        let preview = try DeckImporter.preview(data: data, kind: .json, fallbackDeckName: "f")

        XCTAssertEqual(preview.deckCount, 2)
        XCTAssertEqual(preview.cardCount, 4)
    }

    func testDatesAreReadWithOrWithoutFractionalSeconds() {
        XCTAssertNotNil(DeckTransferDate.date(from: "2026-10-08T09:30:00Z"))
        XCTAssertNotNil(DeckTransferDate.date(from: "2026-10-08T09:30:00.250Z"))
        XCTAssertNil(DeckTransferDate.date(from: "yesterday"))
    }

    // MARK: - Several files

    func testSeveralFilesBecomeOnePreview() throws {
        let files = [
            DeckImporter.SourceFile(name: "Verbs.csv", data: Data("eat,comer\n".utf8)),
            DeckImporter.SourceFile(name: "Food.csv", data: Data("tea,té\nbread,pan\n".utf8)),
        ]

        let preview = try DeckImporter.preview(files: files, kind: .csv)

        XCTAssertEqual(preview.decks.map(\.name), ["Verbs", "Food"])
        XCTAssertEqual(preview.cardCount, 3)
    }

    func testAFailingFileIsNamed() {
        let files = [
            DeckImporter.SourceFile(name: "Good.json", data: Data(#"{"deckList":[{"name":"A","cardList":[{"frontText":"a","backText":"b"}]}]}"#.utf8)),
            DeckImporter.SourceFile(name: "Broken.json", data: Data("{ nope".utf8)),
        ]

        XCTAssertThrowsError(try DeckImporter.preview(files: files, kind: .json)) { error in
            XCTAssertTrue(error.localizedDescription.hasPrefix("Broken.json"))
        }
    }

    // MARK: - Planning

    func testADeckWithAnUnknownIdentifierIsNew() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)

        var incoming = exported(deck)
        incoming.id = UUID().uuidString

        let plan = makePlan([incoming], against: [deck])

        XCTAssertEqual(plan.newDeckCount, 1)
        XCTAssertTrue(plan.changes.isEmpty)
    }

    func testTheSameDeckAgainChangesNothing() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)

        let plan = makePlan([exported(deck)], against: [deck])

        XCTAssertEqual(plan.newDeckCount, 0)
        XCTAssertFalse(plan.hasChangesToApply)
        XCTAssertFalse(plan.hasConflicts)
    }

    func testANewerFileUpdatesWithoutAsking() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)

        var incoming = exported(deck)
        incoming.cardList[0].backText = "Infusión"
        incoming.cardList[0].modifiedAt = DeckTransferDate.string(from: later)

        let plan = makePlan([incoming], against: [deck])

        XCTAssertEqual(plan.updatedCardCount, 1)
        XCTAssertFalse(plan.hasConflicts)
    }

    func testAnEditMadeHereSinceTheFileIsAConflict() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)
        var incoming = exported(deck)
        incoming.cardList[0].backText = "Infusión"

        // Edited here after the file was written.
        let card = deck.orderedCards[0]
        card.backText = "Té verde"
        card.modifiedAt = later

        let plan = makePlan([incoming], against: [deck])

        XCTAssertEqual(plan.updatedCardCount, 0)
        XCTAssertEqual(plan.conflicts.count, 1)
        XCTAssertEqual(plan.conflicts.first?.mine, "Tea → Té verde")
        XCTAssertEqual(plan.conflicts.first?.theirs, "Tea → Infusión")
    }

    func testAChangeWithNoNewerDateIsAConflict() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)

        // Changed in the file by hand, date untouched.
        var incoming = exported(deck)
        incoming.cardList[1].backText = "Pan integral"

        XCTAssertEqual(makePlan([incoming], against: [deck]).conflicts.count, 1)
    }

    func testCardsNewToTheDeckAreAdded() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)

        var incoming = exported(deck)
        incoming.cardList.append(DeckTransferCard(frontText: "Rice", backText: "Arroz"))

        let plan = makePlan([incoming], against: [deck])

        XCTAssertEqual(plan.newCardCount, 1)
        XCTAssertFalse(plan.hasConflicts)
    }

    func testDeckDetailsAreComparedToo() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)

        var newer = exported(deck)
        newer.name = "Comida"
        newer.modifiedAt = DeckTransferDate.string(from: later)
        XCTAssertEqual(makePlan([newer], against: [deck]).updatedDeckCount, 1)

        var undated = exported(deck)
        undated.name = "Comida"
        XCTAssertTrue(makePlan([undated], against: [deck]).hasConflicts)

        // A file that leaves the details out does not ask to change them.
        var bare = exported(deck)
        bare.name = ""; bare.icon = ""; bare.color = ""
        XCTAssertFalse(makePlan([bare], against: [deck]).hasConflicts)
    }

    // MARK: - Applying

    func testOverwritingTakesTheFilesVersion() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)
        var incoming = exported(deck)
        incoming.cardList[0].backText = "Infusión"
        incoming.cardList.append(DeckTransferCard(frontText: "Rice", backText: "Arroz"))

        let plan = makePlan([incoming], against: [deck])
        DeckImporter.apply(plan, overwritingConflicts: true, into: context, after: 1)

        XCTAssertEqual(deck.orderedCards.map(\.backText), ["Infusión", "Pan", "Arroz"])
    }

    func testNotApplyingKeepsMineButStillAddsTheRest() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)
        var incoming = exported(deck)
        incoming.cardList[0].backText = "Infusión"
        incoming.cardList.append(DeckTransferCard(frontText: "Rice", backText: "Arroz"))

        let plan = makePlan([incoming], against: [deck])
        DeckImporter.apply(plan, overwritingConflicts: false, into: context, after: 1)

        XCTAssertEqual(deck.orderedCards.map(\.backText), ["Té", "Pan", "Arroz"])
    }

    func testAnUpdateLeavesProgressAndBookmarksAlone() {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)
        let card = deck.orderedCards[0]
        card.practiceProgress = 7
        card.isBookmarked = true

        var incoming = exported(deck)
        incoming.cardList[0].backText = "Infusión"
        incoming.cardList[0].modifiedAt = DeckTransferDate.string(from: later)

        DeckImporter.apply(makePlan([incoming], against: [deck]), overwritingConflicts: false, into: context, after: 1)

        XCTAssertEqual(card.backText, "Infusión")
        XCTAssertEqual(card.modifiedAt, later)
        XCTAssertEqual(card.practiceProgress, 7)
        XCTAssertTrue(card.isBookmarked)
    }

    func testANewDeckKeepsTheFilesIdentifiers() throws {
        let context = makeContext()
        let id = UUID()
        let cardID = UUID()
        let incoming = DeckTransferDeck(
            id: id.uuidString,
            name: "Verbs",
            cardList: [DeckTransferCard(id: cardID.uuidString, frontText: "Eat", backText: "Comer")]
        )

        DeckImporter.apply(makePlan([incoming], against: []), overwritingConflicts: false, into: context, after: 0)

        let deck = try XCTUnwrap(try context.fetch(FetchDescriptor<Deck>()).first)
        XCTAssertEqual(deck.uuid, id)
        XCTAssertEqual(deck.orderedCards.first?.uuid, cardID)
    }

    func testAddingAsNewNeverReusesAnIdentifierAlreadyInTheLibrary() throws {
        let context = makeContext()
        let deck = makeDeck(in: context, editedAt: earlier)

        let preview = DeckImporter.Preview(decks: [exported(deck)], skippedCardCount: 0)
        let copy = try XCTUnwrap(DeckImporter.insert(preview, into: context, after: 1).first)

        XCTAssertNotEqual(copy.uuid, deck.uuid)
        XCTAssertTrue(Set(copy.orderedCards.map(\.uuid)).isDisjoint(with: deck.orderedCards.map(\.uuid)))
    }

    // MARK: - Edit dates

    func testEditingACardMovesItsEditDateOnlyWhenTheTextChanges() {
        let card = Card(frontText: "Tea", backText: "Té", modifiedAt: earlier)

        var draft = CardDraft(card: card)
        draft.practiceProgress = 3
        draft.isBookmarked = true
        draft.apply(to: card)
        XCTAssertEqual(card.modifiedAt, earlier)

        draft.backText = "Té verde"
        draft.apply(to: card)
        XCTAssertGreaterThan(card.modifiedAt, earlier)
    }
}
