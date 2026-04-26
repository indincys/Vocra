import XCTest
@testable import VocraCore

final class ReviewSchedulerTests: XCTestCase {
  func testForgotSchedulesTomorrow() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let result = ReviewScheduler().schedule(after: .forgot, now: now)
    XCTAssertEqual(result.status, .learning)
    XCTAssertEqual(result.nextReviewAt, Calendar.current.date(byAdding: .day, value: 1, to: now))
  }

  func testVagueSchedulesThreeDaysLater() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let result = ReviewScheduler().schedule(after: .vague, now: now)
    XCTAssertEqual(result.nextReviewAt, Calendar.current.date(byAdding: .day, value: 3, to: now))
  }

  func testFamiliarSchedulesTenDaysLater() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let result = ReviewScheduler().schedule(after: .familiar, now: now)
    XCTAssertEqual(result.nextReviewAt, Calendar.current.date(byAdding: .day, value: 10, to: now))
  }

  func testMasteredRemovesFromActiveReview() {
    let result = ReviewScheduler().schedule(after: .mastered, now: Date(timeIntervalSince1970: 1_800_000_000))
    XCTAssertEqual(result.status, .mastered)
    XCTAssertNil(result.nextReviewAt)
  }
}
