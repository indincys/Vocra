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

  public init(
    schemaVersion: Int,
    mode: ExplanationMode,
    sourceText: String,
    language: LearningExplanationLanguage,
    sentenceAnalysis: SentenceAnalysis?,
    wordExplanation: WordExplanation?,
    vocabularyCard: StructuredVocabularyCard?,
    warnings: [String]
  ) {
    self.schemaVersion = schemaVersion
    self.mode = mode
    self.sourceText = sourceText
    self.language = language
    self.sentenceAnalysis = sentenceAnalysis
    self.wordExplanation = wordExplanation
    self.vocabularyCard = vocabularyCard
    self.warnings = warnings
  }
}

public struct LearningExplanationLanguage: Codable, Equatable, Sendable {
  public var source: String
  public var explanation: String

  public init(source: String, explanation: String) {
    self.source = source
    self.explanation = explanation
  }
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

  public init(
    headline: LearningHeadline,
    sentence: AnalyzedSentence,
    structureBreakdown: StructureBreakdown,
    relationshipDiagram: RelationshipDiagram,
    logicSummary: LogicSummary,
    translation: TranslationBlock,
    keyVocabulary: [KeyVocabularyItem]
  ) {
    self.headline = headline
    self.sentence = sentence
    self.structureBreakdown = structureBreakdown
    self.relationshipDiagram = relationshipDiagram
    self.logicSummary = logicSummary
    self.translation = translation
    self.keyVocabulary = keyVocabulary
  }
}

public struct LearningHeadline: Codable, Equatable, Sendable {
  public var title: String
  public var subtitle: String

  public init(title: String, subtitle: String) {
    self.title = title
    self.subtitle = subtitle
  }
}

public struct AnalyzedSentence: Codable, Equatable, Sendable {
  public var text: String
  public var segments: [SentenceSegment]

  public init(text: String, segments: [SentenceSegment]) {
    self.text = text
    self.segments = segments
  }
}

public struct SentenceSegment: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var text: String
  public var role: String
  public var labelZh: String
  public var labelEn: String
  public var color: LearningColorToken

  public init(
    id: String,
    text: String,
    role: String,
    labelZh: String,
    labelEn: String,
    color: LearningColorToken
  ) {
    self.id = id
    self.text = text
    self.role = role
    self.labelZh = labelZh
    self.labelEn = labelEn
    self.color = color
  }
}

public struct StructureBreakdown: Codable, Equatable, Sendable {
  public var title: String
  public var items: [StructureItem]

  public init(title: String, items: [StructureItem]) {
    self.title = title
    self.items = items
  }
}

public struct StructureItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var text: String
  public var role: String
  public var labelZh: String
  public var labelEn: String
  public var children: [StructureItem]

  public init(
    id: String,
    text: String,
    role: String,
    labelZh: String,
    labelEn: String,
    children: [StructureItem]
  ) {
    self.id = id
    self.text = text
    self.role = role
    self.labelZh = labelZh
    self.labelEn = labelEn
    self.children = children
  }
}

public struct RelationshipDiagram: Codable, Equatable, Sendable {
  public var nodes: [RelationshipNode]
  public var edges: [RelationshipEdge]

  public init(nodes: [RelationshipNode], edges: [RelationshipEdge]) {
    self.nodes = nodes
    self.edges = edges
  }
}

public struct RelationshipNode: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var title: String
  public var text: String

  public init(id: String, title: String, text: String) {
    self.id = id
    self.title = title
    self.text = text
  }
}

public struct RelationshipEdge: Codable, Equatable, Sendable {
  public var from: String
  public var to: String
  public var labelZh: String
  public var labelEn: String

  public init(from: String, to: String, labelZh: String, labelEn: String) {
    self.from = from
    self.to = to
    self.labelZh = labelZh
    self.labelEn = labelEn
  }
}

public struct LogicSummary: Codable, Equatable, Sendable {
  public var title: String
  public var points: [String]
  public var coreMeaning: String

  public init(title: String, points: [String], coreMeaning: String) {
    self.title = title
    self.points = points
    self.coreMeaning = coreMeaning
  }
}

public struct TranslationBlock: Codable, Equatable, Sendable {
  public var title: String
  public var text: String

  public init(title: String, text: String) {
    self.title = title
    self.text = text
  }
}

public struct KeyVocabularyItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String { term }
  public var term: String
  public var meaning: String
  public var note: String

  public init(term: String, meaning: String, note: String) {
    self.term = term
    self.meaning = meaning
    self.note = note
  }
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

  public init(
    term: String,
    pronunciation: String?,
    partOfSpeech: String,
    coreMeaning: String,
    contextualMeaning: String,
    usageNotes: [String],
    collocations: [String],
    examples: [LearningExample],
    commonMistakes: [String]
  ) {
    self.term = term
    self.pronunciation = pronunciation
    self.partOfSpeech = partOfSpeech
    self.coreMeaning = coreMeaning
    self.contextualMeaning = contextualMeaning
    self.usageNotes = usageNotes
    self.collocations = collocations
    self.examples = examples
    self.commonMistakes = commonMistakes
  }
}

public struct LearningExample: Codable, Equatable, Sendable, Identifiable {
  public var id: String { sentence }
  public var sentence: String
  public var translation: String
  public var note: String?

  public init(sentence: String, translation: String, note: String?) {
    self.sentence = sentence
    self.translation = translation
    self.note = note
  }
}

public struct StructuredVocabularyCard: Codable, Equatable, Sendable {
  public var front: VocabularyCardFront
  public var back: VocabularyCardBack
  public var examples: [VocabularyCardExample]
  public var reviewPrompts: [String]

  public init(
    front: VocabularyCardFront,
    back: VocabularyCardBack,
    examples: [VocabularyCardExample],
    reviewPrompts: [String]
  ) {
    self.front = front
    self.back = back
    self.examples = examples
    self.reviewPrompts = reviewPrompts
  }
}

public struct VocabularyCardFront: Codable, Equatable, Sendable {
  public var text: String
  public var hint: String?

  public init(text: String, hint: String?) {
    self.text = text
    self.hint = hint
  }
}

public struct VocabularyCardBack: Codable, Equatable, Sendable {
  public var coreMeaning: String
  public var memoryNote: String
  public var usage: String

  public init(coreMeaning: String, memoryNote: String, usage: String) {
    self.coreMeaning = coreMeaning
    self.memoryNote = memoryNote
    self.usage = usage
  }
}

public struct VocabularyCardExample: Codable, Equatable, Sendable, Identifiable {
  public var id: String { sentence }
  public var sentence: String
  public var translation: String

  public init(sentence: String, translation: String) {
    self.sentence = sentence
    self.translation = translation
  }
}
