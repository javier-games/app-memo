//
//  DeckExporter.swift
//  Memo
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Turns stored decks back into file contents.
enum DeckExporter {

    /// The decks as the documented JSON shape.
    ///
    /// Each deck and card carries its identifier and the date it was last
    /// edited, so the file can be imported again as an update. Practice
    /// progress is left out: it belongs to the person practising, not to the
    /// deck, and a shared file should not carry it.
    static func transferFile(for decks: [Deck]) -> DeckTransferFile {
        DeckTransferFile(deckList: decks.map { deck in
            var transfer = DeckTransferDeck(details: deck)
            transfer.cardList = deck.orderedCards.map { DeckTransferCard(card: $0) }
            return transfer
        })
    }

    static func transferFile(for deck: Deck) -> DeckTransferFile {
        transferFile(for: [deck])
    }

    static func jsonData(for decks: [Deck]) throws -> Data {
        let encoder = JSONEncoder()
        // Readable, stable, and without the escaped slashes and \uXXXX that
        // would mangle the emoji and accents these decks are full of.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(transferFile(for: decks))
    }

    static func jsonData(for deck: Deck) throws -> Data {
        try jsonData(for: [deck])
    }

    static func csvText(for deck: Deck) -> String {
        DeckCSVFormat.serialize(
            deck.orderedCards.map {
                DeckTransferCard(
                    frontText: $0.frontText,
                    frontHintText: $0.frontHintText,
                    backText: $0.backText,
                    backHintText: $0.backHintText
                )
            }
        )
    }

    /// A file name built from the deck's name, safe for any file system.
    static func fileName(for deck: Deck, kind: DeckTransferKind) -> String {
        let base = deck.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = base
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")

        let name = cleaned.isEmpty ? String(localized: "Deck") : cleaned
        return "\(name).\(kind.fileExtension)"
    }
}

// MARK: - From the models

extension DeckTransferDeck {

    /// The deck's own details, without its cards.
    init(details deck: Deck) {
        self.init(
            id: deck.uuid.uuidString,
            modifiedAt: DeckTransferDate.string(from: deck.modifiedAt),
            name: deck.name,
            icon: deck.icon,
            color: DeckTransferColor.string(
                red: deck.colorRed,
                green: deck.colorGreen,
                blue: deck.colorBlue,
                alpha: deck.colorAlpha
            )
        )
    }
}

extension DeckTransferCard {

    init(card: Card) {
        self.init(
            id: card.uuid.uuidString,
            modifiedAt: DeckTransferDate.string(from: card.modifiedAt),
            frontText: card.frontText,
            frontHintText: card.frontHintText,
            backText: card.backText,
            backHintText: card.backHintText
        )
    }
}

// MARK: - Shareable files

/// One `Transferable` per format: a transfer representation declares its
/// content type statically, so the two cannot share a type.
struct ExportedDeckJSON: Transferable {

    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName { $0.fileName }
    }
}

struct ExportedDeckCSV: Transferable {

    let text: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.text.utf8) }
            .suggestedFileName { $0.fileName }
    }
}
