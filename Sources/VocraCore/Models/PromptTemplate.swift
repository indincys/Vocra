import Foundation

public enum PromptKind: String, CaseIterable, Codable, Equatable, Sendable {
  case sentenceAnalysisSchema
  case wordExplanationSchema
  case vocabularyCardSchema

  @available(*, deprecated, message: "Transitional compatibility for pre-schema prompt storage. Use wordExplanationSchema.")
  case wordExplanation
  @available(*, deprecated, message: "Transitional compatibility for pre-schema prompt storage. Use wordExplanationSchema.")
  case phraseExplanation
  @available(*, deprecated, message: "Transitional compatibility for pre-schema prompt storage. Use sentenceAnalysisSchema.")
  case sentenceExplanation
  @available(*, deprecated, message: "Transitional compatibility for pre-schema prompt storage. Use vocabularyCardSchema.")
  case vocabularyCard

  public static var allCases: [PromptKind] {
    [.sentenceAnalysisSchema, .wordExplanationSchema, .vocabularyCardSchema]
  }
}

extension PromptKind {
  var schemaFallbackKind: PromptKind {
    switch self {
    case .wordExplanation, .phraseExplanation:
      .wordExplanationSchema
    case .sentenceExplanation:
      .sentenceAnalysisSchema
    case .vocabularyCard:
      .vocabularyCardSchema
    case .sentenceAnalysisSchema, .wordExplanationSchema, .vocabularyCardSchema:
      self
    }
  }
}

public struct PromptTemplate: Codable, Equatable, Sendable {
  public let kind: PromptKind
  public var body: String

  public init(kind: PromptKind, body: String) {
    self.kind = kind
    self.body = body
  }
}

public struct PromptContext: Equatable, Sendable {
  public let text: String
  public let type: ExplanationMode
  public let sourceApp: String?
  public let surroundingContext: String
  public let createdAt: String

  public init(text: String, type: ExplanationMode, sourceApp: String?, surroundingContext: String, createdAt: String) {
    self.text = text
    self.type = type
    self.sourceApp = sourceApp
    self.surroundingContext = surroundingContext
    self.createdAt = createdAt
  }
}
