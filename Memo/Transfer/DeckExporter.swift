//
//  DeckExporter.swift
//  Memo
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Turns a stored deck back into file contents.
enum DeckExporter {

    /// The deck as the documented JSON shape.
    ///
    /// `practiceProgress` is left out so an exported file matches the format
    /// published in the README exactly. Including it would make a round trip
    /// lossless but would put a field in the file that the documented schema
    /// does not mention.
    static func transferFile(for deck: Deck) -> DeckTransferFile {
        DeckTransferFile(deckList: [
            DeckTransferDeck(
                name: deck.name,
                icon: deck.icon,
                color: DeckTransferColor.string(
                    red: deck.colorRed,
                    green: deck.colorGreen,
                    blue: deck.colorBlue,
                    alpha: deck.colorAlpha
                ),
                cardList: deck.orderedCards.map {
                    DeckTransferCard(
                        frontText: $0.frontText,
                        frontHintText: $0.frontHintText,
                        backText: $0.backText,
                        backHintText: $0.backHintText
                    )
                }
            )
        ])
    }

    static func jsonData(for deck: Deck) throws -> Data {
        let encoder = JSONEncoder()
        // Readable, stable, and without the escaped slashes and \uXXXX that
        // would mangle the emoji and accents these decks are full of.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(transferFile(for: deck))
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
