import Foundation

public enum VocabularyType: String, Codable, Equatable, Sendable {
  case word
  case phrase
}

public enum VocabularyStatus: String, Codable, Equatable, Sendable {
  case new
  case learning
  case familiar
  case mastered
}

public enum ReviewRating: String, Codable, Equatable, Sendable {
  case forgot
  case vague
  case familiar
  case mastered
}

public struct VocabularyCard: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var text: String
  public var type: VocabularyType
  public var cardJSON: String
  public var sourceApp: String?
  public var createdAt: Date
  public var updatedAt: Date
  public var lastReviewedAt: Date?
  public var nextReviewAt: Date?
  public var reviewCount: Int
  public var status: VocabularyStatus
  public var familiarityLevel: Int

  public init(
    id: UUID = UUID(),
    text: String,
    type: VocabularyType,
    cardJSON: String,
    sourceApp: String?,
    createdAt: Date,
    updatedAt: Date,
    lastReviewedAt: Date?,
    nextReviewAt: Date?,
    reviewCount: Int,
    status: VocabularyStatus,
    familiarityLevel: Int
  ) {
    self.id = id
    self.text = text
    self.type = type
    self.cardJSON = cardJSON
    self.sourceApp = sourceApp
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.lastReviewedAt = lastReviewedAt
    self.nextReviewAt = nextReviewAt
    self.reviewCount = reviewCount
    self.status = status
    self.familiarityLevel = familiarityLevel
  }
}
