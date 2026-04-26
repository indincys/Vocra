import Foundation

public struct ReviewScheduleResult: Equatable, Sendable {
  public let status: VocabularyStatus
  public let familiarityLevel: Int
  public let nextReviewAt: Date?
}

public struct ReviewScheduler: Sendable {
  public init() {}

  public func schedule(after rating: ReviewRating, now: Date) -> ReviewScheduleResult {
    switch rating {
    case .forgot:
      ReviewScheduleResult(status: .learning, familiarityLevel: 0, nextReviewAt: Calendar.current.date(byAdding: .day, value: 1, to: now))
    case .vague:
      ReviewScheduleResult(status: .learning, familiarityLevel: 1, nextReviewAt: Calendar.current.date(byAdding: .day, value: 3, to: now))
    case .familiar:
      ReviewScheduleResult(status: .familiar, familiarityLevel: 2, nextReviewAt: Calendar.current.date(byAdding: .day, value: 10, to: now))
    case .mastered:
      ReviewScheduleResult(status: .mastered, familiarityLevel: 3, nextReviewAt: nil)
    }
  }
}
