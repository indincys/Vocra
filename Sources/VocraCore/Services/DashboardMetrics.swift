import Foundation

/// Aggregate learning stats derived from stored vocabulary cards, powering the
/// Today dashboard (streak, due count, weekly lookups, mastery totals).
public struct DashboardMetrics: Equatable, Sendable {
  public var dueToday: Int
  public var newToday: Int
  public var streak: Int
  public var totalWords: Int
  public var mastered: Int
  /// Lookups (cards created) per day for the trailing seven days, oldest first.
  public var weekLookups: [Int]

  public var weekLookupTotal: Int { weekLookups.reduce(0, +) }

  public init(
    dueToday: Int,
    newToday: Int,
    streak: Int,
    totalWords: Int,
    mastered: Int,
    weekLookups: [Int]
  ) {
    self.dueToday = dueToday
    self.newToday = newToday
    self.streak = streak
    self.totalWords = totalWords
    self.mastered = mastered
    self.weekLookups = weekLookups
  }

  public init(cards: [VocabularyCard], now: Date = Date(), calendar: Calendar = .current) {
    let today = calendar.startOfDay(for: now)

    dueToday = cards.filter { card in
      guard card.status != .mastered, let next = card.nextReviewAt else { return false }
      return next <= now
    }.count

    newToday = cards.filter { card in
      card.reviewCount == 0 && calendar.isDate(card.createdAt, inSameDayAs: now)
    }.count

    totalWords = cards.count
    mastered = cards.filter { $0.status == .mastered }.count

    // Days that saw any learning activity (a lookup or a review).
    var activeDays: Set<Date> = []
    for card in cards {
      activeDays.insert(calendar.startOfDay(for: card.createdAt))
      if let reviewed = card.lastReviewedAt {
        activeDays.insert(calendar.startOfDay(for: reviewed))
      }
    }

    // Count back from today; an inactive *today* doesn't break a live streak.
    var streakCount = 0
    var cursor = today
    if !activeDays.contains(cursor) {
      cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
    }
    while activeDays.contains(cursor) {
      streakCount += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    streak = streakCount

    weekLookups = (0..<7).reversed().map { offset in
      guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
      return cards.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }.count
    }
  }
}
