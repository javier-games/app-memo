//
//  PracticeSession.swift
//  Memo
//

import Foundation

/// The state of one run through a deck.
///
/// A value type held as view state: a practice run is transient and must never
/// touch the stored deck. It owns the queue, the tally and the notion of being
/// finished — previously all three were implicit, which is why marking a card
/// correct, wrong or skipped did exactly the same thing and why reaching the
/// end left the screen blank.
struct PracticeSession {

    enum Outcome {
        case correct, incorrect, skipped
    }

    /// The working queue. Skipping reorders this; it never removes anything, so
    /// ``totalCount`` is stable for the whole run.
    private(set) var cards: [Card]

    /// Index of the card on screen. Everything before it has been resolved.
    private(set) var currentIndex: Int = 0

    private(set) var correctCount: Int = 0
    private(set) var incorrectCount: Int = 0

    /// How many times the user skipped during this run.
    ///
    /// Counts skip *actions*, not cards: a skipped card comes back, so the same
    /// card can be deferred more than once and will still end up counted as
    /// correct or wrong. ``correctCount`` plus ``incorrectCount`` always equals
    /// ``totalCount`` at the end; this is separate from that.
    private(set) var skippedCount: Int = 0

    init(cards: [Card]) {
        self.cards = cards
    }

    var totalCount: Int { cards.count }

    /// Cards settled one way or the other. Skipping does not settle a card.
    var resolvedCount: Int { correctCount + incorrectCount }

    var remainingCount: Int { totalCount - resolvedCount }

    /// A run ends when every card has been answered, not when the queue is
    /// exhausted — skipped cards are still owed an answer.
    var isFinished: Bool { resolvedCount >= totalCount }

    var currentCard: Card? {
        cards.indices.contains(currentIndex) ? cards[currentIndex] : nil
    }

    /// Fraction of the deck answered, 0...1.
    ///
    /// Driven by cards resolved, so skipping deliberately does not move it: the
    /// card has been deferred, not dealt with. An empty session is complete.
    var progress: Double {
        guard totalCount > 0 else { return 1 }
        return Double(resolvedCount) / Double(totalCount)
    }

    /// Skipping is only meaningful while another unanswered card exists to move
    /// to; with one card left, sending it to the back would just redeal it.
    var canSkip: Bool { !isFinished && remainingCount > 1 }

    /// Records an outcome for the current card.
    mutating func record(_ outcome: Outcome) {
        guard !isFinished else { return }

        switch outcome {
        case .correct:
            correctCount += 1
            currentIndex += 1

        case .incorrect:
            incorrectCount += 1
            currentIndex += 1

        case .skipped:
            guard canSkip else { return }
            skippedCount += 1
            moveCurrentCardToBack()
        }
    }

    /// Sends the current card to the end of the queue, leaving `currentIndex`
    /// put so the next card slides into its place.
    private mutating func moveCurrentCardToBack() {
        guard cards.indices.contains(currentIndex) else { return }
        cards.append(cards.remove(at: currentIndex))
    }

    /// Starts a fresh run over `cards`.
    ///
    /// Takes the new list rather than reshuffling its own: which cards a run
    /// deals, and in what order, is decided by ``PracticePlanner`` from the
    /// current settings, not by the session.
    mutating func restart(with cards: [Card]) {
        self.cards = cards
        currentIndex = 0
        correctCount = 0
        incorrectCount = 0
        skippedCount = 0
    }
}
