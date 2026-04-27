import Foundation

public enum LearningExplanationValidationError: Error, Equatable, CustomStringConvertible, Sendable {
  case unsupportedSchemaVersion(Int)
  case modeMismatch(expected: ExplanationMode, actual: ExplanationMode)
  case sourceTextMismatch
  case missingBranch(String)
  case duplicateID(String, String)
  case emptyRequiredField(String)
  case unknownRelationshipNodeReference(field: String, id: String)

  public var description: String {
    switch self {
    case .unsupportedSchemaVersion(let version):
      "Unsupported schema version: \(version)."
    case .modeMismatch(let expected, let actual):
      "Expected mode \(expected.rawValue), got \(actual.rawValue)."
    case .sourceTextMismatch:
      "The response sourceText does not match the selected text."
    case .missingBranch(let branch):
      "Missing required branch: \(branch)."
    case .duplicateID(let scope, let id):
      "Duplicate ID in \(scope): \(id)."
    case .emptyRequiredField(let field):
      "Missing required text in \(field)."
    case .unknownRelationshipNodeReference(let field, let id):
      "Unknown relationship node reference in \(field): \(id)."
    }
  }
}

public struct LearningExplanationValidator: Sendable {
  public init() {}

  public func validate(
    _ document: LearningExplanationDocument,
    expectedMode: ExplanationMode,
    expectedSourceText: String
  ) throws {
    guard document.schemaVersion == LearningExplanationDocument.currentSchemaVersion else {
      throw LearningExplanationValidationError.unsupportedSchemaVersion(document.schemaVersion)
    }
    guard document.mode == expectedMode else {
      throw LearningExplanationValidationError.modeMismatch(expected: expectedMode, actual: document.mode)
    }
    guard normalize(document.sourceText) == normalize(expectedSourceText) else {
      throw LearningExplanationValidationError.sourceTextMismatch
    }

    switch expectedMode {
    case .sentence:
      guard let sentenceAnalysis = document.sentenceAnalysis else {
        throw LearningExplanationValidationError.missingBranch("sentenceAnalysis")
      }
      try validateSentenceAnalysis(sentenceAnalysis)
    case .word, .phrase:
      guard let wordExplanation = document.wordExplanation else {
        throw LearningExplanationValidationError.missingBranch("wordExplanation")
      }
      try validateWordExplanation(wordExplanation)
    }
  }

  public func validateVocabularyCard(
    _ document: LearningExplanationDocument,
    expectedMode: ExplanationMode,
    expectedSourceText: String
  ) throws {
    guard document.schemaVersion == LearningExplanationDocument.currentSchemaVersion else {
      throw LearningExplanationValidationError.unsupportedSchemaVersion(document.schemaVersion)
    }
    guard document.mode == expectedMode else {
      throw LearningExplanationValidationError.modeMismatch(expected: expectedMode, actual: document.mode)
    }
    guard normalize(document.sourceText) == normalize(expectedSourceText) else {
      throw LearningExplanationValidationError.sourceTextMismatch
    }
    guard let vocabularyCard = document.vocabularyCard else {
      throw LearningExplanationValidationError.missingBranch("vocabularyCard")
    }
    try requireText(vocabularyCard.front.text, field: "vocabularyCard.front.text")
    try requireText(vocabularyCard.back.coreMeaning, field: "vocabularyCard.back.coreMeaning")
    try requireText(vocabularyCard.back.memoryNote, field: "vocabularyCard.back.memoryNote")
    try requireText(vocabularyCard.back.usage, field: "vocabularyCard.back.usage")
    for (index, example) in vocabularyCard.examples.enumerated() {
      try requireText(example.sentence, field: "vocabularyCard.examples[\(index)].sentence")
      try requireText(example.translation, field: "vocabularyCard.examples[\(index)].translation")
    }
    try validateTextEntries(vocabularyCard.reviewPrompts, field: "vocabularyCard.reviewPrompts")
  }

