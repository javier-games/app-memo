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
    /// JSON and the recordings it refers to, together in a zip.
    case package

    var id: String { rawValue }

    var title: String {
        switch self {
        case .json:    "JSON"
        case .csv:     "CSV"
        case .package: String(localized: "JSON and Audio")
        }
    }

    var contentTypes: [UTType] {
        switch self {
        case .json:    [.json]
        case .csv:     [.commaSeparatedText, .plainText]
        case .package: [.zip]
        }
    }

    var fileExtension: String {
        switch self {
        case .json:    "json"
        case .csv:     "csv"
        case .package: "zip"
        }
    }

    var menuIcon: String {
        switch self {
        case .json:    "curlybraces"
        case .csv:     "tablecells"
        case .package: "doc.zipper"
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

        /// The recordings a package carried, by the reference its cards use.
        var audio: [String: Data] = [:]

        /// Recordings a card referred to that could not be used: missing
        /// from the package, or too large.
        var skippedAudioCount = 0

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
                combined.audio.merge(preview.audio) { first, _ in first }
                combined.skippedAudioCount += preview.skippedAudioCount
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
        let decks: [DeckTransferDeck]
        switch kind {
        case .json:    decks = try decodeJSON(data)
        case .csv:     decks = try decodeCSV(data, deckName: fallbackDeckName)
        case .package: return try DeckPackage.preview(fromZip: data)
        }

        return try preview(decks: decks)
    }

    /// Drops cards that cannot be practised and refuses a file left with
    /// nothing, the same for every format.
    static func preview(decks: [DeckTransferDeck]) throws -> Preview {
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
            // A plain JSON file has no recordings to go with any references,
            // so they are dropped here rather than looked for later.
            return try JSONDecoder().decode(DeckTransferFile.self, from: data).deckList.map { deck in
                var deck = deck
                for index in deck.cardList.indices {
                    for slot in AudioSlot.allCases { deck.cardList[index][audio: slot] = nil }
                }
                return deck
            }
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
                audio: preview.audio,
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
        audio: [String: Data] = [:],
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
            attachAudio(from: transferCard, to: card, audio: audio, onlyEmptySlots: false)
        }

        return deck
    }

    /// Gives `card` the recordings `transferCard` refers to, from `audio`.
    ///
    /// With `onlyEmptySlots`, a slot that already has a recording keeps it:
    /// importing a file again adds the recordings a card lacks, and never
    /// replaces or removes one made here.
    ///
    /// Returns how many recordings were added.
    @discardableResult
    static func attachAudio(
        from transferCard: DeckTransferCard,
        to card: Card,
        audio: [String: Data],
        onlyEmptySlots: Bool
    ) -> Int {
        var added = 0

        for slot in AudioSlot.allCases {
            guard let reference = transferCard[audio: slot],
                  let data = audio[reference],
                  !onlyEmptySlots || card.audio(for: slot) == nil
            else { continue }

            let recording = CardAudio(
                slot: slot,
                data: data,
                duration: DeckPackage.duration(of: data),
                fileExtension: DeckPackage.fileExtension(of: reference)
            )
            card.modelContext?.insert(recording)
            recording.card = card
            added += 1
        }

        return added
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
