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
        /// A failure in one of several files, so the message can say which.
        case inFile(name: String, reason: String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let reason):
                String(localized: "The file could not be opened. \(reason)")
            case .malformed(let reason):
                String(localized: "The file is not in a format Memo understands. \(reason)")
            case .nothingToImport:
                String(localized: "That file contains no cards to import.")
            case .inFile(let name, let reason):
                "\(name): \(reason)"
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

    /// A file's name and contents, read but not yet parsed.
    struct SourceFile {
        var name: String
        var data: Data
    }

    static func readFiles(at urls: [URL]) throws -> [SourceFile] {
        try urls.map { url in
            do {
                return SourceFile(name: url.lastPathComponent, data: try read(contentsOf: url))
            } catch {
                throw Failure.inFile(name: url.lastPathComponent, reason: error.localizedDescription)
            }
        }
    }

    /// Parses several files into one preview.
    ///
    /// All or nothing: one unusable file stops the import and is named, since
    /// carrying on would leave the user unsure which of their files went in.
    static func preview(files: [SourceFile], kind: DeckTransferKind) throws -> Preview {
        var combined = Preview(decks: [], skippedCardCount: 0)

        for file in files {
            do {
                let preview = try preview(
                    data: file.data,
                    kind: kind,
                    // CSV has nowhere to put a deck name, so the file supplies it.
                    fallbackDeckName: (file.name as NSString).deletingPathExtension
                )
                combined.decks += preview.decks
                combined.skippedCardCount += preview.skippedCardCount
            } catch let error where files.count > 1 {
                throw Failure.inFile(name: file.name, reason: error.localizedDescription)
            }
        }

        return combined
    }

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

    /// Adds the previewed decks to the library as new decks, whatever
    /// identifiers the file carries.
    ///
    /// The plain "add" used for files with nothing to match against, and for
    /// decks an AI wrote. A file that may update decks already in the library
    /// goes through ``plan(_:against:)`` instead.
    @discardableResult
    static func insert(
        _ preview: Preview,
        into context: ModelContext,
        after existingDeckCount: Int
    ) -> [Deck] {
        var takenIDs = existingIDs(in: context)

        return preview.decks.enumerated().map { offset, transferDeck in
            insert(
                transferDeck,
                sortIndex: existingDeckCount + offset,
                takenIDs: &takenIDs,
                into: context
            )
        }
    }

    /// Inserts one deck with its cards.
    ///
    /// The file's identifiers are kept, so the same file imported later is
    /// recognised — unless something in the library already has one of them,
    /// in which case that deck or card gets a fresh one. Two things sharing an
    /// identifier would make every later match ambiguous.
    static func insert(
        _ transferDeck: DeckTransferDeck,
        sortIndex: Int,
        takenIDs: inout Set<UUID>,
        into context: ModelContext
    ) -> Deck {
        let deck = Deck(
            uuid: claim(transferDeck.uuid, in: &takenIDs),
            name: transferDeck.name.isEmpty
                ? String(localized: "Imported Deck")
                : transferDeck.name,
            icon: transferDeck.icon.isEmpty ? defaultIcon : transferDeck.icon,
            sortIndex: sortIndex,
            modifiedAt: transferDeck.modifiedDate ?? Date()
        )

        let color = DeckTransferColor.components(from: transferDeck.color)
        deck.colorRed = color.red
        deck.colorGreen = color.green
        deck.colorBlue = color.blue
        deck.colorAlpha = color.alpha

        context.insert(deck)

        for (cardIndex, transferCard) in transferDeck.cardList.enumerated() {
            let card = makeCard(from: transferCard, sortIndex: cardIndex, takenIDs: &takenIDs)
            context.insert(card)
            card.deck = deck
        }

        return deck
    }

    static func makeCard(
        from transferCard: DeckTransferCard,
        sortIndex: Int,
        takenIDs: inout Set<UUID>
    ) -> Card {
        Card(
            uuid: claim(transferCard.uuid, in: &takenIDs),
            frontText: transferCard.frontText,
            backText: transferCard.backText,
            frontHintText: transferCard.frontHintText,
            backHintText: transferCard.backHintText,
            sortIndex: sortIndex,
            modifiedAt: transferCard.modifiedDate ?? Date(),
            practiceProgress: max(0, transferCard.practiceProgress ?? 0)
        )
    }

    /// Every deck and card identifier already in the store.
    static func existingIDs(in context: ModelContext) -> Set<UUID> {
        let decks = (try? context.fetch(FetchDescriptor<Deck>())) ?? []
        let cards = (try? context.fetch(FetchDescriptor<Card>())) ?? []
        return Set(decks.map(\.uuid)).union(cards.map(\.uuid))
    }

    /// `wanted` if it is free, otherwise a new identifier; either way marked
    /// as taken.
    private static func claim(_ wanted: UUID?, in takenIDs: inout Set<UUID>) -> UUID {
        let id = wanted.flatMap { takenIDs.contains($0) ? nil : $0 } ?? UUID()
        takenIDs.insert(id)
        return id
    }

    /// Used when a file gives no icon of its own.
    static let defaultIcon = "📥"
}
