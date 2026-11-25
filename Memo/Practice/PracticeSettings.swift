//
//  PracticeSettings.swift
//  Memo
//
//  The rules that shape a practice run. Pure values with no SwiftUI and no
//  storage, so every rule here is directly testable and new ones can be added
//  without touching the views.
//

import Foundation

/// Which cards a run deals, and in what order. Whether they are shuffled
/// is a separate switch, ``PracticeSettings/isShuffled``.
///
/// Adding a mode means adding a case here and answering the capability
/// questions below; the settings panels build themselves from `allCases`.
enum PracticeMode: String, CaseIterable, Identifiable {

    /// Every card: in the deck's order, or shuffled.
    case all

    /// Lowest practice progress first. Shuffling only reorders cards with
    /// the same progress.
    ///
    /// Puts the cards you keep getting wrong — and the ones you have never
    /// seen — in front of the ones you have already learned.
    case leastPracticed

    /// Only the cards the user has bookmarked.
    ///
    /// A deck with no bookmarks is practised in
    /// ``PracticeSettings/bookmarkFallbackMode`` instead, so choosing this
    /// mode never leaves a deck with nothing to deal.
    case bookmarked

    /// Only learned cards that have slipped below the practice target since,
    /// mostly through the Review Schedule. Most faded first.
    ///
    /// Falls back like ``bookmarked`` when there are none.
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:            String(localized: "All Cards")
        case .leastPracticed: String(localized: "Least Practiced")
        case .bookmarked:     String(localized: "Bookmarked")
        case .review:         String(localized: "Review")
        }
    }

    /// Whether the run is ordered by how much each card has been practiced.
    var ordersByProgress: Bool {
        switch self {
        case .leastPracticed, .review: true
        case .all, .bookmarked:        false
        }
    }

    /// Whether the mode deals only some cards, and so needs a fallback for a
    /// deck where it would deal none.
    var needsFallback: Bool {
        switch self {
        case .bookmarked, .review:  true
        case .all, .leastPracticed: false
        }
    }

    /// The modes a deck can fall back to: those that always have cards.
    static var fallbacks: [PracticeMode] {
        allCases.filter { !$0.needsFallback }
    }

    /// What a run in this mode deals, for the settings panels.
    func explanation(isShuffled: Bool, fallback: PracticeMode) -> String {
        switch (self, isShuffled) {
        case (.all, false):
            String(localized: "Every card, in order.")
        case (.all, true):
            String(localized: "Every card, shuffled.")
        case (.leastPracticed, false):
            String(localized: "The least practised cards first; cards with the same progress keep their order.")
        case (.leastPracticed, true):
            String(localized: "The least practised cards first; cards with the same progress are shuffled.")
        case (.bookmarked, _):
            String(localized: "Only the cards you have bookmarked. With no bookmarks, \(fallback.title) is used instead.")
        case (.review, _):
            String(localized: "Only learned cards whose progress has dropped since, most faded first — mostly through the Review Schedule. With none, \(fallback.title) is used instead.")
        }
    }
}

extension PracticeMode: Codable {

    /// Reads the modes of earlier versions too: Random and In Order are now
    /// All Cards, and Least Practiced, Shuffled is Least Practiced. Whether
    /// they shuffled is read by ``PracticeSettings`` as ``isShuffled``.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let mode = Self(legacyRawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown practice mode \(raw)"
            ))
        }
        self = mode
    }

    init?(legacyRawValue raw: String) {
        switch raw {
        case "random", "inOrder":       self = .all
        case "leastPracticedShuffled":  self = .leastPracticed
        default:
            guard let mode = Self(rawValue: raw) else { return nil }
            self = mode
        }
    }

    /// Whether a mode saved by an earlier version shuffled, or nil if the
    /// value says nothing about it.
    static func legacyShuffle(_ raw: String) -> Bool? {
        switch raw {
        case "random", "leastPracticedShuffled", "bookmarked": true
        case "inOrder", "leastPracticed":                      false
        default:                                               nil
        }
    }
}

/// What a wrong answer does to a card's progress.
enum PracticeErrorPenalty: String, Codable, CaseIterable, Identifiable {

    /// Nothing: progress only ever goes up.
    case none

    /// One correct answer is taken back.
    case decrease

    /// The card starts again from zero.
    case reset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:     String(localized: "Keep Progress")
        case .decrease: String(localized: "Lose One")
        case .reset:    String(localized: "Back to Zero")
        }
    }

    var systemImage: String {
        switch self {
        case .none:     "equal"
        case .decrease: "minus"
        case .reset:    "arrow.counterclockwise"
        }
    }

    /// The other things a wrong answer could do, for the times one card
    /// deserves different treatment from the deck's usual.
    var alternatives: [PracticeErrorPenalty] {
        Self.allCases.filter { $0 != self }
    }

    var explanation: String {
        switch self {
        case .none:     String(localized: "A wrong answer leaves the card's progress as it is.")
        case .decrease: String(localized: "A wrong answer takes one correct answer back.")
        case .reset:    String(localized: "A wrong answer sends the card back to zero.")
        }
    }
}

/// User-adjustable options for practice.
struct PracticeSettings: Codable, Equatable {

    /// Show the far side of the card as the prompt.
    ///
    /// Normally the back is the prompt and the front is the answer; inverting
    /// swaps the two, hints included.
    var isInverted: Bool = false

    var mode: PracticeMode = .all

    /// Deal the mode's cards in a different order each run. For Least
    /// Practiced and Review, only cards with the same progress are shuffled.
    var isShuffled: Bool = true

    /// Correct answers a card needs before it counts as learned.
    ///
    /// Zero switches progress tracking off entirely. It applies to every card;
    /// what a card carries of its own is its progress, not its target.
    var practiceTarget: Int = 10

