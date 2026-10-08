//
//  CardPracticeProgress.swift
//  Memo
//

import Foundation

/// A card's standing against its practice target.
///
/// A resolved snapshot rather than something read off the card directly: the
/// target may come from the card or from the app-wide setting, and "tracking is
/// off" is a real state that several places need to agree on.
struct CardPracticeProgress: Equatable {

    /// Consecutive correct answers so far.
    let completed: Int

    /// Correct answers needed. Zero means progress is not tracked at all.
    let target: Int

    /// Whether this card records progress. A target of zero turns it off.
    var isTracked: Bool { target > 0 }

    var isFulfilled: Bool { isTracked && completed >= target }

    /// 0...1, or zero when untracked so callers need no special case.
    var fraction: Double {
        guard isTracked else { return 0 }
        return min(1, Double(completed) / Double(target))
    }

    /// "3 / 10", or nil when untracked.
    var shortDescription: String? {
        isTracked ? "\(min(completed, target))/\(target)" : nil
    }
}

/// Applies practice outcomes to a card's stored progress.
///
/// Separate from ``PracticeSession``, which owns only the transient run: this
/// writes to the card and therefore to the store.
enum CardPracticeProgressRecorder {

    /// Records an outcome against `card`.
    ///
    /// Correct advances by one, wrong does what `penalty` says, and skipping
    /// changes nothing — a deferred card has not been answered. A target of
    /// zero is left entirely alone, so turning tracking off does not quietly
    /// wipe progress the user may want back.
    static func record(
        _ outcome: PracticeSession.Outcome,
        on card: Card,
        target: Int,
        penalty: PracticeErrorPenalty
    ) {
        guard target > 0 else { return }

        switch outcome {
        case .correct:
            card.practiceProgress = min(card.practiceProgress + 1, target)
        case .incorrect:
            switch penalty {
            case .none:     break
            case .decrease: card.practiceProgress = max(0, card.practiceProgress - 1)
            case .reset:    card.practiceProgress = 0
            }
        case .skipped:
            break
        }
    }
}
