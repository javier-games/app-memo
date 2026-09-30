//
//  LegacyStoreImportTests.swift
//  MemoTests
//

import XCTest
import SwiftData
@testable import Memo

/// Covers the one-time move off the pre-SwiftData `UserDefaults` blob, using
/// the exact JSON shape the README documents.
final class LegacyStoreImportTests: XCTestCase {

    private static let legacyPayload = """
    {
      "deckList": [
        {
          "name": "Food",
          "icon": "🥩",
          "color": "253,251,102,255",
          "cardList": [
            {"frontText":"Tea","frontHintText":"a hot drink","backText":"Té","backHintText":""},
            {"frontText":"Bread","backText":"Pan"}
          ]
        },
        {
          "name": "Numbers",
          "icon": "🔢",
          "color": "0,0,0,255",
          "cardList": [{"frontText":"One","backText":"Uno"}]
        }
      ]
    }
    """

    private func makeDefaults(function: String = #function) -> UserDefaults {
        let suite = "MemoTests.legacy.\(function)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    @MainActor
    private func makeContext() -> ModelContext {
        ModelContext(MemoModelContainer.makeInMemoryContainer())
    }

    private func fetchDecks(_ context: ModelContext) throws -> [Deck] {
        try context.fetch(
            FetchDescriptor<Deck>(sortBy: [SortDescriptor(\Deck.sortIndex)])
        )
    }

    @MainActor
    func testImportsDecksInOrder() throws {
        let defaults = makeDefaults()
        defaults.set(Data(Self.legacyPayload.utf8), forKey: "DeckList")
        let context = makeContext()

        LegacyStoreImport.runIfNeeded(in: context, defaults: defaults)

        let decks = try fetchDecks(context)
        XCTAssertEqual(decks.map(\.name), ["Food", "Numbers"])
        XCTAssertEqual(decks.first?.icon, "🥩")
    }

    @MainActor
    func testConvertsTheLegacyColourString() throws {
        let defaults = makeDefaults()
        defaults.set(Data(Self.legacyPayload.utf8), forKey: "DeckList")
        let context = makeContext()

        LegacyStoreImport.runIfNeeded(in: context, defaults: defaults)

        let food = try XCTUnwrap(try fetchDecks(context).first)
        XCTAssertEqual(food.colorRed, 253.0 / 255, accuracy: 0.001)
        XCTAssertEqual(food.colorGreen, 251.0 / 255, accuracy: 0.001)
        XCTAssertEqual(food.colorBlue, 102.0 / 255, accuracy: 0.001)
        XCTAssertEqual(food.colorAlpha, 1, accuracy: 0.001)
    }

    @MainActor
    func testKeepsCardOrderAndToleratesAbsentHints() throws {
        let defaults = makeDefaults()
        defaults.set(Data(Self.legacyPayload.utf8), forKey: "DeckList")
        let context = makeContext()

        LegacyStoreImport.runIfNeeded(in: context, defaults: defaults)

        let food = try XCTUnwrap(try fetchDecks(context).first)
        XCTAssertEqual(food.orderedCards.map(\.frontText), ["Tea", "Bread"])
        XCTAssertEqual(food.orderedCards.first?.frontHintText, "a hot drink")
        XCTAssertEqual(food.orderedCards.last?.backHintText, "", "the hint fields postdate the first release")
        XCTAssertTrue(food.orderedCards.allSatisfy { $0.deck?.name == "Food" })
    }

    @MainActor
    func testKeepsABackupAndMarksItselfDone() throws {
        let defaults = makeDefaults()
        defaults.set(Data(Self.legacyPayload.utf8), forKey: "DeckList")

        LegacyStoreImport.runIfNeeded(in: makeContext(), defaults: defaults)

        XCTAssertNil(defaults.data(forKey: "DeckList"))
        XCTAssertNotNil(
            defaults.data(forKey: "DeckList.preSwiftDataBackup"),
            "the original payload is kept rather than deleted"
        )
        XCTAssertTrue(defaults.bool(forKey: "LegacyStoreImport.completed"))
    }

    @MainActor
    func testRunningTwiceDoesNotDuplicate() throws {
        let defaults = makeDefaults()
        defaults.set(Data(Self.legacyPayload.utf8), forKey: "DeckList")
        let context = makeContext()

        LegacyStoreImport.runIfNeeded(in: context, defaults: defaults)
        LegacyStoreImport.runIfNeeded(in: context, defaults: defaults)

        XCTAssertEqual(try fetchDecks(context).count, 2)
    }

    @MainActor
    func testFreshInstallImportsNothingAndStopsChecking() throws {
        let defaults = makeDefaults()
        let context = makeContext()

        LegacyStoreImport.runIfNeeded(in: context, defaults: defaults)

        XCTAssertTrue(try fetchDecks(context).isEmpty)
        XCTAssertTrue(defaults.bool(forKey: "LegacyStoreImport.completed"))
    }

    @MainActor
    func testACorruptPayloadIsLeftAloneForARetry() throws {
        let defaults = makeDefaults()
        defaults.set(Data("{ not json".utf8), forKey: "DeckList")
        let context = makeContext()

        LegacyStoreImport.runIfNeeded(in: context, defaults: defaults)

        XCTAssertNotNil(defaults.data(forKey: "DeckList"), "the user's only copy must survive")
        XCTAssertFalse(defaults.bool(forKey: "LegacyStoreImport.completed"))
        XCTAssertTrue(try fetchDecks(context).isEmpty)
    }
}
