//
//  RepositorySync.swift
//  Memo
//
//  The rules for syncing decks with a repository, apart from the network and
//  the screen: what the repository holds, how each deck stands against it,
//  and exactly which files a push would write.
//

import Foundation

/// What was read from the repository.
struct RepositorySnapshot {

    struct File {
        var path: String
        var sha: String
        var decks: [DeckTransferDeck]
    }

    /// The same deck found in more than one place. Which copy is the real one
    /// cannot be guessed, so such a deck is left alone until the repository is
    /// tidied.
    struct Duplicate: Identifiable, Equatable {
        var deckID: UUID
        var name: String
        var paths: [String]

        var id: UUID { deckID }
    }

    var files: [File] = []

    /// Deck files that could not be read as one.
    var unreadablePaths: [String] = []

    var duplicates: [Duplicate] {
        var seen: [UUID: (name: String, paths: [String])] = [:]

        for file in files {
            for deck in file.decks {
                guard let id = deck.uuid else { continue }
                seen[id, default: (deck.name, [])].paths.append(file.path)
            }
        }

        return seen
            .filter { $0.value.paths.count > 1 }
            .map { Duplicate(deckID: $0.key, name: $0.value.name, paths: $0.value.paths) }
            .sorted { $0.name < $1.name }
    }

    func file(at path: String) -> File? {
        files.first { $0.path == path }
    }

    /// Where the deck with `id` lives, if it lives in exactly one place.
    func location(of id: UUID) -> (file: File, deck: DeckTransferDeck)? {
        let found = files.flatMap { file in
            file.decks.filter { $0.uuid == id }.map { (file: file, deck: $0) }
        }

        return found.count == 1 ? found[0] : nil
    }
}

/// One deck, as it stands between this device and the repository.
struct RepositoryItem: Identifiable {

    enum State: Equatable {
        /// Made on this device and never pushed.
        case onlyHere
        /// In the repository and not on this device.
        case onlyInRepository
        case same
        case different
        /// In the repository more than once; see ``RepositorySnapshot/Duplicate``.
        case duplicated
    }

    let id: String
    var name: String
    var icon: String
    var state: State

    var local: Deck?
    var remote: DeckTransferDeck?

    var canPush: Bool { local != nil && (state == .onlyHere || state == .different) }
    var canPull: Bool { remote != nil && (state == .onlyInRepository || state == .different) }
}

/// One file a push would create or replace.
struct RepositoryWrite: Equatable {
    var path: String
    /// The version being replaced, or `nil` for a new file.
    var sha: String?
    var data: Data
    var message: String
}

enum RepositorySync {

    /// The file that holds every deck when the library is kept as one file.
    static let libraryPath = DeckExporter.libraryFileName

    static let readmePath = "README.md"

    /// What an empty repository is started with, so it has a first commit and
    /// says what it is for.
    static let readme = """
        # Memo Decks

        Flashcard decks synced by the Memo Decks app. Each `.json` file holds one \
        or more decks. Edit them here or in the app; the app matches decks by the \
        `id` inside the file, so files can be renamed freely.

        """

    // MARK: - Reading

    /// The files that hold decks, given how the library is laid out: the one
    /// library file, or every other JSON file at the root.
    static func deckPaths(among entries: [GitHubEntry], usesSingleFile: Bool) -> [GitHubEntry] {
        entries.filter { entry in
            guard entry.isFile, entry.path.lowercased().hasSuffix(".json") else { return false }
            return (entry.path == libraryPath) == usesSingleFile
        }
    }

    static func snapshot(of contents: [(entry: GitHubEntry, data: Data)]) -> RepositorySnapshot {
        var snapshot = RepositorySnapshot()

        for (entry, data) in contents {
            if let file = try? JSONDecoder().decode(DeckTransferFile.self, from: data) {
                snapshot.files.append(
                    RepositorySnapshot.File(path: entry.path, sha: entry.sha, decks: file.deckList)
                )
            } else {
                snapshot.unreadablePaths.append(entry.path)
            }
        }

        return snapshot
    }

    // MARK: - Comparing

