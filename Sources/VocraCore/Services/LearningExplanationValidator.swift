import Foundation

public enum LearningExplanationValidationError: Error, Equatable, CustomStringConvertible, Sendable {
  case unsupportedSchemaVersion(Int)
  case modeMismatch(expected: ExplanationMode, actual: ExplanationMode)
  case sourceTextMismatch
  case missingBranch(String)
  case duplicateID(String, String)
  case emptyRequiredField(String)

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
      try requireText(wordExplanation.term, field: "wordExplanation.term")
      try requireText(wordExplanation.coreMeaning, field: "wordExplanation.coreMeaning")
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
  }

  private func validateSentenceAnalysis(_ analysis: SentenceAnalysis) throws {
    try requireText(analysis.headline.title, field: "sentenceAnalysis.headline.title")
    try requireText(analysis.sentence.text, field: "sentenceAnalysis.sentence.text")
    try requireUniqueIDs(analysis.sentence.segments.map(\.id), scope: "sentence.segments")
    try requireUniqueIDs(analysis.relationshipDiagram.nodes.map(\.id), scope: "relationshipDiagram.nodes")
    try validateStructureItems(analysis.structureBreakdown.items, scope: "structureBreakdown.items")
  }

  private func validateStructureItems(_ items: [StructureItem], scope: String) throws {
    try requireUniqueIDs(items.map(\.id), scope: scope)
    for item in items {
      try validateStructureItems(item.children, scope: "\(scope).\(item.id).children")
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

  private func normalize(_ text: String) -> String {
    text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }
}
