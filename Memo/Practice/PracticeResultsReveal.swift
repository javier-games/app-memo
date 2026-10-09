//
//  PracticeResultsReveal.swift
//  Memo
//
//  The animation that plays when a session ends, and nothing else. The
//  results screen draws whatever this says is showing, so the animation can
//  be retimed, replaced or switched off here without touching the screen:
//  set `isAnimated` to `false` and the results simply appear.
//

import SwiftUI

/// The counts on the results screen, at one moment of the reveal.
struct PracticeResultsTally: Equatable {

    var practiced = 0
    var correct = 0
    var incorrect = 0
    var skipped = 0

    /// Counts one thing that happened in the session. An answer is a card
    /// practised; a skip is not, since the card came back to be answered.
    mutating func count(_ outcome: PracticeSession.Outcome) {
        switch outcome {
        case .correct:
            practiced += 1
            correct += 1
        case .incorrect:
            practiced += 1
            incorrect += 1
        case .skipped:
            skipped += 1
        }
    }

    /// The counts once everything in `log` has been counted.
    static func total(of log: [PracticeSession.Outcome]) -> PracticeResultsTally {
        var tally = PracticeResultsTally()
        log.forEach { tally.count($0) }
        return tally
    }
}

/// Plays the session back: the icon arrives, then the counts climb in the
/// order the answers were given.
@Observable
final class PracticeResultsReveal {

    /// The one switch for the whole effect.
    static let isAnimated = true

    enum Timing {
        /// How long the icon has to itself before the counting starts.
        static let icon: TimeInterval = 0.55

        /// Roughly how long the counting lasts, however long the session was.
        static let counting: TimeInterval = 1.8

        /// The pause between one count and the next. Bounded both ways: a
        /// short session should not crawl, and a long one should still be
        /// seen to count.
        static func step(for count: Int) -> TimeInterval {
            min(0.16, max(0.03, counting / Double(max(1, count))))
        }
    }

    private(set) var showsIcon = false
    private(set) var tally = PracticeResultsTally()

    /// Whether everything is showing. The screen's buttons wait for this.
    private(set) var isFinished = false

    @ObservationIgnored private let log: [PracticeSession.Outcome]
    @ObservationIgnored private var playback: Task<Void, Never>?

    init(log: [PracticeSession.Outcome]) {
        self.log = log
    }

    /// Starts the reveal. Does nothing if it is already running or done.
    func start() {
        guard playback == nil, !isFinished else { return }

        guard Self.isAnimated, !log.isEmpty else {
            finish()
            return
        }

        playback = Task { @MainActor in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showsIcon = true
            }

            try? await Task.sleep(for: .seconds(Timing.icon))

            let step = Timing.step(for: log.count)

            for outcome in log {
                if Task.isCancelled { return }

                withAnimation(.snappy(duration: step)) {
                    tally.count(outcome)
                }

                try? await Task.sleep(for: .seconds(step))
            }

            if Task.isCancelled { return }

            withAnimation(.easeOut(duration: 0.25)) {
                isFinished = true
            }
        }
    }

    /// Jumps to the end: everything showing, the final counts in place.
    func finish() {
        playback?.cancel()
        playback = nil

        withAnimation(.easeOut(duration: 0.2)) {
            showsIcon = true
            tally = .total(of: log)
            isFinished = true
        }
    }
}
