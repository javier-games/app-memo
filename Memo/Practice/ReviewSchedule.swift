//
//  ReviewSchedule.swift
//  Memo
//

import Foundation
import SwiftData

/// A length of time, as the Review Schedule counts it.
struct ReviewDuration: Codable, Equatable, Hashable {

    enum Unit: String, Codable, CaseIterable, Identifiable {
        case day, week, month, year

        var id: String { rawValue }

        var title: String {
            switch self {
            case .day:   String(localized: "Days")
            case .week:  String(localized: "Weeks")
            case .month: String(localized: "Months")
            case .year:  String(localized: "Years")
            }
        }
    }

    var value: Int
    var unit: Unit

    static let valueRange = 1...99

    /// "week", "2 months".
    var description: String {
        switch (unit, value) {
        case (.day, 1):   String(localized: "day")
        case (.week, 1):  String(localized: "week")
        case (.month, 1): String(localized: "month")
        case (.year, 1):  String(localized: "year")
        case (.day, _):   String(localized: "\(value) days")
        case (.week, _):  String(localized: "\(value) weeks")
        case (.month, _): String(localized: "\(value) months")
        case (.year, _):  String(localized: "\(value) years")
        }
    }

    /// `times` of this length after `date`. Always counted from the same
    /// start rather than step by step, so months do not drift on short ones.
    func added(to date: Date, times: Int = 1, calendar: Calendar) -> Date? {
        let count = value * times
        switch unit {
        case .day:   return calendar.date(byAdding: .day, value: count, to: date)
        case .week:  return calendar.date(byAdding: .day, value: count * 7, to: date)
        case .month: return calendar.date(byAdding: .month, value: count, to: date)
        case .year:  return calendar.date(byAdding: .year, value: count, to: date)
        }
    }
}

/// One step of the Review Schedule: every `every`, lower progress by
/// `decrease` (or to zero), for `lasting`.
struct ReviewInterval: Codable, Equatable, Identifiable {

    var id = UUID()
    var every: ReviewDuration
    var decrease: Int = 1

    /// Back to zero instead of lowering by ``decrease``.
    var resetsProgress = false

    var lasting: ReviewDuration

    static let decreaseRange = 1...99

    /// "Every week, −1, for 4 weeks".
    var summary: String {
        let change = resetsProgress ? String(localized: "back to zero") : "−\(decrease)"
        return String(localized: "Every \(every.description), \(change), for \(lasting.description)")
    }

    /// The progress a card is left with after one checkpoint.
    func lowered(_ progress: Int) -> Int {
        resetsProgress ? 0 : max(0, progress - decrease)
    }
}

/// The app-wide Review Schedule: how a learned card's progress fades, so
/// cards not seen for a while come back up in Least Practiced.
///
/// The intervals run one after another from the day a card is learned.
struct ReviewScheduleSettings: Codable, Equatable {

    var intervals: [ReviewInterval]

    static let `default` = ReviewScheduleSettings(intervals: [
        ReviewInterval(every: .init(value: 1, unit: .week), lasting: .init(value: 4, unit: .week)),
        ReviewInterval(every: .init(value: 1, unit: .month), lasting: .init(value: 6, unit: .month)),
        ReviewInterval(every: .init(value: 1, unit: .year), lasting: .init(value: 2, unit: .year)),
    ])

    /// One moment progress may be lowered at, and the period it closes.
    struct Checkpoint: Equatable {
        /// When the period began: the previous checkpoint, or the start of
        /// its interval.
        let start: Date
        let date: Date
        let interval: ReviewInterval
    }

    /// Every checkpoint for a card learned at `learnedAt`, in order. Finite:
    /// the schedule ends with its last interval.
    func checkpoints(from learnedAt: Date, calendar: Calendar = .current) -> [Checkpoint] {
        var result: [Checkpoint] = []
        var intervalStart = learnedAt

        for interval in intervals {
            guard interval.every.value > 0, interval.lasting.value > 0,
                  let intervalEnd = interval.lasting.added(to: intervalStart, calendar: calendar)
            else { continue }

            var previous = intervalStart
            var times = 1

            // Capped so a day-long period over 99 years cannot run away.
            while times <= 10_000,
                  let date = interval.every.added(to: intervalStart, times: times, calendar: calendar),
                  date <= intervalEnd {
                result.append(Checkpoint(start: previous, date: date, interval: interval))
                previous = date
                times += 1
            }

            intervalStart = intervalEnd
        }

        return result
    }

    /// The next checkpoint after `date` for a card learned at `learnedAt`.
    func nextCheckpoint(after date: Date, learnedAt: Date, calendar: Calendar = .current) -> Checkpoint? {
        checkpoints(from: learnedAt, calendar: calendar).first { $0.date > date }
    }
}

/// Applies the Review Schedule to cards.
enum ReviewScheduler {

    /// Lowers `card`'s progress for every checkpoint passed by `now` and not
    /// yet dealt with. A period in which the card was answered is skipped.
    ///
    /// Returns whether the card changed. Writes nothing until a checkpoint
    /// has passed, so running it often costs no sync traffic.
    @discardableResult
    static func update(
        _ card: Card,
        schedule: ReviewScheduleSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard card.isReviewScheduleEnabled, let learnedAt = card.learnedAt else { return false }

        let since = card.reviewCheckedAt ?? learnedAt
        let due = schedule.checkpoints(from: learnedAt, calendar: calendar)
            .filter { $0.date > since && $0.date <= now }

        guard let last = due.last else { return false }

        var progress = card.practiceProgress
        for checkpoint in due {
            if let answered = card.lastAnsweredAt,
               answered >= checkpoint.start, answered < checkpoint.date {
                continue
            }
            progress = checkpoint.interval.lowered(progress)
        }

        if progress != card.practiceProgress { card.practiceProgress = progress }
        card.reviewCheckedAt = last.date
        return true
    }

    /// Starts the schedule the first time a card is fully learned. A card
    /// whose schedule the user has turned off is left off.
    static func noteProgress(of card: Card, target: Int, now: Date = Date()) {
        guard target > 0, card.practiceProgress >= target, card.learnedAt == nil else { return }

        card.learnedAt = now
        card.reviewCheckedAt = now
        card.isReviewScheduleEnabled = true
    }

    /// Starts the schedule again from `now`, as if the card had just been
    /// learned.
    static func restart(_ card: Card, now: Date = Date()) {
        card.learnedAt = now
        card.reviewCheckedAt = now
    }

    /// Turns the schedule on or off for `card`. Turning it on does not catch
    /// up on the time it was off: only checkpoints from now on count.
    static func setEnabled(_ isEnabled: Bool, for card: Card, now: Date = Date()) {
        guard isEnabled != card.isReviewScheduleEnabled else { return }

        card.isReviewScheduleEnabled = isEnabled
        if isEnabled {
            if card.learnedAt == nil { card.learnedAt = now }
            card.reviewCheckedAt = now
        }
    }
}

extension ReviewScheduler {

    /// Brings every card with a Review Schedule up to date. Run when the app
    /// starts and each time it comes back, so Least Practiced sees the cards
    /// that have faded.
    @MainActor
    static func updateAll(in context: ModelContext, schedule: ReviewScheduleSettings, now: Date = Date()) {
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.isReviewScheduleEnabled })
        guard let cards = try? context.fetch(descriptor) else { return }

        var changed = false
        for card in cards where update(card, schedule: schedule, now: now) {
            changed = true
        }

        if changed { try? context.save() }
    }
}
