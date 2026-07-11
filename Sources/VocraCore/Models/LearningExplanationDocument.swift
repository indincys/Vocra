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
    // schemaVersion / mode / sourceText / language are constants or locally-known values.
    // The prompts no longer ask the model to echo them, so default them on decode; the
    // service overwrites mode and sourceText with the captured values afterward.
    schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? LearningExplanationDocument.currentSchemaVersion
    mode = try container.decodeIfPresent(ExplanationMode.self, forKey: .mode) ?? .sentence
    sourceText = try container.decodeIfPresent(String.self, forKey: .sourceText) ?? ""
    language = try container.decodeIfPresent(LearningExplanationLanguage.self, forKey: .language)
      ?? LearningExplanationLanguage(source: "en", explanation: "zh-Hans")
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
    // headline is unused by the UI and the fixed section titles have local fallbacks, so
    // the prompt omits them; relationshipDiagram / keyVocabulary may arrive in a separate
    // supplementary request. Everything here decodes-if-present with an empty default.
    headline = try container.decodeIfPresent(LearningHeadline.self, forKey: .headline)
      ?? LearningHeadline(title: "", subtitle: "")
    sentence = try container.decodeIfPresent(AnalyzedSentence.self, forKey: .sentence)
      ?? AnalyzedSentence(text: "", segments: [])
    structureBreakdown = try container.decodeIfPresent(StructureBreakdown.self, forKey: .structureBreakdown)
      ?? StructureBreakdown(title: "", items: [])
    relationshipDiagram = try container.decodeIfPresent(RelationshipDiagram.self, forKey: .relationshipDiagram)
      ?? RelationshipDiagram(nodes: [], edges: [])
    logicSummary = try container.decodeIfPresent(LogicSummary.self, forKey: .logicSummary)
      ?? LogicSummary(title: "", points: [], coreMeaning: "")
    translation = try container.decodeIfPresent(TranslationBlock.self, forKey: .translation)
      ?? TranslationBlock(title: "", text: "")
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
    // `text` is filled locally from the captured selection, so the prompt omits it.
    text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
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
  /// Sentence-specific grammar note for this exact span (what it modifies /
  /// introduces / connects, and its meaning here). Optional in the JSON.
  public var note: String

  public init(
    id: String,
    text: String,
    role: String,
    labelZh: String,
    labelEn: String,
    color: LearningColorToken,
    note: String = ""
  ) {
    self.id = id
    self.text = text
    self.role = role
    self.labelZh = labelZh
    self.labelEn = labelEn
    self.color = color
    self.note = note
  }

  private enum CodingKeys: String, CodingKey {
    case id, text, role, labelZh, labelEn, color, note
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    text = try container.decode(String.self, forKey: .text)
    // role / labelEn are English-role metadata the UI ignores (it renders labelZh + color),
    // so the prompt omits them.
    role = (try container.decodeIfPresent(String.self, forKey: .role)) ?? ""
    labelZh = try container.decode(String.self, forKey: .labelZh)
    labelEn = (try container.decodeIfPresent(String.self, forKey: .labelEn)) ?? ""
    color = try container.decode(LearningColorToken.self, forKey: .color)
    note = (try container.decodeIfPresent(String.self, forKey: .note)) ?? ""
  }
}

public struct StructureBreakdown: Codable, Equatable, Sendable {
  public var title: String
  /// The stripped-down core sentence (subject + verb + object/complement) with
  /// modifiers and subordinate clauses removed — the "trunk" a reader should
  /// grab first. Optional in the JSON.
  public var trunk: String
  /// Concise Chinese gloss of `trunk`. Optional in the JSON.
  public var trunkZh: String
  public var items: [StructureItem]

  public init(title: String, trunk: String = "", trunkZh: String = "", items: [StructureItem]) {
    self.title = title
    self.trunk = trunk
    self.trunkZh = trunkZh
    self.items = items
  }

  private enum CodingKeys: String, CodingKey {
    case title
    case trunk
    case trunkZh
    case items
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // `title` is a fixed UI label with a local fallback, so the prompt omits it.
    title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? ""
    trunk = (try container.decodeIfPresent(String.self, forKey: .trunk)) ?? ""
    trunkZh = (try container.decodeIfPresent(String.self, forKey: .trunkZh)) ?? ""
    items = try container.decodeIfPresent([StructureItem].self, forKey: .items) ?? []
  }
}

public struct StructureItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var text: String
  public var role: String
  public var labelZh: String
  public var labelEn: String
  /// Sentence-specific Chinese note explaining what job this clause/structure
  /// does in this exact sentence (states / modifies / connects what). Optional.
  public var note: String
  public var children: [StructureItem]

  public init(
    id: String,
    text: String,
    role: String,
    labelZh: String,
    labelEn: String,
    note: String = "",
    children: [StructureItem]
  ) {
    self.id = id
    self.text = text
    self.role = role
    self.labelZh = labelZh
    self.labelEn = labelEn
    self.note = note
    self.children = children
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case text
    case role
    case labelZh
    case labelEn
    case note
    case children
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    text = try container.decode(String.self, forKey: .text)
    // role / labelEn are unused by the UI (renders labelZh), so the prompt omits them.
    role = (try container.decodeIfPresent(String.self, forKey: .role)) ?? ""
    labelZh = try container.decode(String.self, forKey: .labelZh)
    labelEn = (try container.decodeIfPresent(String.self, forKey: .labelEn)) ?? ""
    note = (try container.decodeIfPresent(String.self, forKey: .note)) ?? ""
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
    // `title` is a fixed UI label with a local fallback, so the prompt omits it.
    title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? ""
    points = try container.decodeStringList(forKey: .points)
    coreMeaning = (try container.decodeIfPresent(String.self, forKey: .coreMeaning)) ?? ""
  }
}

public struct TranslationBlock: Codable, Equatable, Sendable {
  public var title: String
  public var text: String

  public init(title: String, text: String) {
    self.title = title
    self.text = text
  }

  private enum CodingKeys: String, CodingKey {
    case title
    case text
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // `title` is a fixed UI label with a local fallback, so the prompt omits it.
    title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? ""
    text = (try container.decodeIfPresent(String.self, forKey: .text)) ?? ""
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
