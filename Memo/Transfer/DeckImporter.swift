//
//  DeckImporter.swift
//  Memo
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The file formats decks travel in.
enum DeckTransferKind: String, CaseIterable, Identifiable {

    case json
    case csv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .json: "JSON"
        case .csv:  "CSV"
        }
    }

    var contentTypes: [UTType] {
        switch self {
        case .json: [.json]
        case .csv:  [.commaSeparatedText, .plainText]
        }
    }

    var fileExtension: String { rawValue }

    var menuIcon: String {
        switch self {
        case .json: "curlybraces"
        case .csv:  "tablecells"
        }
    }
}

/// Reads deck files into the store.
///
/// Splits deliberately into reading, previewing and inserting. Parsing a file
/// should never be the same step as committing it: the user sees what was found
/// before anything is written, and a malformed file surfaces as a message
/// rather than as a half-finished import.
enum DeckImporter {

    enum Failure: LocalizedError {

        case unreadable(String)
        case malformed(String)
        case nothingToImport

        var errorDescription: String? {
            switch self {
            case .unreadable(let reason):
                String(localized: "The file could not be opened. \(reason)")
            case .malformed(let reason):
                String(localized: "The file is not in a format Memo understands. \(reason)")
            case .nothingToImport:
                String(localized: "That file contains no cards to import.")
            }
        }
    }

    /// What a file turned out to contain, before anything is written.
    struct Preview {

        var decks: [DeckTransferDeck]

        /// Cards found but left out because they had no front or no back.
        var skippedCardCount: Int

        var deckCount: Int { decks.count }
        var cardCount: Int { decks.reduce(0) { $0 + $1.cardList.count } }
        var isEmpty: Bool { cardCount == 0 }
    }

    // MARK: - Reading

    /// Reads a file the user picked.
    ///
    /// The security-scoped resource must be opened and closed around the read:
    /// a document picked outside the app's container is otherwise unreadable on
    /// a real device, which is the classic way this feature fails only after
    /// shipping.
    static func read(contentsOf url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw Failure.unreadable(error.localizedDescription)
        }
    }

    // MARK: - Previewing

    static func preview(
        data: Data,
        kind: DeckTransferKind,
        fallbackDeckName: String
    ) throws -> Preview {
        let decks: [DeckTransferDeck] = switch kind {
        case .json: try decodeJSON(data)
        case .csv:  try decodeCSV(data, deckName: fallbackDeckName)
        }

        var skipped = 0
        let cleaned: [DeckTransferDeck] = decks.map { deck in
            var deck = deck
            let complete = deck.cardList.filter(\.isComplete)
            skipped += deck.cardList.count - complete.count
            deck.cardList = complete
            return deck
        }
        .filter { !$0.cardList.isEmpty }

        let preview = Preview(decks: cleaned, skippedCardCount: skipped)
        guard !preview.isEmpty else { throw Failure.nothingToImport }

        return preview
    }

    private static func decodeJSON(_ data: Data) throws -> [DeckTransferDeck] {
        do {
            return try JSONDecoder().decode(DeckTransferFile.self, from: data).deckList
        } catch {
            throw Failure.malformed(error.localizedDescription)
        }
    }

    private static func decodeCSV(_ data: Data, deckName: String) throws -> [DeckTransferDeck] {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        else {
            throw Failure.malformed(String(localized: "Its text could not be read."))
        }

        return [
            DeckTransferDeck(
                name: deckName,
                icon: defaultIcon,
                cardList: DeckCSVFormat.parse(text)
            )
        ]
    }

    // MARK: - Inserting

    /// Appends the previewed decks to the library.
    ///
    /// Import only ever adds. The documented file format carries no identifier,
    /// so there is no sound way to tell "the same deck again" from "a different
    /// deck with the same name" — and guessing wrong would overwrite something
    /// the user still wanted. New decks are appended after the existing ones.
    @discardableResult
    static func insert(
        _ preview: Preview,
        into context: ModelContext,
        after existingDeckCount: Int
    ) -> [Deck] {
        preview.decks.enumerated().map { offset, transferDeck in
            let deck = Deck(
                name: transferDeck.name.isEmpty
                    ? String(localized: "Imported Deck")
                    : transferDeck.name,
                icon: transferDeck.icon.isEmpty ? defaultIcon : transferDeck.icon,
                sortIndex: existingDeckCount + offset
            )

            let color = DeckTransferColor.components(from: transferDeck.color)
            deck.colorRed = color.red
            deck.colorGreen = color.green
            deck.colorBlue = color.blue
            deck.colorAlpha = color.alpha

            context.insert(deck)

            for (cardIndex, transferCard) in transferDeck.cardList.enumerated() {
                let card = Card(
                    frontText: transferCard.frontText,
                    backText: transferCard.backText,
                    frontHintText: transferCard.frontHintText,
                    backHintText: transferCard.backHintText,
                    sortIndex: cardIndex,
                    practiceProgress: max(0, transferCard.practiceProgress ?? 0)
                )
                context.insert(card)
                card.deck = deck
            }

            return deck
        }
    }

    /// Used when a file gives no icon of its own.
    static let defaultIcon = "📥"
}
