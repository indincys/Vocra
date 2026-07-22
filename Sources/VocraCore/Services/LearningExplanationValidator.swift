import Foundation

public enum LearningExplanationValidationError: Error, Equatable, CustomStringConvertible, Sendable {
  case unsupportedSchemaVersion(Int)
  case missingBranch(String)
  case duplicateID(String, String)
  case emptyRequiredField(String)

  public var description: String {
    switch self {
    case .unsupportedSchemaVersion(let version):
      "Unsupported schema version: \(version)."
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
    // `mode` and `sourceText` are overwritten with the locally-known values before
    // validation (see StructuredExplanationService), so they are never re-checked here —
    // repair retries are reserved for genuine structural problems.

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
    guard let vocabularyCard = document.vocabularyCard else {
      throw LearningExplanationValidationError.missingBranch("vocabularyCard")
    }
    try requireText(vocabularyCard.front.text, field: "vocabularyCard.front.text")
    try requireOptionalText(vocabularyCard.front.hint, field: "vocabularyCard.front.hint")
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
    try requireOptionalText(explanation.pronunciation, field: "wordExplanation.pronunciation")
    try requireText(explanation.partOfSpeech, field: "wordExplanation.partOfSpeech")
    try requireText(explanation.coreMeaning, field: "wordExplanation.coreMeaning")
    try requireText(explanation.contextualMeaning, field: "wordExplanation.contextualMeaning")
    try validateTextEntries(explanation.usageNotes, field: "wordExplanation.usageNotes")
    try validateTextEntries(explanation.collocations, field: "wordExplanation.collocations")
    for (index, example) in explanation.examples.enumerated() {
      try requireText(example.sentence, field: "wordExplanation.examples[\(index)].sentence")
      try requireText(example.translation, field: "wordExplanation.examples[\(index)].translation")
      try requireOptionalText(example.note, field: "wordExplanation.examples[\(index)].note")
    }
    try validateTextEntries(explanation.commonMistakes, field: "wordExplanation.commonMistakes")
  }

  private func validateSentenceAnalysis(_ analysis: SentenceAnalysis) throws {
    // sentence.text is filled locally from the captured selection and the section titles are
    // fixed UI labels, so neither is model-generated and neither is checked here.
    // keyVocabulary may still be empty while the document is streaming in.
    try requireUniqueIDs(analysis.sentence.segments.map(\.id), scope: "sentence.segments")
    for segment in analysis.sentence.segments {
      try requireText(segment.text, field: "sentenceAnalysis.sentence.segments.\(segment.id).text")
      try requireText(segment.labelZh, field: "sentenceAnalysis.sentence.segments.\(segment.id).labelZh")
    }
    for (index, item) in analysis.keyVocabulary.enumerated() {
      try requireText(item.term, field: "sentenceAnalysis.keyVocabulary[\(index)].term")
      try requireText(item.meaning, field: "sentenceAnalysis.keyVocabulary[\(index)].meaning")
    }
    try requireText(analysis.translation.text, field: "sentenceAnalysis.translation.text")
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

  private func requireOptionalText(_ text: String?, field: String) throws {
    guard let text else {
      return
    }
    try requireText(text, field: field)
  }

  private func validateTextEntries(_ entries: [String], field: String) throws {
    for (index, entry) in entries.enumerated() {
      try requireText(entry, field: "\(field)[\(index)]")
    }
  }
}
