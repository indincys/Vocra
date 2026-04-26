import UserNotifications
import XCTest
@testable import VocraCore

final class ReviewReminderServiceTests: XCTestCase {
  func testScheduleDailyReminderCreatesRepeatingRequestWithDueCount() async throws {
    let center = FakeReviewNotificationCenter()
    let service = ReviewReminderService(center: center)

    try await service.scheduleDailyReminder(hour: 8, minute: 30, dueCount: 3)

    let request = try XCTUnwrap(center.addedRequest)
    XCTAssertEqual(request.identifier, "vocra.daily-review")
    XCTAssertEqual(request.content.title, "Vocra Review")
    XCTAssertEqual(request.content.body, "You have 3 vocabulary cards due today.")

    let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
    XCTAssertTrue(trigger.repeats)
    XCTAssertEqual(trigger.dateComponents.hour, 8)
    XCTAssertEqual(trigger.dateComponents.minute, 30)
  }

  func testCancelDailyReminderRemovesPendingRequest() {
    let center = FakeReviewNotificationCenter()
    let service = ReviewReminderService(center: center)

    service.cancelDailyReminder()

    XCTAssertEqual(center.canceledIdentifiers, ["vocra.daily-review"])
  }
}

private final class FakeReviewNotificationCenter: ReviewNotificationCenterClient, @unchecked Sendable {
  var authorizationRequested = false
  var addedRequest: UNNotificationRequest?
  var canceledIdentifiers: [String] = []

  func requestAuthorization() async throws -> Bool {
    authorizationRequested = true
    return true
  }

  func add(_ request: UNNotificationRequest) async throws {
    addedRequest = request
  }

  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    canceledIdentifiers = identifiers
  }
}
