//
//  ReviewScheduleTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class ReviewScheduleTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A card learned on `learnedAt` with a full 10/10.
    private func learnedCard(on learnedAt: Date, progress: Int = 10) -> Card {
        let card = Card(frontText: "Tea", backText: "Té", practiceProgress: progress)
        card.isReviewScheduleEnabled = true
        card.learnedAt = learnedAt
        card.reviewCheckedAt = learnedAt
        return card
    }

    private func update(_ card: Card, at now: Date, schedule: ReviewScheduleSettings = .default) {
        ReviewScheduler.update(card, schedule: schedule, now: now, calendar: calendar)
    }

    // MARK: - Checkpoints

    func testDefaultIntervalsRunOneAfterAnother() {
        let dates = ReviewScheduleSettings.default
            .checkpoints(from: date(2026, 1, 1), calendar: calendar)
            .map(\.date)

        XCTAssertEqual(dates.count, 4 + 6 + 2)
        XCTAssertEqual(Array(dates.prefix(4)), [date(2026, 1, 8), date(2026, 1, 15), date(2026, 1, 22), date(2026, 1, 29)])
        XCTAssertEqual(dates[4], date(2026, 2, 28), "the months start where the weeks end")
        XCTAssertEqual(dates[9], date(2026, 7, 29))
        XCTAssertEqual(Array(dates.suffix(2)), [date(2027, 7, 29), date(2028, 7, 29)])
    }

    func testEveryTwoMonthsForAYearIsSixSteps() {
        let schedule = ReviewScheduleSettings(intervals: [
            ReviewInterval(every: .init(value: 2, unit: .month), lasting: .init(value: 1, unit: .year)),
        ])

        XCTAssertEqual(schedule.checkpoints(from: date(2026, 1, 1), calendar: calendar).count, 6)
    }

    // MARK: - Lowering progress

    func testEachPassedCheckpointLowersByOne() {
        let card = learnedCard(on: date(2026, 1, 1))

        update(card, at: date(2026, 1, 20))

        XCTAssertEqual(card.practiceProgress, 8, "Jan 8 and Jan 15")
        XCTAssertEqual(card.reviewCheckedAt, date(2026, 1, 15))
    }

    func testNothingHappensBeforeTheFirstCheckpoint() {
        let card = learnedCard(on: date(2026, 1, 1))

        update(card, at: date(2026, 1, 7))

        XCTAssertEqual(card.practiceProgress, 10)
        XCTAssertEqual(card.reviewCheckedAt, date(2026, 1, 1))
    }

    func testCheckpointsAreNotAppliedTwice() {
        let card = learnedCard(on: date(2026, 1, 1))

        update(card, at: date(2026, 1, 10))
        update(card, at: date(2026, 1, 12))

        XCTAssertEqual(card.practiceProgress, 9)
    }

    func testAnsweredPeriodIsSkipped() {
        let card = learnedCard(on: date(2026, 1, 1))
        card.lastAnsweredAt = date(2026, 1, 10)

        update(card, at: date(2026, 1, 16))

        XCTAssertEqual(card.practiceProgress, 9, "only Jan 8–15, the week with the answer, is skipped")
    }

    func testCatchesUpAfterALongAbsence() {
        let card = learnedCard(on: date(2026, 1, 1))

        update(card, at: date(2030, 1, 1))

        XCTAssertEqual(card.practiceProgress, 0, "12 steps of one, floored at zero")
        XCTAssertNil(ReviewScheduleSettings.default.nextCheckpoint(after: date(2030, 1, 1), learnedAt: date(2026, 1, 1), calendar: calendar))
    }

    func testBackToZero() {
        let schedule = ReviewScheduleSettings(intervals: [
            ReviewInterval(every: .init(value: 1, unit: .week), resetsProgress: true, lasting: .init(value: 1, unit: .week)),
        ])
        let card = learnedCard(on: date(2026, 1, 1))

        update(card, at: date(2026, 1, 9), schedule: schedule)

        XCTAssertEqual(card.practiceProgress, 0)
    }

    func testDisabledCardIsLeftAlone() {
        let card = learnedCard(on: date(2026, 1, 1))
        card.isReviewScheduleEnabled = false

        update(card, at: date(2026, 3, 1))

        XCTAssertEqual(card.practiceProgress, 10)
    }

    // MARK: - Starting and restarting

    func testReachingTheTargetStartsTheSchedule() {
        let card = Card(frontText: "Tea", backText: "Té", practiceProgress: 9)
        let now = date(2026, 5, 1)

        CardPracticeProgressRecorder.record(.correct, on: card, target: 10, penalty: .none, now: now)

        XCTAssertTrue(card.isReviewScheduleEnabled)
        XCTAssertEqual(card.learnedAt, now)
        XCTAssertEqual(card.lastAnsweredAt, now)
    }

    func testAnsweringShortOfTheTargetOnlyRecordsTheDate() {
        let card = Card(frontText: "Tea", backText: "Té", practiceProgress: 3)
        let now = date(2026, 5, 1)

        CardPracticeProgressRecorder.record(.incorrect, on: card, target: 10, penalty: .none, now: now)

        XCTAssertFalse(card.isReviewScheduleEnabled)
        XCTAssertNil(card.learnedAt)
        XCTAssertEqual(card.lastAnsweredAt, now)
    }

    func testSkippingIsNotAnAnswer() {
        let card = Card(frontText: "Tea", backText: "Té", practiceProgress: 3)

        CardPracticeProgressRecorder.record(.skipped, on: card, target: 10, penalty: .none)

        XCTAssertNil(card.lastAnsweredAt)
    }

    func testRelearningKeepsTheOriginalStartAndARefusal() {
        let card = learnedCard(on: date(2026, 1, 1), progress: 9)
        card.isReviewScheduleEnabled = false

        CardPracticeProgressRecorder.complete(card, target: 10, now: date(2026, 2, 1))

        XCTAssertFalse(card.isReviewScheduleEnabled, "turned off by the user, stays off")
        XCTAssertEqual(card.learnedAt, date(2026, 1, 1))
    }

    func testPendingCheckpointsApplyBeforeAnAnswer() {
        let card = learnedCard(on: date(2026, 1, 1))

        CardPracticeProgressRecorder.record(
            .correct, on: card, target: 10, penalty: .none,
            schedule: .default, now: date(2026, 1, 16)
        )

        // Calendar is the current one inside the recorder; the two weekly
        // steps fall well inside any time zone.
        XCTAssertEqual(card.practiceProgress, 9, "two steps off, then one correct answer")
    }

    func testTurningOnAgainDoesNotCatchUp() {
        let card = learnedCard(on: date(2026, 1, 1))
        card.isReviewScheduleEnabled = false

        ReviewScheduler.setEnabled(true, for: card, now: date(2026, 3, 1))
        update(card, at: date(2026, 3, 2))

        XCTAssertEqual(card.practiceProgress, 10)
    }

    func testRestartCountsFromToday() {
        let card = learnedCard(on: date(2026, 1, 1))

        ReviewScheduler.restart(card, now: date(2026, 6, 1))
        update(card, at: date(2026, 6, 9))

        XCTAssertEqual(card.learnedAt, date(2026, 6, 1))
        XCTAssertEqual(card.practiceProgress, 9)
    }

    // MARK: - Saving

    func testScheduleSurvivesARelaunch() {
        let defaults = UserDefaults(suiteName: "test.review.schedule.\(UUID().uuidString)")!
        var schedule = ReviewScheduleSettings.default
        schedule.intervals.removeLast()

        PracticeSettingsStore(defaults: defaults).reviewSchedule = schedule

        XCTAssertEqual(PracticeSettingsStore(defaults: defaults).reviewSchedule, schedule)
        XCTAssertEqual(PracticeSettingsStore(defaults: UserDefaults(suiteName: "test.review.\(UUID().uuidString)")!).reviewSchedule, .default)
    }
}
