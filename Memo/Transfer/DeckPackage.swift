//
//  DeckPackage.swift
//  Memo
//
//  Decks with their recordings, as one zip:
//
//      Food.zip
//      ├── Food.json          the usual deck file, plus a reference per
//      │                      recording, such as "frontAudio": "audio/….m4a"
//      └── audio/
//          └── 6F1C2B3A-….m4a one file per recording, named by its id
//
//  The JSON is the same format as a plain export, so a package can be
//  unzipped and its JSON read or edited by hand. A plain JSON export leaves the
//  references out, since it has no recordings to point at.
//

import AVFoundation
import CoreTransferable
import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

enum DeckPackage {

    static let audioFolder = "audio"

    /// The largest recording an import will take. Recordings made in the app
    /// are far below this; it keeps a stray long file from swelling iCloud.
    static let audioSizeLimit = 5 * 1_048_576

    /// File types a recording may be in.
    static let audioExtensions: Set<String> = ["m4a", "mp3", "aac", "wav", "caf"]

    // MARK: - Exporting

    /// What a package will hold, read from the store.
    struct Contents {
        var file: DeckTransferFile
        var recordings: [(path: String, data: Data)]
    }

    /// Reads the decks, their cards and their recordings. Done on the main
    /// actor, where the store lives; writing the files can happen anywhere.
    @MainActor
    static func contents(for decks: [Deck]) -> Contents {
        var recordings: [(path: String, data: Data)] = []

        let file = DeckTransferFile(deckList: decks.map { deck in
            var transfer = DeckTransferDeck(details: deck)

            transfer.cardList = deck.orderedCards.map { card in
                var transferCard = DeckTransferCard(card: card)

                for slot in AudioSlot.allCases {
                    guard let audio = card.audio(for: slot), let data = audio.data else { continue }

                    let path = "\(audioFolder)/\(audio.uuid.uuidString).\(audio.fileExtension)"
                    transferCard[audio: slot] = path
                    recordings.append((path, data))
                }

                return transferCard
            }

            return transfer
        })

        return Contents(file: file, recordings: recordings)
    }

    /// Writes `contents` as a zip named `name` and returns where it is.
    static func write(_ contents: Contents, named name: String) throws -> URL {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("memo-export-\(UUID().uuidString)")
        let folder = workspace.appendingPathComponent(name)

        try fileManager.createDirectory(
            at: folder.appendingPathComponent(audioFolder),
            withIntermediateDirectories: true
        )

        try DeckExporter.jsonData(for: contents.file)
            .write(to: folder.appendingPathComponent("\(name).json"))

        for recording in contents.recordings {
            try recording.data.write(to: folder.appendingPathComponent(recording.path))
        }

        let zip = workspace.appendingPathComponent("\(name).zip")
        try fileManager.zipItem(at: folder, to: zip, shouldKeepParent: false)
        try? fileManager.removeItem(at: folder)

        return zip
    }

    // MARK: - Importing

    /// Unzips a package and reads every deck file in it, with the recordings
    /// they refer to.
    ///
    /// Each reference is replaced by a key unique to the whole import, so two
    /// deck files in one package can each have an `audio/1.m4a` without
    /// mixing them up.
    static func preview(fromZip data: Data) throws -> DeckImporter.Preview {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("memo-import-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: workspace) }

        let zip = workspace.appendingPathComponent("package.zip")
        let root = workspace.appendingPathComponent("contents", isDirectory: true)

        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: zip)
            try fileManager.unzipItem(at: zip, to: root)
        } catch {
            throw DeckImporter.Failure.unreadable(error.localizedDescription)
        }

        let jsonFiles = deckFiles(in: root)
        guard !jsonFiles.isEmpty else {
            throw DeckImporter.Failure.malformed(String(localized: "The zip holds no deck file."))
        }

        var decks: [DeckTransferDeck] = []
        var audio: [String: Data] = [:]
        var skippedAudio = 0

        for (fileIndex, jsonURL) in jsonFiles.enumerated() {
            let file: DeckTransferFile
            do {
                file = try JSONDecoder().decode(DeckTransferFile.self, from: Data(contentsOf: jsonURL))
            } catch {
                throw DeckImporter.Failure.inFile(
                    name: jsonURL.lastPathComponent,
                    reason: error.localizedDescription
                )
            }

            let folder = jsonURL.deletingLastPathComponent()

            for var deck in file.deckList {
                for index in deck.cardList.indices {
                    for slot in AudioSlot.allCases {
                        guard let reference = deck.cardList[index][audio: slot] else { continue }

                        if let recording = recording(at: reference, in: folder, root: root) {
                            let key = "\(fileIndex)/\(reference)"
                            audio[key] = recording
                            deck.cardList[index][audio: slot] = key
                        } else {
                            skippedAudio += 1
                            deck.cardList[index][audio: slot] = nil
                        }
                    }
                }
                decks.append(deck)
            }
        }

        var preview = try DeckImporter.preview(decks: decks)
        preview.audio = audio
        preview.skippedAudioCount = skippedAudio
        return preview
    }

    /// Every JSON file in the package, in a stable order, leaving out the
    /// folders macOS adds when it makes a zip.
    private static func deckFiles(in root: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var found: [URL] = []

        while let url = enumerator?.nextObject() as? URL {
            if url.path.contains("__MACOSX") { continue }
            if url.pathExtension.lowercased() == "json" { found.append(url) }
        }

        return found.sorted { $0.path < $1.path }
    }

    /// The recording a reference points to, if it is a usable audio file
    /// inside the package. A reference may not climb out of the package.
    private static func recording(at reference: String, in folder: URL, root: URL) -> Data? {
        let url = folder.appendingPathComponent(reference).standardizedFileURL
        let rootPath = root.standardizedFileURL.path

        guard url.path.hasPrefix(rootPath + "/"),
              audioExtensions.contains(url.pathExtension.lowercased()),
              let data = try? Data(contentsOf: url),
              !data.isEmpty,
              data.count <= audioSizeLimit
        else { return nil }

        return data
    }

    // MARK: - Recordings

    /// A recording's length in seconds, or zero if it cannot be read.
    static func duration(of data: Data) -> Double {
        (try? AVAudioPlayer(data: data).duration) ?? 0
    }

    static func fileExtension(of reference: String) -> String {
        let pathExtension = (reference as NSString).pathExtension.lowercased()
        return audioExtensions.contains(pathExtension) ? pathExtension : "m4a"
    }
}

/// Decks with their recordings, shared as a zip.
///
/// The files are only written when the share sheet asks for them, so showing
/// the button costs nothing.
struct ExportedDeckPackage: Transferable {

    let decks: [Deck]
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .zip) { package in
            let contents = await DeckPackage.contents(for: package.decks)
            return SentTransferredFile(try DeckPackage.write(contents, named: package.name))
        }
    }
}

extension Deck {

    /// Whether any card in the deck has a recording.
    var hasAudio: Bool {
        (cards ?? []).contains(where: \.hasAudio)
    }
}
