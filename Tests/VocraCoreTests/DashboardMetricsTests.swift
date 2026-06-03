import XCTest
@testable import VocraCore

final class DashboardMetricsTests: XCTestCase {
  private let calendar = Calendar(identifier: .gregorian)
  private let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed reference instant

  func testEmptyCardsProduceZeroedMetrics() {
    let metrics = DashboardMetrics(cards: [], now: now, calendar: calendar)
    XCTAssertEqual(metrics.dueToday, 0)
    XCTAssertEqual(metrics.newToday, 0)
    XCTAssertEqual(metrics.streak, 0)
    XCTAssertEqual(metrics.totalWords, 0)
    XCTAssertEqual(metrics.mastered, 0)
    XCTAssertEqual(metrics.weekLookups, [0, 0, 0, 0, 0, 0, 0])
  }

  func testCountsTotalsMasteredAndDue() {
    let cards = [
      card(created: now, status: .learning, nextReview: now.addingTimeInterval(-3600)), // due
      card(created: now, status: .mastered, nextReview: now.addingTimeInterval(-3600)), // mastered → not due
      card(created: now, status: .new, nextReview: now.addingTimeInterval(3600)),       // future → not due
    ]
    let metrics = DashboardMetrics(cards: cards, now: now, calendar: calendar)
    XCTAssertEqual(metrics.totalWords, 3)
    XCTAssertEqual(metrics.mastered, 1)
    XCTAssertEqual(metrics.dueToday, 1)
  }

  func testNewTodayCountsOnlyFreshUnreviewedCards() {
    let cards = [
      card(created: now, status: .new, reviewCount: 0),                 // new today
      card(created: now, status: .learning, reviewCount: 2),            // reviewed already
      card(created: day(-1), status: .new, reviewCount: 0),             // yesterday
    ]
    let metrics = DashboardMetrics(cards: cards, now: now, calendar: calendar)
    XCTAssertEqual(metrics.newToday, 1)
  }

  func testStreakCountsConsecutiveActiveDaysEndingToday() {
    let cards = [
      card(created: now, reviewed: now),
      card(created: day(-1), reviewed: day(-1)),
      card(created: day(-2), reviewed: day(-2)),
      card(created: day(-5), reviewed: day(-5)), // gap at -3/-4 stops the streak
    ]
    let metrics = DashboardMetrics(cards: cards, now: now, calendar: calendar)
    XCTAssertEqual(metrics.streak, 3)
  }

  func testStreakSurvivesAnInactiveTodayByCountingFromYesterday() {
    let cards = [
      card(created: day(-1), reviewed: day(-1)),
      card(created: day(-2), reviewed: day(-2)),
    ]
    let metrics = DashboardMetrics(cards: cards, now: now, calendar: calendar)
    XCTAssertEqual(metrics.streak, 2)
  }

  func testWeekLookupsBucketsByCreationDayOldestFirst() {
    let cards = [
      card(created: now),
      card(created: now),
      card(created: day(-6)),
      card(created: day(-10)), // outside the 7-day window
    ]
    let metrics = DashboardMetrics(cards: cards, now: now, calendar: calendar)
    XCTAssertEqual(metrics.weekLookups.count, 7)
    XCTAssertEqual(metrics.weekLookups.first, 1) // six days ago
    XCTAssertEqual(metrics.weekLookups.last, 2)  // today
    XCTAssertEqual(metrics.weekLookupTotal, 3)
  }

  // MARK: Helpers

  private func day(_ offset: Int) -> Date {
    calendar.date(byAdding: .day, value: offset, to: now)!
  }

  private func card(
    created: Date,
    reviewed: Date? = nil,
    status: VocabularyStatus = .new,
    reviewCount: Int = 0,
    nextReview: Date? = nil
  ) -> VocabularyCard {
    VocabularyCard(
      text: "term",
      type: .word,
      cardJSON: "{}",
      sourceApp: nil,
      createdAt: created,
      updatedAt: created,
      lastReviewedAt: reviewed,
      nextReviewAt: nextReview,
      reviewCount: reviewCount,
      status: status,
      familiarityLevel: 0
    )
  }
}
