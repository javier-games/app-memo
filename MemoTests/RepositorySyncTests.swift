//
//  RepositorySyncTests.swift
//  MemoTests
//

import XCTest
import SwiftData
@testable import Memo

@MainActor
final class RepositorySyncTests: XCTestCase {

    private func makeContext() -> ModelContext {
        ModelContext(MemoModelContainer.makeInMemoryContainer())
    }

    private func makeDeck(_ name: String, in context: ModelContext, cards: [(String, String)] = [("Tea", "Té")]) -> Deck {
        let deck = Deck(name: name, icon: "🥩", sortIndex: 0)
        context.insert(deck)

        for (index, pair) in cards.enumerated() {
            let card = Card(frontText: pair.0, backText: pair.1, sortIndex: index)
            context.insert(card)
            card.deck = deck
        }

        return deck
    }

    private func transfer(_ deck: Deck) -> DeckTransferDeck {
        DeckExporter.transferFile(for: deck).deckList[0]
    }

    private func file(_ path: String, _ decks: [DeckTransferDeck]) -> RepositorySnapshot.File {
        RepositorySnapshot.File(path: path, sha: "sha-\(path)", decks: decks)
    }

    private func decks(in write: RepositoryWrite) throws -> [DeckTransferDeck] {
        try JSONDecoder().decode(DeckTransferFile.self, from: write.data).deckList
    }

    // MARK: - Reading

    func testLayoutDecidesWhichFilesHoldDecks() {
        let entries = [
            GitHubEntry(path: "Food.json", sha: "1", isFile: true),
            GitHubEntry(path: "Memo Decks.json", sha: "2", isFile: true),
            GitHubEntry(path: "README.md", sha: "3", isFile: true),
            GitHubEntry(path: "archive.json", sha: "4", isFile: false),
        ]

        XCTAssertEqual(
            RepositorySync.deckPaths(among: entries, usesSingleFile: false).map(\.path),
            ["Food.json"]
        )
        XCTAssertEqual(
            RepositorySync.deckPaths(among: entries, usesSingleFile: true).map(\.path),
            ["Memo Decks.json"]
        )
    }

