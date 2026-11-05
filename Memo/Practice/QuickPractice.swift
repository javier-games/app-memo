//
//  QuickPractice.swift
//  Memo
//

import Foundation

/// The options for Quick Practice: a short run drawn from several decks at
/// once, started from the deck list.
///
/// Its own set rather than any deck's, since the run belongs to no one deck.
struct QuickPracticeSettings: Codable, Equatable {

    /// The decks cards are drawn from, by id, or `nil` for every deck.
    var deckIDs: [UUID]?

    var isInverted = false

    /// How the run picks its cards from the chosen decks.
    var mode = PracticeMode.random

    /// How many cards a run deals.
    var cardCount = 10

    /// The target progress is shown and recorded against, for every card in
    /// the run, whichever deck it comes from.
    var practiceTarget = 10

    var errorPenalty = PracticeErrorPenalty.none

    static let `default` = QuickPracticeSettings()

    static let cardCountRange = 1...100

    /// The decks a run draws from, out of `library`. Decks chosen once and
    /// since deleted are simply not there.
    func decks(from library: [Deck]) -> [Deck] {
        guard let deckIDs else { return library }

        let chosen = Set(deckIDs)
        return library.filter { chosen.contains($0.uuid) }
    }

    /// The run's options as the practice screen takes them: ``cardCount``
    /// cards picked by ``mode``, with the app-wide choices the run cannot make
    /// for itself passed in.
    func practiceSettings(audioPlayback: AudioPlaybackMode, bookmarkFallback: PracticeMode) -> PracticeSettings {
        var settings = PracticeSettings()
        settings.mode = mode
        settings.isInverted = isInverted
        settings.cardLimit = min(max(cardCount, Self.cardCountRange.lowerBound), Self.cardCountRange.upperBound)
        settings.practiceTarget = practiceTarget
        settings.errorPenalty = errorPenalty
        settings.audioPlayback = audioPlayback
        settings.bookmarkFallbackMode = bookmarkFallback
        return settings
    }
}

// Declared in an extension so the memberwise initialiser survives.
extension QuickPracticeSettings {

    private enum CodingKeys: String, CodingKey {
        case deckIDs, isInverted, mode, cardCount, practiceTarget, errorPenalty
    }

    /// Tolerant for the same reason ``PracticeSettings`` is: an option added
    /// later must not make a saved payload unreadable.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = QuickPracticeSettings()

        self.init(
            deckIDs: try container.decodeIfPresent([UUID].self, forKey: .deckIDs),
            isInverted: try container.decodeIfPresent(Bool.self, forKey: .isInverted) ?? fallback.isInverted,
            mode: (try? container.decode(PracticeMode.self, forKey: .mode)) ?? fallback.mode,
            cardCount: try container.decodeIfPresent(Int.self, forKey: .cardCount) ?? fallback.cardCount,
            practiceTarget: try container.decodeIfPresent(Int.self, forKey: .practiceTarget) ?? fallback.practiceTarget,
            errorPenalty: (try? container.decode(PracticeErrorPenalty.self, forKey: .errorPenalty)) ?? fallback.errorPenalty
        )
    }
}

/// Where a practice run's cards come from.
enum PracticeSource {

    /// One deck, practised by its own options.
    case deck(Deck)

    /// Cards drawn from several decks: Quick Practice.
    case decks([Deck])

    /// The cards a run deals, planned afresh each time it starts.
    func cards(settings: PracticeSettings) -> [Card] {
        switch self {
        case .deck(let deck):
            PracticePlanner.cards(for: deck, settings: settings)
        case .decks(let decks):
            // Capped here as well as by the planner: In Order ignores the card
            // limit for a single deck, where it means "the whole deck", but a
            // quick run always deals its card count.
            Array(
                PracticePlanner.plan(from: decks.flatMap(\.practisableCards), settings: settings)
                    .prefix(max(1, settings.cardLimit ?? .max))
            )
        }
    }
}
