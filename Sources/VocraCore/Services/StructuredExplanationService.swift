import Foundation

public struct StructuredExplanationService: Sendable {
  private let aiClient: any AIClient
  private let promptFactory: LearningPromptFactory
  private let validator: LearningExplanationValidator
  private let decoder: JSONDecoder
  private let preferences: LearningPreferences

  public init(
    aiClient: any AIClient,
    promptFactory: LearningPromptFactory = LearningPromptFactory(),
    validator: LearningExplanationValidator = LearningExplanationValidator(),
    decoder: JSONDecoder = JSONDecoder(),
    preferences: LearningPreferences = .default
  ) {
    self.aiClient = aiClient
    self.promptFactory = promptFactory
    self.validator = validator
    self.decoder = decoder
    self.preferences = preferences
  }

  public func explain(captured: CapturedText, template: PromptTemplate) async throws -> LearningExplanationDocument {
    let prompt = try promptFactory.prompt(for: captured, template: template, preferences: preferences)
    let raw = try await aiClient.complete(prompt: prompt)
    do {
      return try decodeAndValidate(raw, captured: captured, validatesVocabularyCard: false)
    } catch {
      let repairedRaw = try await aiClient.complete(prompt: repairPrompt(originalPrompt: prompt, invalidResponse: raw, error: error))
      return try decodeAndValidate(repairedRaw, captured: captured, validatesVocabularyCard: false)
    }
  }

  public func vocabularyCard(captured: CapturedText, template: PromptTemplate) async throws -> LearningExplanationDocument {
    let prompt = try promptFactory.prompt(for: captured, template: template, preferences: preferences)
    let raw = try await aiClient.complete(prompt: prompt)
    do {
      return try decodeAndValidate(raw, captured: captured, validatesVocabularyCard: true)
    } catch {
      let repairedRaw = try await aiClient.complete(prompt: repairPrompt(originalPrompt: prompt, invalidResponse: raw, error: error))
      return try decodeAndValidate(repairedRaw, captured: captured, validatesVocabularyCard: true)
    }
  }

  private func decodeAndValidate(
    _ raw: String,
    captured: CapturedText,
    validatesVocabularyCard: Bool
  ) throws -> LearningExplanationDocument {
    let data = Data(raw.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    let document = try decoder.decode(LearningExplanationDocument.self, from: data)
    if validatesVocabularyCard {
      try validator.validateVocabularyCard(document, expectedMode: captured.mode, expectedSourceText: captured.cleanedText)
    } else {
      try validator.validate(document, expectedMode: captured.mode, expectedSourceText: captured.cleanedText)
    }
    return document
  }

  private func repairPrompt(originalPrompt: String, invalidResponse: String, error: Error) -> String {
    """
    Repair the JSON response so it satisfies the original contract.

    Validation error:
    \(String(describing: error))

    Original prompt:
    \(originalPrompt)

    Invalid response:
    \(invalidResponse)

    Return only the corrected single JSON object.
    """
  }
}