    /// How many cards to practise, or `nil` for the whole deck.
    ///
    /// Stored as "no limit" rather than as a number so the setting keeps
    /// meaning across decks of different sizes — a saved limit of 20 would
    /// otherwise silently mean "all" in one deck and "a fifth" in another.
    var cardLimit: Int?

    /// The mode a ``PracticeMode/bookmarked`` run uses for a deck that has no
    /// bookmarks.
    ///
    /// An app-wide choice: a deck's own options never override it. See
    /// ``Deck/resolvedPracticeSettings(bookmarkFallback:)``.
    var bookmarkFallbackMode: PracticeMode = .all

    /// What a wrong answer does to a card's progress.
    var errorPenalty: PracticeErrorPenalty = .none

    /// When card audio plays without being asked. An app-wide choice, read
    /// from the app's own settings rather than from a deck's.
    var audioPlayback: AudioPlaybackMode = .automatic

    static let `default` = PracticeSettings()

    /// The range the practice target may be set to.
    static let practiceTargetRange = 0...100

    /// How many cards a run over `deckSize` cards will actually deal.
    ///
    /// Clamped rather than trusted: the stored limit may outlive the deck it
    /// was chosen for.
    func cardCount(forDeckSize deckSize: Int) -> Int {
        guard deckSize > 0 else { return 0 }
        guard let cardLimit else { return deckSize }

        return min(max(1, cardLimit), deckSize)
    }

    /// The fallback in force for Bookmarked and Review. Never one of those
    /// itself, which could fall back for ever.
    var resolvedBookmarkFallbackMode: PracticeMode {
        bookmarkFallbackMode.needsFallback ? .all : bookmarkFallbackMode
    }

    /// Whether the run covers the whole deck.
    func practisesWholeDeck(forDeckSize deckSize: Int) -> Bool {
        cardCount(forDeckSize: deckSize) == deckSize
    }

    /// The target in force.
    ///
    /// Clamped on read for the same reason the card limit is — a stored value
    /// can predate a change to the accepted range.
    var resolvedPracticeTarget: Int {
        min(
            Self.practiceTargetRange.upperBound,
            max(Self.practiceTargetRange.lowerBound, practiceTarget)
        )
    }

    /// `card`'s standing against the target.
    func progress(for card: Card) -> CardPracticeProgress {
        CardPracticeProgress(
            completed: max(0, card.practiceProgress),
            target: resolvedPracticeTarget
        )
    }
}

// MARK: - Tolerant decoding

// Declared in an extension so the memberwise initialiser survives.
extension PracticeSettings {

    private enum CodingKeys: String, CodingKey {
        case isInverted, mode, isShuffled, cardLimit, practiceTarget, bookmarkFallbackMode, errorPenalty, audioPlayback
    }

    /// Decodes leniently: any rule absent from a stored payload takes its
    /// default, and an unrecognised mode falls back rather than throwing.
    ///
    /// Synthesised `Codable` treats every key as required even when the
    /// property has a default, so without this, adding a rule would make every
    /// previously saved payload undecodable and quietly reset everyone's
    /// options. An unknown mode matters for the same reason in reverse: a build
    /// that has been rolled back should not choke on a newer mode it has never
    /// heard of.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = PracticeSettings()

        // Saved before shuffling was its own switch, the mode said it.
        let rawMode = try? container.decode(String.self, forKey: .mode)
        let isShuffled = try container.decodeIfPresent(Bool.self, forKey: .isShuffled)
            ?? rawMode.flatMap(PracticeMode.legacyShuffle)
            ?? fallback.isShuffled

        self.init(
            isInverted: try container.decodeIfPresent(Bool.self, forKey: .isInverted)
                ?? fallback.isInverted,
            mode: (try? container.decode(PracticeMode.self, forKey: .mode))
                ?? fallback.mode,
            isShuffled: isShuffled,
            practiceTarget: try container.decodeIfPresent(Int.self, forKey: .practiceTarget)
                ?? fallback.practiceTarget,
            cardLimit: try container.decodeIfPresent(Int.self, forKey: .cardLimit),
            bookmarkFallbackMode: (try? container.decode(PracticeMode.self, forKey: .bookmarkFallbackMode))
                ?? fallback.bookmarkFallbackMode,
            errorPenalty: (try? container.decode(PracticeErrorPenalty.self, forKey: .errorPenalty))
                ?? fallback.errorPenalty,
            audioPlayback: (try? container.decode(AudioPlaybackMode.self, forKey: .audioPlayback))
                ?? fallback.audioPlayback
        )
    }
}

/// Which face of a card is the prompt and which is the answer.
///
/// Resolves ``PracticeSettings/isInverted`` once, so no view has to remember
/// which way round the card is.
struct CardFaces: Equatable {

    let promptText: String
    let promptHint: String
    let answerText: String
    let answerHint: String

    /// Where each face's recordings live, the same way round as its text.
    let promptSlot: AudioSlot
    let promptHintSlot: AudioSlot
    let answerSlot: AudioSlot
    let answerHintSlot: AudioSlot

    init(card: Card, inverted: Bool) {
        promptSlot = inverted ? .front : .back
        promptHintSlot = inverted ? .frontHint : .backHint
        answerSlot = inverted ? .back : .front
        answerHintSlot = inverted ? .backHint : .frontHint

        if inverted {
            promptText = card.frontText
            promptHint = card.frontHintText
            answerText = card.backText
            answerHint = card.backHintText
        } else {
            promptText = card.backText
            promptHint = card.backHintText
            answerText = card.frontText
            answerHint = card.frontHintText
        }
    }

    var hasPromptHint: Bool { !promptHint.isEmpty }
    var hasAnswerHint: Bool { !answerHint.isEmpty }
}
