import Foundation

public struct LearningExplanationDocument: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 1

  public var schemaVersion: Int
  public var mode: ExplanationMode
  public var sourceText: String
  public var language: LearningExplanationLanguage
  public var sentenceAnalysis: SentenceAnalysis?
  public var wordExplanation: WordExplanation?
  public var vocabularyCard: StructuredVocabularyCard?
  public var warnings: [String]
}

public struct LearningExplanationLanguage: Codable, Equatable, Sendable {
  public var source: String
  public var explanation: String
}

public enum LearningColorToken: String, Codable, Equatable, Sendable {
  case blue
  case green
  case orange
  case purple
  case pink
  case neutral

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = LearningColorToken(rawValue: rawValue) ?? .neutral
  }
}

public struct SentenceAnalysis: Codable, Equatable, Sendable {
  public var headline: LearningHeadline
  public var sentence: AnalyzedSentence
  public var structureBreakdown: StructureBreakdown
  public var relationshipDiagram: RelationshipDiagram
  public var logicSummary: LogicSummary
  public var translation: TranslationBlock
  public var keyVocabulary: [KeyVocabularyItem]
}

public struct LearningHeadline: Codable, Equatable, Sendable {
  public var title: String
  public var subtitle: String
}

public struct AnalyzedSentence: Codable, Equatable, Sendable {
  public var text: String
  public var segments: [SentenceSegment]
}

public struct SentenceSegment: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var text: String
  public var role: String
  public var labelZh: String
  public var labelEn: String
  public var color: LearningColorToken
}

public struct StructureBreakdown: Codable, Equatable, Sendable {
  public var title: String
  public var items: [StructureItem]
}

public struct StructureItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var text: String
  public var role: String
  public var labelZh: String
  public var labelEn: String
  public var children: [StructureItem]
}

public struct RelationshipDiagram: Codable, Equatable, Sendable {
  public var nodes: [RelationshipNode]
  public var edges: [RelationshipEdge]
}

public struct RelationshipNode: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var title: String
  public var text: String
}

public struct RelationshipEdge: Codable, Equatable, Sendable {
  public var from: String
  public var to: String
  public var labelZh: String
  public var labelEn: String
}

public struct LogicSummary: Codable, Equatable, Sendable {
  public var title: String
  public var points: [String]
  public var coreMeaning: String
}

public struct TranslationBlock: Codable, Equatable, Sendable {
  public var title: String
  public var text: String
}

public struct KeyVocabularyItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String { term }
  public var term: String
  public var meaning: String
  public var note: String
}

public struct WordExplanation: Codable, Equatable, Sendable {
  public var term: String
  public var pronunciation: String?
  public var partOfSpeech: String
  public var coreMeaning: String
  public var contextualMeaning: String
  public var usageNotes: [String]
  public var collocations: [String]
  public var examples: [LearningExample]
  public var commonMistakes: [String]
}

public struct LearningExample: Codable, Equatable, Sendable, Identifiable {
  public var id: String { sentence }
  public var sentence: String
  public var translation: String
  public var note: String?
}

public struct StructuredVocabularyCard: Codable, Equatable, Sendable {
  public var front: VocabularyCardFront
  public var back: VocabularyCardBack
  public var examples: [VocabularyCardExample]
  public var reviewPrompts: [String]
}

public struct VocabularyCardFront: Codable, Equatable, Sendable {
  public var text: String
  public var hint: String?
}

public struct VocabularyCardBack: Codable, Equatable, Sendable {
  public var coreMeaning: String
  public var memoryNote: String
  public var usage: String
}

public struct VocabularyCardExample: Codable, Equatable, Sendable, Identifiable {
  public var id: String { sentence }
  public var sentence: String
  public var translation: String
}