    func testAFileThatIsNotDecksIsReportedNotDropped() throws {
        let context = makeContext()
        let good = try DeckExporter.jsonData(for: makeDeck("Food", in: context))

        let snapshot = RepositorySync.snapshot(of: [
            (GitHubEntry(path: "Food.json", sha: "1", isFile: true), good),
            (GitHubEntry(path: "package.json", sha: "2", isFile: true), Data(#"{"name":"x"}"#.utf8)),
        ])

        XCTAssertEqual(snapshot.files.map(\.path), ["Food.json"])
        XCTAssertEqual(snapshot.unreadablePaths, ["package.json"])
    }

    // MARK: - Comparing

    func testADeckMadeHereIsOnlyHere() {
        let context = makeContext()
        let deck = makeDeck("Food", in: context)

        let items = RepositorySync.items(local: [deck], snapshot: RepositorySnapshot())

        XCTAssertEqual(items.map(\.state), [.onlyHere])
        XCTAssertTrue(items[0].canPush)
        XCTAssertFalse(items[0].canPull)
    }

    func testADeckOnlyInTheRepositoryCanBePulled() {
        let remote = DeckTransferDeck(id: UUID().uuidString, name: "Verbs", cardList: [
            DeckTransferCard(frontText: "Eat", backText: "Comer")
        ])

        let items = RepositorySync.items(
            local: [],
            snapshot: RepositorySnapshot(files: [file("Verbs.json", [remote])])
        )

        XCTAssertEqual(items.map(\.state), [.onlyInRepository])
        XCTAssertTrue(items[0].canPull)
        XCTAssertFalse(items[0].canPush)
    }

    func testTheSameDeckOnBothSidesIsUpToDate() {
        let context = makeContext()
        let deck = makeDeck("Food", in: context)
        let snapshot = RepositorySnapshot(files: [file("Food.json", [transfer(deck)])])

        XCTAssertEqual(RepositorySync.items(local: [deck], snapshot: snapshot).map(\.state), [.same])
    }

    func testADifferenceOnEitherSideIsSeen() {
        let context = makeContext()
        let deck = makeDeck("Food", in: context)
        let pushed = transfer(deck)

        // Changed in the repository.
        var edited = pushed
        edited.cardList[0].backText = "Infusión"
        XCTAssertEqual(
            RepositorySync.items(
                local: [deck],
                snapshot: RepositorySnapshot(files: [file("Food.json", [edited])])
            ).map(\.state),
            [.different]
        )

        // A card added here that the repository has never seen.
        let card = Card(frontText: "Bread", backText: "Pan", sortIndex: 1)
        context.insert(card)
        card.deck = deck
        XCTAssertEqual(
            RepositorySync.items(
                local: [deck],
                snapshot: RepositorySnapshot(files: [file("Food.json", [pushed])])
            ).map(\.state),
            [.different]
        )
    }

    func testADeckInTwoFilesIsReportedAndLeftAlone() {
        let context = makeContext()
        let deck = makeDeck("Food", in: context)
        let snapshot = RepositorySnapshot(files: [
            file("Food.json", [transfer(deck)]),
            file("Copy of Food.json", [transfer(deck)]),
        ])

        XCTAssertEqual(snapshot.duplicates.map(\.deckID), [deck.uuid])
        XCTAssertEqual(snapshot.duplicates.first?.paths, ["Food.json", "Copy of Food.json"])

        let items = RepositorySync.items(local: [deck], snapshot: snapshot)
        XCTAssertEqual(items.map(\.state), [.duplicated])
        XCTAssertFalse(items[0].canPush)
        XCTAssertFalse(items[0].canPull)
    }

    func testADuplicateNotOnThisDeviceIsListedOnce() {
        let remote = DeckTransferDeck(id: UUID().uuidString, name: "Verbs")
        let snapshot = RepositorySnapshot(files: [file("a.json", [remote]), file("b.json", [remote])])

        let items = RepositorySync.items(local: [], snapshot: snapshot)

        XCTAssertEqual(items.map(\.state), [.duplicated])
    }

    // MARK: - Pushing

    func testANewDeckGetsAFileOfItsOwn() throws {
        let context = makeContext()
        let deck = makeDeck("Food", in: context)

        let writes = try RepositorySync.writes(
            pushing: [deck], snapshot: RepositorySnapshot(), usesSingleFile: false
        )

        XCTAssertEqual(writes.map(\.path), ["Food.json"])
        XCTAssertNil(writes[0].sha, "a new file replaces nothing")
        XCTAssertEqual(writes[0].message, "Add Food")
        XCTAssertEqual(try decks(in: writes[0]).map(\.uuid), [deck.uuid])
    }

    func testTwoDecksWithOneNameGetDifferentFiles() throws {
        let context = makeContext()
        let first = makeDeck("Food", in: context)
        let second = makeDeck("Food", in: context)

        let writes = try RepositorySync.writes(
            pushing: [first, second], snapshot: RepositorySnapshot(), usesSingleFile: false
        )

        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(Set(writes.map { $0.path.lowercased() }).count, 2)
    }

    func testAnExistingDeckIsWrittenBackWhereItLives() throws {
        let context = makeContext()
        let deck = makeDeck("Food", in: context)
        let other = DeckTransferDeck(id: UUID().uuidString, name: "Verbs")

        // Renamed in the repository, and sharing its file with another deck.
        let snapshot = RepositorySnapshot(files: [file("renamed.json", [other, transfer(deck)])])
        deck.name = "Comida"

        let writes = try RepositorySync.writes(pushing: [deck], snapshot: snapshot, usesSingleFile: false)

        XCTAssertEqual(writes.map(\.path), ["renamed.json"])
        XCTAssertEqual(writes[0].sha, "sha-renamed.json")
        XCTAssertEqual(writes[0].message, "Update Comida")
        XCTAssertEqual(try decks(in: writes[0]).map(\.name), ["Verbs", "Comida"], "the other deck is kept")
    }

    func testOneFileHoldsEveryDeckWhenAskedTo() throws {
        let context = makeContext()
        let food = makeDeck("Food", in: context)
        let verbs = makeDeck("Verbs", in: context)
        let existing = DeckTransferDeck(id: UUID().uuidString, name: "Kanji")
        let snapshot = RepositorySnapshot(files: [file("Memo Decks.json", [existing])])

        let writes = try RepositorySync.writes(
            pushing: [food, verbs], snapshot: snapshot, usesSingleFile: true
        )

        XCTAssertEqual(writes.map(\.path), ["Memo Decks.json"])
        XCTAssertEqual(writes[0].message, "Update 2 decks")
        XCTAssertEqual(try decks(in: writes[0]).map(\.name), ["Kanji", "Food", "Verbs"])
    }

    func testNothingButTheDeckAndItsCardsIsPushed() throws {
        let context = makeContext()
        let deck = makeDeck("Food", in: context)
        let card = try XCTUnwrap(deck.orderedCards.first)
        card.practiceProgress = 7
        card.isBookmarked = true

        var settings = PracticeSettings()
        settings.mode = .bookmarked
        deck.practiceSettings = settings

        let write = try XCTUnwrap(
            RepositorySync.writes(pushing: [deck], snapshot: RepositorySnapshot(), usesSingleFile: false).first
        )
        let text = String(decoding: write.data, as: UTF8.self)

        XCTAssertFalse(text.contains("practiceProgress"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("bookmark"))
        XCTAssertFalse(text.contains("practiceSettings"))
    }

    // MARK: - Audio

    private func addAudio(_ slot: AudioSlot, to card: Card, in context: ModelContext, id: UUID = UUID()) {
        let audio = CardAudio(uuid: id, slot: slot, data: Data([7, 7]), duration: 1)
        context.insert(audio)
        audio.card = card
    }

    func testARecordingOnOneSideOnlyMakesADeckDifferent() throws {
        let context = makeContext()
        let deck = makeDeck("Food", in: context)
        let card = try XCTUnwrap(deck.orderedCards.first)

        // In the repository, not here: the text matches, the audio does not.
        var remote = transfer(deck)
        remote.cardList[0].backAudio = "audio/\(UUID().uuidString).mp3"
        XCTAssertEqual(
            RepositorySync.items(local: [deck], snapshot: RepositorySnapshot(files: [file("Food.json", [remote])])).map(\.state),
            [.different]
        )

        // Here, not in the repository.
        addAudio(.back, to: card, in: context)
        XCTAssertEqual(
            RepositorySync.items(local: [deck], snapshot: RepositorySnapshot(files: [file("Food.json", [transfer(deck)])])).map(\.state),
            [.different]
        )

        // On both.
        XCTAssertEqual(
            RepositorySync.items(local: [deck], snapshot: RepositorySnapshot(files: [file("Food.json", [remote])])).map(\.state),
            [.same]
        )
    }

    func testAPullDownloadsOnlyTheRecordingsACardLacks() throws {
        let context = makeContext()
        let deck = makeDeck("Food", in: context, cards: [("Tea", "Té"), ("Bread", "Pan")])
        let cards = deck.orderedCards
        addAudio(.back, to: cards[0], in: context)

        var remote = transfer(deck)
        remote.cardList[0].backAudio = "audio/A.mp3"       // already has one: skipped
        remote.cardList[1].backAudio = "audio/B.mp3"       // lacks one: fetched
        remote.cardList[1].backHintAudio = "../secret.mp3" // leaves the repository: refused

        let newDeck = DeckTransferDeck(id: UUID().uuidString, name: "New", cardList: [
            DeckTransferCard(id: UUID().uuidString, frontText: "Eat", backText: "Comer", backAudio: "audio/C.m4a")
        ])

        XCTAssertEqual(
            RepositorySync.audioToDownload(for: [remote, newDeck], against: [deck]),
            ["audio/B.mp3", "audio/C.m4a"]
        )
    }

    func testOnlyAudioInsideTheRepositoryIsFetched() {
        XCTAssertTrue(RepositorySync.isSafe("audio/0A1B.mp3"))
        XCTAssertTrue(RepositorySync.isSafe("library/N5/肩.mp3"))
        XCTAssertFalse(RepositorySync.isSafe("../outside.mp3"))
        XCTAssertFalse(RepositorySync.isSafe("/etc/passwd.mp3"))
        XCTAssertFalse(RepositorySync.isSafe("audio//x.mp3"))
        XCTAssertFalse(RepositorySync.isSafe("audio/notes.txt"))
    }

    func testAPushKeepsTheAudioReferencesAndSendsOnlyNewRecordings() throws {
        let context = makeContext()
        let deck = makeDeck("Food", in: context, cards: [("Tea", "Té"), ("Bread", "Pan")])
        let kept = UUID()
        let fresh = UUID()
        addAudio(.back, to: deck.orderedCards[0], in: context, id: kept)
        addAudio(.back, to: deck.orderedCards[1], in: context, id: fresh)

        let writes = try RepositorySync.writes(pushing: [deck], snapshot: RepositorySnapshot(), usesSingleFile: false)
        let pushed = try decks(in: writes[0])[0]
        XCTAssertEqual(pushed.cardList[0].backAudio, "audio/\(kept.uuidString).m4a")
        XCTAssertEqual(pushed.cardList[1].backAudio, "audio/\(fresh.uuidString).m4a")

        let uploads = RepositorySync.recordingWrites(for: [deck], existing: ["\(kept.uuidString).m4a"])
        XCTAssertEqual(uploads.map(\.path), ["audio/\(fresh.uuidString).m4a"])
        XCTAssertNil(uploads.first?.sha)
    }

    func testAPulledRecordingKeepsTheIdItsFileIsNamedBy() throws {
        let context = makeContext()
        let card = Card(frontText: "Tea", backText: "Té")
        context.insert(card)
        let id = UUID()

        DeckImporter.attachAudio(
            from: DeckTransferCard(backAudio: "audio/\(id.uuidString).mp3"),
            to: card,
            audio: ["audio/\(id.uuidString).mp3": Data([1])],
            onlyEmptySlots: true
        )

        XCTAssertEqual(card.audio(for: .back)?.uuid, id, "so pushing it back does not upload it again")
        XCTAssertEqual(card.audio(for: .back)?.fileExtension, "mp3")
    }

    func testTreesAreReadForFolderListings() {
        let entries = GitHubClient.treeEntries(from: Data(#"""
            {"tree":[{"path":"a.mp3","type":"blob","sha":"1"},{"path":"sub","type":"tree","sha":"2"}]}
            """#.utf8))

        XCTAssertEqual(entries, [
            GitHubEntry(path: "a.mp3", sha: "1", isFile: true),
            GitHubEntry(path: "sub", sha: "2", isFile: false),
        ])
    }

    // MARK: - GitHub

    func testAWriteQuotesTheVersionItReplaces() throws {
        let request = try GitHubClient.writeRequest(
            Data("{}".utf8),
            to: "Spanish Food 🥩.json",
            replacing: "abc123",
            message: "Update Food",
            in: "javier/decks",
            token: "token"
        )
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any]
        )

        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(body["sha"] as? String, "abc123")
        XCTAssertEqual(body["content"] as? String, Data("{}".utf8).base64EncodedString())

        let url = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertTrue(url.hasPrefix("https://api.github.com/repos/javier/decks/contents/Spanish%20Food%20"))
        XCTAssertFalse(url.contains(" "))
    }

    func testANewFileQuotesNoVersion() throws {
        let request = try GitHubClient.writeRequest(
            Data(), to: "Food.json", replacing: nil, message: "Add Food", in: "javier/decks", token: "token"
        )
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any]
        )

        XCTAssertNil(body["sha"])
    }

    func testSignInPollingReadsEveryAnswer() {
        func result(_ json: String) -> GitHubClient.PollResult {
            GitHubClient.pollResult(from: Data(json.utf8))
        }

        XCTAssertEqual(result(#"{"access_token":"gho_x","token_type":"bearer"}"#), .token("gho_x"))
        XCTAssertEqual(result(#"{"error":"authorization_pending"}"#), .pending)
        XCTAssertEqual(result(#"{"error":"slow_down"}"#), .slowDown)
        XCTAssertEqual(result(#"{"error":"expired_token"}"#), .failed(.signInExpired))
        XCTAssertEqual(result(#"{"error":"access_denied"}"#), .failed(.signInDenied))
    }

    func testAnEmptyRepositoryIsToldFromAMissingOne() {
        XCTAssertTrue(GitHubClient.saysEmpty("This repository is empty."))
        XCTAssertFalse(GitHubClient.saysEmpty("Not Found"))
    }

    func testListingKeepsPathsAndVersions() {
        let entries = GitHubClient.entries(from: Data(#"""
            [{"name":"Food.json","path":"Food.json","sha":"1","type":"file"},
             {"name":"notes","path":"notes","sha":"2","type":"dir"}]
            """#.utf8))

        XCTAssertEqual(entries, [
            GitHubEntry(path: "Food.json", sha: "1", isFile: true),
            GitHubEntry(path: "notes", sha: "2", isFile: false),
        ])
    }

    // MARK: - Settings

    private final class MemorySecretStore: SecretStore {
        var secrets: [String: String] = [:]

        func secret(for account: String) -> String? { secrets[account] }
        func setSecret(_ secret: String?, for account: String) throws { secrets[account] = secret }
    }

    func testSigningOutKeepsTheRepositoryChoice() throws {
        let store = RepositorySettingsStore(
            defaults: UserDefaults(suiteName: "test.repository.\(UUID().uuidString)")!,
            secrets: MemorySecretStore()
        )
        XCTAssertFalse(store.isReady)

        try store.signIn(token: "token", login: "javier")
        store.settings.repository = "javier/decks"
        XCTAssertTrue(store.isReady)
        XCTAssertEqual(store.settings.accountLogin, "javier")

        store.signOut()
        XCTAssertFalse(store.isReady)
        XCTAssertNil(store.token)
        XCTAssertEqual(store.settings.repository, "javier/decks")
    }

    func testASignInArrivingFromAnotherDeviceIsNoticed() throws {
        let secrets = MemorySecretStore()
        let store = RepositorySettingsStore(
            defaults: UserDefaults(suiteName: "test.repository.\(UUID().uuidString)")!,
            secrets: secrets
        )
        store.settings.repository = "javier/decks"
        XCTAssertFalse(store.isReady)

        // What iCloud Keychain does when another device signs in.
        secrets.secrets["github"] = "token"
        XCTAssertFalse(store.isSignedIn, "the Keychain does not announce it")

        store.refreshSignIn()
        XCTAssertTrue(store.isReady)

        // And when another device signs out.
        secrets.secrets["github"] = nil
        store.refreshSignIn()
        XCTAssertFalse(store.isSignedIn)
    }

    func testOlderRepositorySettingsStillDecode() throws {
        let decoded = try JSONDecoder().decode(
            RepositorySettings.self,
            from: Data(#"{"repository":"javier/decks"}"#.utf8)
        )

        XCTAssertEqual(decoded.repository, "javier/decks")
        XCTAssertFalse(decoded.usesSingleFile)
    }
}
