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

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case mode
    case sourceText
    case language
    case sentenceAnalysis
    case wordExplanation
    case vocabularyCard
    case warnings
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    mode = try container.decode(ExplanationMode.self, forKey: .mode)
    sourceText = try container.decode(String.self, forKey: .sourceText)
    language = try container.decode(LearningExplanationLanguage.self, forKey: .language)
    sentenceAnalysis = try container.decodeIfPresent(SentenceAnalysis.self, forKey: .sentenceAnalysis)
    wordExplanation = try container.decodeIfPresent(WordExplanation.self, forKey: .wordExplanation)
    vocabularyCard = try container.decodeIfPresent(StructuredVocabularyCard.self, forKey: .vocabularyCard)
    warnings = try container.decodeStringList(forKey: .warnings)
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

  private enum CodingKeys: String, CodingKey {
    case headline
    case sentence
    case structureBreakdown
    case relationshipDiagram
    case logicSummary
    case translation
    case keyVocabulary
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    headline = try container.decode(LearningHeadline.self, forKey: .headline)
    sentence = try container.decode(AnalyzedSentence.self, forKey: .sentence)
    structureBreakdown = try container.decode(StructureBreakdown.self, forKey: .structureBreakdown)
    relationshipDiagram = try container.decode(RelationshipDiagram.self, forKey: .relationshipDiagram)
    logicSummary = try container.decode(LogicSummary.self, forKey: .logicSummary)
    translation = try container.decode(TranslationBlock.self, forKey: .translation)
    keyVocabulary = try container.decodeIfPresent([KeyVocabularyItem].self, forKey: .keyVocabulary) ?? []
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

  private enum CodingKeys: String, CodingKey {
    case text
    case segments
  }

  public init(from decoder: Decoder) throws {
    if let text = try? decoder.singleValueContainer().decode(String.self) {
      self.text = text
      self.segments = []
      return
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    text = try container.decode(String.self, forKey: .text)
    segments = try container.decodeIfPresent([SentenceSegment].self, forKey: .segments) ?? []
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

  private enum CodingKeys: String, CodingKey {
    case id
    case text
    case role
    case labelZh
    case labelEn
    case children
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    text = try container.decode(String.self, forKey: .text)
    role = try container.decode(String.self, forKey: .role)
    labelZh = try container.decode(String.self, forKey: .labelZh)
    labelEn = try container.decode(String.self, forKey: .labelEn)
    children = try container.decodeIfPresent([StructureItem].self, forKey: .children) ?? []
  }
}

public struct RelationshipDiagram: Codable, Equatable, Sendable {
  public var nodes: [RelationshipNode]
  public var edges: [RelationshipEdge]

  public init(nodes: [RelationshipNode], edges: [RelationshipEdge]) {
    self.nodes = nodes
    self.edges = edges
  }

  private enum CodingKeys: String, CodingKey {
    case nodes
    case edges
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    nodes = try container.decodeIfPresent([RelationshipNode].self, forKey: .nodes) ?? []
    edges = try container.decodeIfPresent([RelationshipEdge].self, forKey: .edges) ?? []
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

  private enum CodingKeys: String, CodingKey {
    case from
    case to
    case label
    case labelZh
    case labelEn
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    from = try container.decode(String.self, forKey: .from)
    to = try container.decode(String.self, forKey: .to)
    let sharedLabel = try container.decodeIfPresent(String.self, forKey: .label)?.trimmedNonEmpty
    labelZh = try container.decodeIfPresent(String.self, forKey: .labelZh)?.trimmedNonEmpty ?? sharedLabel ?? "关系"
    labelEn = try container.decodeIfPresent(String.self, forKey: .labelEn)?.trimmedNonEmpty ?? sharedLabel ?? "relationship"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(from, forKey: .from)
    try container.encode(to, forKey: .to)
    try container.encode(labelZh, forKey: .labelZh)
    try container.encode(labelEn, forKey: .labelEn)
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

  private enum CodingKeys: String, CodingKey {
    case title
    case points
    case coreMeaning
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    title = try container.decode(String.self, forKey: .title)
    points = try container.decodeStringList(forKey: .points)
    coreMeaning = try container.decode(String.self, forKey: .coreMeaning)
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

  private enum CodingKeys: String, CodingKey {
    case term
    case pronunciation
    case partOfSpeech
    case coreMeaning
    case contextualMeaning
    case usageNotes
    case collocations
    case examples
    case commonMistakes
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    term = try container.decode(String.self, forKey: .term)
    pronunciation = try container.decodeIfPresent(String.self, forKey: .pronunciation)
    partOfSpeech = try container.decode(String.self, forKey: .partOfSpeech)
    coreMeaning = try container.decode(String.self, forKey: .coreMeaning)
    contextualMeaning = try container.decode(String.self, forKey: .contextualMeaning)
    usageNotes = try container.decodeStringList(forKey: .usageNotes)
    collocations = try container.decodeStringList(forKey: .collocations)
    examples = try container.decodeIfPresent([LearningExample].self, forKey: .examples) ?? []
    commonMistakes = try container.decodeStringList(forKey: .commonMistakes)
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

  private enum CodingKeys: String, CodingKey {
    case front
    case back
    case examples
    case reviewPrompts
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    front = try container.decode(VocabularyCardFront.self, forKey: .front)
    back = try container.decode(VocabularyCardBack.self, forKey: .back)
    examples = try container.decodeIfPresent([VocabularyCardExample].self, forKey: .examples) ?? []
    reviewPrompts = try container.decodeStringList(forKey: .reviewPrompts)
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

private extension KeyedDecodingContainer {
  func decodeStringList(forKey key: Key) throws -> [String] {
    guard contains(key), (try decodeNil(forKey: key)) == false else {
      return []
    }

    do {
      return try decode([String].self, forKey: key)
    } catch {
      if let text = try? decode(String.self, forKey: key) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
      }
      throw error
    }
  }
}

private extension String {
  var trimmedNonEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
