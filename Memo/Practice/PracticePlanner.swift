//
//  PracticePlanner.swift
//  Memo
//

import Foundation

/// Turns a deck plus settings into the exact list of cards a run will deal.
///
/// Kept apart from ``PracticeSession`` so the selection rules can be tested
/// without a session, and so a new ``PracticeMode`` only has to be handled in
/// one place.
enum PracticePlanner {

    static func cards(for deck: Deck, settings: PracticeSettings) -> [Card] {
        plan(from: deck.orderedCards.filter(\.isComplete), settings: settings)
    }

    /// The deck-free half, so the rules can be exercised directly.
    static func plan(from available: [Card], settings: PracticeSettings) -> [Card] {
        guard !available.isEmpty else { return [] }

        // The card limit counts against the cards a mode draws from, which for
        // bookmarks is fewer than the deck.
        let ordered: [Card]

        switch settings.mode {
        case .random:
            ordered = available.shuffled()

        case .inOrder:
            ordered = available

        case .leastPracticed:
            ordered = byProgress(available)

        case .leastPracticedShuffled:
            // Shuffled first, then ordered by progress: the shuffle decides
            // what happens within a group of equally practiced cards, which is
            // the only place it can without breaking the ordering.
            ordered = byProgress(available.shuffled())

        case .bookmarked:
            let bookmarked = available.filter(\.isBookmarked)

            guard !bookmarked.isEmpty else {
                var fallback = settings
                fallback.mode = settings.resolvedBookmarkFallbackMode
                return plan(from: available, settings: fallback)
            }

            ordered = bookmarked.shuffled()
        }

        return Array(ordered.prefix(settings.cardCount(forDeckSize: ordered.count)))
    }

    /// Least practiced first, preserving the incoming order within each level.
    ///
    /// Sorted by the pair `(progress, position)` rather than by progress alone:
    /// Swift's sort is not stable, so equally practiced cards would otherwise
    /// come out in an arbitrary order — which would make the sorted mode
    /// unpredictable and the shuffled one no different from it.
    private static func byProgress(_ cards: [Card]) -> [Card] {
        cards.enumerated()
            .sorted { lhs, rhs in
                let left = max(0, lhs.element.practiceProgress)
                let right = max(0, rhs.element.practiceProgress)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }
}