    /// Every deck on either side, with how the two sides compare.
    static func items(local decks: [Deck], snapshot: RepositorySnapshot) -> [RepositoryItem] {
        let duplicated = Set(snapshot.duplicates.map(\.deckID))
        var items: [RepositoryItem] = []
        var matched: Set<UUID> = []

        for deck in decks {
            var item = RepositoryItem(
                id: deck.uuid.uuidString,
                name: deck.name,
                icon: deck.icon,
                state: .onlyHere,
                local: deck
            )

            if duplicated.contains(deck.uuid) {
                item.state = .duplicated
                matched.insert(deck.uuid)
            } else if let remote = snapshot.location(of: deck.uuid)?.deck {
                item.remote = remote
                item.state = matches(deck, remote) ? .same : .different
                matched.insert(deck.uuid)
            }

            items.append(item)
        }

        for file in snapshot.files {
            for (index, remote) in file.decks.enumerated() {
                if let id = remote.uuid, matched.contains(id) { continue }

                // A deck with no identifier can never be matched, so it is
                // always something the repository has and this device lacks.
                let isDuplicate = remote.uuid.map { duplicated.contains($0) } ?? false
                if isDuplicate, let id = remote.uuid { matched.insert(id) }

                items.append(RepositoryItem(
                    id: remote.uuid?.uuidString ?? "\(file.path)#\(index)",
                    name: remote.name.isEmpty ? file.path : remote.name,
                    icon: remote.icon,
                    state: isDuplicate ? .duplicated : .onlyInRepository,
                    remote: isDuplicate ? nil : remote
                ))
            }
        }

        return items
    }

    /// Whether pulling would change nothing and pushing would add nothing.
    static func matches(_ deck: Deck, _ remote: DeckTransferDeck) -> Bool {
        let plan = DeckImporter.plan(
            DeckImporter.Preview(decks: [remote], skippedCardCount: 0),
            against: [deck]
        )
        guard !plan.hasChangesToApply, !plan.hasConflicts else { return false }

        // The plan only looks one way. A card made here that the repository
        // has never seen is a difference too.
        let remoteCards = Set(remote.cardList.compactMap(\.uuid))
        return (deck.cards ?? []).allSatisfy { remoteCards.contains($0.uuid) }
    }

    // MARK: - Pushing

    /// The files to write so the repository holds `decks` as they are here.
    ///
    /// A deck already in the repository is written back to the file it is in,
    /// whatever that file is called, and any other decks in that file are
    /// kept. A deck the repository has never seen gets a file named after it,
    /// or joins the library file.
    static func writes(
        pushing decks: [Deck],
        snapshot: RepositorySnapshot,
        usesSingleFile: Bool
    ) throws -> [RepositoryWrite] {
        // Path → the decks that file will hold, starting from what it holds.
        var contents: [String: [DeckTransferDeck]] = [:]
        var order: [String] = []
        var changed: [String: [String]] = [:]

        var takenPaths = Set(snapshot.files.map { $0.path.lowercased() })

        for deck in decks {
            let transfer = DeckExporter.transferFile(for: deck).deckList[0]

            let path: String
            if let existing = snapshot.location(of: deck.uuid)?.file.path {
                path = existing
            } else if usesSingleFile {
                path = libraryPath
            } else {
                path = freeFileName(for: deck, taken: &takenPaths)
            }

            if contents[path] == nil {
                contents[path] = snapshot.file(at: path)?.decks ?? []
                order.append(path)
            }

            if let index = contents[path]?.firstIndex(where: { $0.uuid == deck.uuid }) {
                contents[path]?[index] = transfer
            } else {
                contents[path]?.append(transfer)
            }

            changed[path, default: []].append(deck.name)
        }

        return try order.map { path in
            RepositoryWrite(
                path: path,
                sha: snapshot.file(at: path)?.sha,
                data: try DeckExporter.jsonData(for: DeckTransferFile(deckList: contents[path] ?? [])),
                message: message(for: changed[path] ?? [], isNew: snapshot.file(at: path) == nil)
            )
        }
    }

    /// A file name for a deck that does not clash with one already there.
    /// Two decks may share a name; their files cannot.
    private static func freeFileName(for deck: Deck, taken: inout Set<String>) -> String {
        var name = DeckExporter.fileName(for: deck, kind: .json)

        if taken.contains(name.lowercased()) {
            let base = (name as NSString).deletingPathExtension
            name = "\(base) \(deck.uuid.uuidString.prefix(8)).json"
        }

        taken.insert(name.lowercased())
        return name
    }

    private static func message(for names: [String], isNew: Bool) -> String {
        guard names.count == 1, let name = names.first else {
            return "Update \(names.count) decks"
        }
        return isNew ? "Add \(name)" : "Update \(name)"
    }
}