  private func validateWordExplanation(_ explanation: WordExplanation) throws {
    try requireText(explanation.term, field: "wordExplanation.term")
    try requireText(explanation.partOfSpeech, field: "wordExplanation.partOfSpeech")
    try requireText(explanation.coreMeaning, field: "wordExplanation.coreMeaning")
    try requireText(explanation.contextualMeaning, field: "wordExplanation.contextualMeaning")
    try validateTextEntries(explanation.usageNotes, field: "wordExplanation.usageNotes")
    try validateTextEntries(explanation.collocations, field: "wordExplanation.collocations")
    for (index, example) in explanation.examples.enumerated() {
      try requireText(example.sentence, field: "wordExplanation.examples[\(index)].sentence")
      try requireText(example.translation, field: "wordExplanation.examples[\(index)].translation")
    }
    try validateTextEntries(explanation.commonMistakes, field: "wordExplanation.commonMistakes")
  }

  private func validateSentenceAnalysis(_ analysis: SentenceAnalysis) throws {
    try requireText(analysis.headline.title, field: "sentenceAnalysis.headline.title")
    try requireText(analysis.sentence.text, field: "sentenceAnalysis.sentence.text")
    try requireText(analysis.structureBreakdown.title, field: "sentenceAnalysis.structureBreakdown.title")
    try requireUniqueIDs(analysis.sentence.segments.map(\.id), scope: "sentence.segments")
    for segment in analysis.sentence.segments {
      try requireText(segment.text, field: "sentenceAnalysis.sentence.segments.\(segment.id).text")
    }
    try requireUniqueIDs(analysis.relationshipDiagram.nodes.map(\.id), scope: "relationshipDiagram.nodes")
    for node in analysis.relationshipDiagram.nodes {
      try requireText(node.title, field: "sentenceAnalysis.relationshipDiagram.nodes.\(node.id).title")
      try requireText(node.text, field: "sentenceAnalysis.relationshipDiagram.nodes.\(node.id).text")
    }
    try validateRelationshipEdges(analysis.relationshipDiagram.edges, nodeIDs: Set(analysis.relationshipDiagram.nodes.map(\.id)))
    var structureItemIDs: Set<String> = []
    try validateStructureItems(analysis.structureBreakdown.items, scope: "structureBreakdown.items", seen: &structureItemIDs)
    try requireText(analysis.logicSummary.title, field: "sentenceAnalysis.logicSummary.title")
    try requireText(analysis.translation.title, field: "sentenceAnalysis.translation.title")
    try requireText(analysis.translation.text, field: "sentenceAnalysis.translation.text")
  }

  private func validateRelationshipEdges(_ edges: [RelationshipEdge], nodeIDs: Set<String>) throws {
    for (index, edge) in edges.enumerated() {
      let baseField = "sentenceAnalysis.relationshipDiagram.edges[\(index)]"
      try requireText(edge.from, field: "\(baseField).from")
      try requireText(edge.to, field: "\(baseField).to")
      try requireText(edge.labelZh, field: "\(baseField).labelZh")
      try requireText(edge.labelEn, field: "\(baseField).labelEn")

      guard nodeIDs.contains(edge.from) else {
        throw LearningExplanationValidationError.unknownRelationshipNodeReference(field: "\(baseField).from", id: edge.from)
      }
      guard nodeIDs.contains(edge.to) else {
        throw LearningExplanationValidationError.unknownRelationshipNodeReference(field: "\(baseField).to", id: edge.to)
      }
    }
  }

  private func validateStructureItems(_ items: [StructureItem], scope: String, seen: inout Set<String>) throws {
    for item in items {
      try requireText(item.id, field: "\(scope).id")
      try requireText(item.text, field: "sentenceAnalysis.\(scope).\(item.id).text")
      if seen.contains(item.id) {
        throw LearningExplanationValidationError.duplicateID(scope, item.id)
      }
      seen.insert(item.id)
      try validateStructureItems(item.children, scope: scope, seen: &seen)
    }
  }

  private func requireUniqueIDs(_ ids: [String], scope: String) throws {
    var seen: Set<String> = []
    for id in ids {
      try requireText(id, field: "\(scope).id")
      if seen.contains(id) {
        throw LearningExplanationValidationError.duplicateID(scope, id)
      }
      seen.insert(id)
    }
  }

  private func requireText(_ text: String, field: String) throws {
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw LearningExplanationValidationError.emptyRequiredField(field)
    }
  }

  private func validateTextEntries(_ entries: [String], field: String) throws {
    for (index, entry) in entries.enumerated() {
      try requireText(entry, field: "\(field)[\(index)]")
    }
  }

  private func normalize(_ text: String) -> String {
    text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }
}
