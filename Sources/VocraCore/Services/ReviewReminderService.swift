import Foundation
import UserNotifications

protocol ReviewNotificationCenterClient: Sendable {
  func requestAuthorization() async throws -> Bool
  func add(_ request: UNNotificationRequest) async throws
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

public struct ReviewReminderService: Sendable {
  private let center: any ReviewNotificationCenterClient
  private let requestIdentifier = "vocra.daily-review"

  public init() {
    self.center = SystemReviewNotificationCenterClient()
  }

  init(center: any ReviewNotificationCenterClient) {
    self.center = center
  }

  public func requestAuthorization() async throws -> Bool {
    try await center.requestAuthorization()
  }

  public func scheduleDailyReminder(hour: Int, minute: Int, dueCount: Int) async throws {
    let content = UNMutableNotificationContent()
    content.title = "Vocra Review"
    content.body = if dueCount > 0 {
      "You have \(dueCount) vocabulary cards due today."
    } else {
      "Open Vocra to review today's vocabulary."
    }
    content.sound = .default

    var date = DateComponents()
    date.hour = hour
    date.minute = minute

    let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
    let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
    try await center.add(request)
  }

  public func cancelDailyReminder() {
    center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
  }
}

private struct SystemReviewNotificationCenterClient: ReviewNotificationCenterClient {
  func requestAuthorization() async throws -> Bool {
    try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
  }

  func add(_ request: UNNotificationRequest) async throws {
    try await UNUserNotificationCenter.current().add(request)
  }

  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
  }
}
