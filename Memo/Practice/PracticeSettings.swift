//
//  PracticeSettings.swift
//  Memo
//
//  The rules that shape a practice run. Pure values with no SwiftUI and no
//  storage, so every rule here is directly testable and new ones can be added
//  without touching the views.
//

import Foundation

/// The order cards are dealt in.
///
/// Adding a mode means adding a case here and answering the capability
/// questions below; the settings panel builds itself from `allCases`.
enum PracticeMode: String, Codable, CaseIterable, Identifiable {

    /// The deck, shuffled.
    case random

    /// The deck in its authored order, start to finish.
    case inOrder

    /// Lowest practice progress first, ties keeping the deck's order.
    ///
    /// Puts the cards you keep getting wrong — and the ones you have never
    /// seen — in front of the ones you have already learned.
    case leastPracticed

    /// Lowest practice progress first, ties in a different order each run.
    case leastPracticedShuffled

    /// Only the cards the user has bookmarked, shuffled.
    ///
    /// A deck with no bookmarks is practised in
    /// ``PracticeSettings/bookmarkFallbackMode`` instead, so choosing this
    /// mode never leaves a deck with nothing to deal.
    case bookmarked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .random:                 String(localized: "Random")
        case .inOrder:                String(localized: "In Order")
        case .leastPracticed:         String(localized: "Least Practiced")
        case .leastPracticedShuffled: String(localized: "Least Practiced, Shuffled")
        case .bookmarked:             String(localized: "Bookmarked")
        }
    }

    /// Whether a run in this mode may practise a subset of the deck.
    ///
    /// `inOrder` is a run through the whole deck by definition, so a card limit
    /// would be meaningless; the panel disables the control and explains why.
    var allowsCardLimit: Bool {
        switch self {
        case .random, .leastPracticed, .leastPracticedShuffled, .bookmarked: true
        case .inOrder:                                                      false
        }
    }

    /// Whether the run is ordered by how much each card has been practiced.
    ///
    /// Both such modes fall back to their unordered form when the practice
    /// target is zero, since every card then sits at zero progress.
    var ordersByProgress: Bool {
        switch self {
        case .leastPracticed, .leastPracticedShuffled: true
        case .random, .inOrder, .bookmarked:           false
        }
    }

    /// Why the card limit is unavailable, for modes that fix it.
    var cardLimitExplanation: String? {
        switch self {
        case .random, .leastPracticed, .leastPracticedShuffled, .bookmarked:
            nil
        case .inOrder:
            String(localized: "In Order practises the whole deck, so every card is included.")
        }
    }

    /// The modes a deck with no bookmarks can be practised in: every mode
    /// that does not itself need bookmarks.
    static var bookmarkFallbacks: [PracticeMode] {
        allCases.filter { $0 != .bookmarked }
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

    var mode: PracticeMode = .random

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
    var bookmarkFallbackMode: PracticeMode = .random

    /// What a wrong answer does to a card's progress.
    var errorPenalty: PracticeErrorPenalty = .none

    static let `default` = PracticeSettings()

    /// The range the practice target may be set to.
    static let practiceTargetRange = 0...100

    /// How many cards a run over `deckSize` cards will actually deal.
    ///
    /// Clamped rather than trusted: the stored limit may outlive the deck it
    /// was chosen for, and the mode may forbid a limit entirely.
    func cardCount(forDeckSize deckSize: Int) -> Int {
        guard deckSize > 0 else { return 0 }
        guard mode.allowsCardLimit, let cardLimit else { return deckSize }

        return min(max(1, cardLimit), deckSize)
    }

    /// The fallback in force. Never ``PracticeMode/bookmarked`` itself, which
    /// would fall back to itself for ever.
    var resolvedBookmarkFallbackMode: PracticeMode {
        bookmarkFallbackMode == .bookmarked ? .random : bookmarkFallbackMode
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
        case isInverted, mode, cardLimit, practiceTarget, bookmarkFallbackMode, errorPenalty
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

        self.init(
            isInverted: try container.decodeIfPresent(Bool.self, forKey: .isInverted)
                ?? fallback.isInverted,
            mode: (try? container.decode(PracticeMode.self, forKey: .mode))
                ?? fallback.mode,
            practiceTarget: try container.decodeIfPresent(Int.self, forKey: .practiceTarget)
                ?? fallback.practiceTarget,
            cardLimit: try container.decodeIfPresent(Int.self, forKey: .cardLimit),
            bookmarkFallbackMode: (try? container.decode(PracticeMode.self, forKey: .bookmarkFallbackMode))
                ?? fallback.bookmarkFallbackMode,
            errorPenalty: (try? container.decode(PracticeErrorPenalty.self, forKey: .errorPenalty))
                ?? fallback.errorPenalty
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

    init(card: Card, inverted: Bool) {
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
