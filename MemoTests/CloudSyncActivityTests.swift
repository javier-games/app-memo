//
//  CloudSyncActivityTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class CloudSyncActivityTests: XCTestCase {

    func testNothingHasHappenedAtFirst() {
        let activity = CloudSyncActivity()

        XCTAssertFalse(activity.isSyncing)
        XCTAssertNil(activity.lastSuccess)
        XCTAssertNil(activity.lastError)
    }

    func testSyncingLastsUntilEveryEventHasFinished() {
        var activity = CloudSyncActivity()
        let upload = UUID(), download = UUID()
        let now = Date()

        activity.started(upload)
        activity.started(download)
        XCTAssertTrue(activity.isSyncing)

        activity.finished(upload, at: now, error: nil)
        XCTAssertTrue(activity.isSyncing)

        activity.finished(download, at: now, error: nil)
        XCTAssertFalse(activity.isSyncing)
        XCTAssertEqual(activity.lastSuccess, now)
    }

    func testAFailureIsKeptUntilTheNextSuccess() {
        var activity = CloudSyncActivity()
        let first = UUID(), second = UUID()

        activity.started(first)
        activity.finished(first, at: Date(), error: "No schema")
        XCTAssertEqual(activity.lastError, "No schema")
        XCTAssertNil(activity.lastSuccess)

        activity.started(second)
        activity.finished(second, at: Date(), error: nil)
        XCTAssertNil(activity.lastError)
        XCTAssertNotNil(activity.lastSuccess)
    }
}
