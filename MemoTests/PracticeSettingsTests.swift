//
//  PracticeSettingsTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class PracticeSettingsTests: XCTestCase {

    private func makeCards(_ count: Int) -> [Card] {
        (0..<count).map { Card(frontText: "F\($0)", backText: "B\($0)") }
    }

    // MARK: - Defaults

    func testDefaults() {
        let settings = PracticeSettings.default

        XCTAssertFalse(settings.isInverted)
        XCTAssertEqual(settings.mode, .all)
        XCTAssertTrue(settings.isShuffled, "the default is the old Random")
        XCTAssertNil(settings.cardLimit, "no limit means the whole deck")
        XCTAssertEqual(settings.cardCount(forDeckSize: 12), 12)
        XCTAssertTrue(settings.practisesWholeDeck(forDeckSize: 12))
    }

    // MARK: - Card limit

    func testCardLimitIsClampedToTheDeck() {
        var settings = PracticeSettings()

        settings.cardLimit = 5
        XCTAssertEqual(settings.cardCount(forDeckSize: 12), 5)

        settings.cardLimit = 50
        XCTAssertEqual(settings.cardCount(forDeckSize: 12), 12, "a stored limit can outlive its deck")

        settings.cardLimit = 0
        XCTAssertEqual(settings.cardCount(forDeckSize: 12), 1)

        settings.cardLimit = -3
        XCTAssertEqual(settings.cardCount(forDeckSize: 12), 1)
    }

    func testEmptyDeckYieldsNoCards() {
        var settings = PracticeSettings()
        settings.cardLimit = 5

        XCTAssertEqual(settings.cardCount(forDeckSize: 0), 0)
    }

    func testEveryModeTakesACardLimit() {
        for mode in PracticeMode.allCases {
            var settings = PracticeSettings()
            settings.mode = mode
            settings.cardLimit = 3

            XCTAssertEqual(settings.cardCount(forDeckSize: 12), 3, "\(mode)")
        }
    }

    func testInOrderTakesTheFirstCardsUpToTheLimit() {
        var settings = PracticeSettings()
        settings.isShuffled = false
        settings.cardLimit = 2

        let dealt = PracticePlanner.plan(from: makeCards(6), settings: settings)

        XCTAssertEqual(dealt.map(\.frontText), ["F0", "F1"])
    }

    // MARK: - Planner

    func testInOrderKeepsDeckOrderAndDealsEverything() {
        var settings = PracticeSettings()
        settings.mode = .all
        settings.isShuffled = false

        let dealt = PracticePlanner.plan(from: makeCards(6), settings: settings)

        XCTAssertEqual(dealt.map(\.frontText), ["F0", "F1", "F2", "F3", "F4", "F5"])
    }

    func testPlannerDealsExactlyTheRequestedAmount() {
        var settings = PracticeSettings()
        settings.cardLimit = 4

        let dealt = PracticePlanner.plan(from: makeCards(6), settings: settings)

        XCTAssertEqual(dealt.count, 4)
        XCTAssertEqual(Set(dealt.map(\.frontText)).count, 4, "no card is dealt twice")
    }

    func testPlannerOnAnEmptyPool() {
        XCTAssertTrue(PracticePlanner.plan(from: [], settings: .default).isEmpty)
    }

    func testRandomModeVariesTheOrder() {
        let pool = makeCards(6)
        var orderings = Set<String>()

        for _ in 0..<40 {
            orderings.insert(
                PracticePlanner.plan(from: pool, settings: .default)
                    .map(\.frontText)
                    .joined(separator: ",")
            )
        }

        XCTAssertGreaterThan(orderings.count, 1)
    }

    // MARK: - Least practiced

    /// Cards F0…Fn with the given progress values.
    private func makeCards(progress: [Int]) -> [Card] {
        progress.enumerated().map { index, value in
            Card(
                frontText: "F\(index)",
                backText: "B\(index)",
                sortIndex: index,
                practiceProgress: value
            )
        }
    }

    private func settings(_ mode: PracticeMode, shuffled: Bool = false, limit: Int? = nil) -> PracticeSettings {
        var settings = PracticeSettings()
        settings.mode = mode
        settings.isShuffled = shuffled
        settings.cardLimit = limit
        return settings
    }

    func testLeastPracticedPutsTheLowestScoresFirst() {
        let pool = makeCards(progress: [5, 0, 3, 1])

        let dealt = PracticePlanner.plan(from: pool, settings: settings(.leastPracticed))

        XCTAssertEqual(dealt.map(\.practiceProgress), [0, 1, 3, 5])
        XCTAssertEqual(dealt.map(\.frontText), ["F1", "F3", "F2", "F0"])
    }

    func testLeastPracticedBreaksTiesByDeckOrder() {
        // Swift's sort is not stable, so this would otherwise be arbitrary.
        let pool = makeCards(progress: [2, 2, 2, 2])

        let dealt = PracticePlanner.plan(from: pool, settings: settings(.leastPracticed))

        XCTAssertEqual(dealt.map(\.frontText), ["F0", "F1", "F2", "F3"])
    }

    func testLeastPracticedIsRepeatable() {
        let pool = makeCards(progress: [4, 0, 4, 1])
        let first = PracticePlanner.plan(from: pool, settings: settings(.leastPracticed))

        for _ in 0..<20 {
            let again = PracticePlanner.plan(from: pool, settings: settings(.leastPracticed))
            XCTAssertEqual(again.map(\.frontText), first.map(\.frontText))
        }
    }

    func testShuffledStillDealsLowestScoresFirst() {
        let pool = makeCards(progress: [9, 0, 9, 0, 5, 5])

        for _ in 0..<40 {
            let dealt = PracticePlanner.plan(
                from: pool, settings: settings(.leastPracticed, shuffled: true)
            )
            XCTAssertEqual(
                dealt.map(\.practiceProgress), [0, 0, 5, 5, 9, 9],
                "shuffling must not let a well-practiced card jump the queue"
            )
        }
    }

    func testShuffledVariesWithinEqualScores() {
        let pool = makeCards(progress: [0, 0, 0, 0, 0, 0])
        var orderings = Set<String>()

        for _ in 0..<40 {
            orderings.insert(
                PracticePlanner.plan(from: pool, settings: settings(.leastPracticed, shuffled: true))
                    .map(\.frontText)
                    .joined(separator: ",")
            )
        }

        XCTAssertGreaterThan(orderings.count, 1, "ties should not come out the same every run")
    }

    func testSortedAndShuffledDifferOnlyWithinTies() {
        // Two cards at each level: the levels are fixed, the pairs are not.
        let pool = makeCards(progress: [1, 1, 2, 2])
        var pairOrderings = Set<String>()

        for _ in 0..<40 {
            let dealt = PracticePlanner.plan(
                from: pool, settings: settings(.leastPracticed, shuffled: true)
            )
            XCTAssertEqual(dealt.map(\.practiceProgress), [1, 1, 2, 2])
            pairOrderings.insert(dealt.map(\.frontText).joined())
        }

        XCTAssertGreaterThan(pairOrderings.count, 1)
    }

    func testTakingOnlyTheLeastPracticedCards() {
        let pool = makeCards(progress: [7, 0, 7, 2, 7])

        let dealt = PracticePlanner.plan(
            from: pool, settings: settings(.leastPracticed, limit: 2)
        )

        XCTAssertEqual(dealt.map(\.practiceProgress), [0, 2], "the two weakest cards")
    }

    func testOnlyLeastPracticedAndReviewOrderByProgress() {
        XCTAssertTrue(PracticeMode.leastPracticed.ordersByProgress)
        XCTAssertTrue(PracticeMode.review.ordersByProgress)
        XCTAssertFalse(PracticeMode.all.ordersByProgress)
        XCTAssertFalse(PracticeMode.bookmarked.ordersByProgress)
    }

    func testWithTrackingOffEveryCardIsEquallyUnpracticed() {
        // Progress stays at zero when the target is zero, so ordering by it is
        // a no-op and the sorted mode simply keeps deck order.
        let pool = makeCards(progress: [0, 0, 0])

        let dealt = PracticePlanner.plan(from: pool, settings: settings(.leastPracticed))

        XCTAssertEqual(dealt.map(\.frontText), ["F0", "F1", "F2"])
    }

    func testNegativeProgressIsTreatedAsZero() {
        let pool = makeCards(progress: [3, -5, 1])

        let dealt = PracticePlanner.plan(from: pool, settings: settings(.leastPracticed))

        XCTAssertEqual(dealt.map(\.frontText), ["F1", "F2", "F0"])
    }

    func testTheNewModesSurviveARoundTrip() throws {
        for mode in PracticeMode.allCases {
            var settings = PracticeSettings()
            settings.mode = mode

            let decoded = try JSONDecoder().decode(
                PracticeSettings.self, from: JSONEncoder().encode(settings)
            )
            XCTAssertEqual(decoded.mode, mode)
        }
    }

    func testEveryModeIsOfferedByThePicker() {
        XCTAssertEqual(PracticeMode.allCases, [.all, .leastPracticed, .bookmarked, .review])
        XCTAssertTrue(PracticeMode.allCases.allSatisfy { !$0.title.isEmpty })
    }

    // MARK: - Inverse

    func testFacesByDefault() {
        let card = Card(frontText: "Tea", backText: "Té",
                        frontHintText: "hot drink", backHintText: "bebida")
        let faces = CardFaces(card: card, inverted: false)

        XCTAssertEqual(faces.promptText, "Té")
        XCTAssertEqual(faces.answerText, "Tea")
        XCTAssertEqual(faces.promptHint, "bebida")
        XCTAssertEqual(faces.answerHint, "hot drink")
    }

    func testInverseSwapsBothTextAndHints() {
        let card = Card(frontText: "Tea", backText: "Té",
                        frontHintText: "hot drink", backHintText: "bebida")
        let faces = CardFaces(card: card, inverted: true)

        XCTAssertEqual(faces.promptText, "Tea")
        XCTAssertEqual(faces.answerText, "Té")
        XCTAssertEqual(faces.promptHint, "hot drink")
        XCTAssertEqual(faces.answerHint, "bebida")
    }

    func testAbsentHintsReportAbsent() {
        let faces = CardFaces(card: Card(frontText: "a", backText: "b"), inverted: true)

        XCTAssertFalse(faces.hasPromptHint)
        XCTAssertFalse(faces.hasAnswerHint)
    }

    // MARK: - Coding

    func testSettingsSurviveARoundTrip() throws {
        var settings = PracticeSettings()
        settings.isInverted = true
        settings.mode = .leastPracticed
        settings.isShuffled = false
        settings.cardLimit = 7

        let decoded = try JSONDecoder().decode(
            PracticeSettings.self,
            from: JSONEncoder().encode(settings)
        )

        XCTAssertEqual(decoded, settings)
    }

    func testAnOlderPayloadGainsNewRulesAtTheirDefaults() throws {
        // Synthesised Codable treats every key as required, so without tolerant
        // decoding, adding a rule would reset everyone's saved options.
        let legacy = Data(#"{"isInverted":true}"#.utf8)

        let decoded = try JSONDecoder().decode(PracticeSettings.self, from: legacy)

        XCTAssertTrue(decoded.isInverted)
        XCTAssertEqual(decoded.mode, .all)
        XCTAssertTrue(decoded.isShuffled)
        XCTAssertNil(decoded.cardLimit)
    }

    func testAnUnrecognisedModeFallsBack() throws {
        // Matters if a build is ever rolled back past a mode it does not know.
        let payload = Data(#"{"mode":"spacedRepetition","isInverted":true}"#.utf8)

        let decoded = try JSONDecoder().decode(PracticeSettings.self, from: payload)

        XCTAssertEqual(decoded.mode, .all)
        XCTAssertTrue(decoded.isInverted)
    }

    func testModesSavedByEarlierVersionsBecomeAModeAndAShuffle() throws {
        let cases: [(String, PracticeMode, Bool)] = [
            ("random", .all, true),
            ("inOrder", .all, false),
            ("leastPracticed", .leastPracticed, false),
            ("leastPracticedShuffled", .leastPracticed, true),
            ("bookmarked", .bookmarked, true),
        ]

        for (raw, mode, shuffled) in cases {
            let decoded = try JSONDecoder().decode(
                PracticeSettings.self, from: Data(#"{"mode":"\#(raw)"}"#.utf8)
            )
            XCTAssertEqual(decoded.mode, mode, raw)
            XCTAssertEqual(decoded.isShuffled, shuffled, raw)
        }
    }

    func testAnEmptyPayloadDecodesToDefaults() throws {
        let decoded = try JSONDecoder().decode(PracticeSettings.self, from: Data("{}".utf8))

        XCTAssertEqual(decoded, .default)
    }

    // MARK: - Store

    private func makeDefaults(function: String = #function) -> UserDefaults {
        let suite = "MemoTests.\(function)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    func testStoreStartsAtDefaults() {
        XCTAssertEqual(PracticeSettingsStore(defaults: makeDefaults()).settings, .default)
    }

    func testStorePersistsAcrossInstances() {
        let defaults = makeDefaults()
        let store = PracticeSettingsStore(defaults: defaults)

        store.settings.mode = .leastPracticed
        store.settings.cardLimit = 4

        let reloaded = PracticeSettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.mode, .leastPracticed)
        XCTAssertEqual(reloaded.settings.cardLimit, 4)
    }

    func testResetIsPersisted() {
        let defaults = makeDefaults()
        let store = PracticeSettingsStore(defaults: defaults)
        store.settings.isInverted = true

        store.reset()

        XCTAssertEqual(store.settings, .default)
        XCTAssertEqual(PracticeSettingsStore(defaults: defaults).settings, .default)
    }

    func testUnreadableSettingsFallBackInsteadOfTrapping() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "PracticeSettings")

        XCTAssertEqual(PracticeSettingsStore(defaults: defaults).settings, .default)
    }
}
