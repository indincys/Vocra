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

  public func explain(
    captured: CapturedText,
    template: PromptTemplate,
    onPartial: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> LearningExplanationDocument {
    let prompt = try promptFactory.prompt(for: captured, template: template, preferences: preferences)
    let raw = try await aiClient.complete(prompt: prompt, onPartial: onPartial)
    do {
      return try decodeAndValidate(raw, captured: captured, validatesVocabularyCard: false)
    } catch is CancellationError {
      throw CancellationError()
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
    } catch is CancellationError {
      throw CancellationError()
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
    let json = Self.extractJSONObject(from: raw)
    let data = Data(json.utf8)
    var document = try decoder.decode(LearningExplanationDocument.self, from: data)
    // `mode` and `sourceText` are known locally; the model routinely tweaks casing,
    // punctuation, or spacing and would otherwise trigger a full (expensive) repair
    // retry. Overwrite them with the captured values so validation only guards the
    // genuinely model-generated structure.
    document.mode = captured.mode
    document.sourceText = captured.cleanedText
    if validatesVocabularyCard {
      try validator.validateVocabularyCard(document, expectedMode: captured.mode, expectedSourceText: captured.cleanedText)
    } else {
      try validator.validate(document, expectedMode: captured.mode, expectedSourceText: captured.cleanedText)
    }
    return document
  }

  /// Pulls a clean JSON object out of a raw model response. Strips Markdown code
  /// fences and any prose before/after, then returns the substring from the first
  /// `{` to its balanced closing `}` (respecting strings and escapes). Falls back to
  /// the trimmed input when no balanced object is found, so decoding still surfaces a
  /// meaningful error.
  static func extractJSONObject(from raw: String) -> String {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.hasPrefix("```") {
      // Drop the opening fence line (``` or ```json …) and the trailing fence.
      if let firstNewline = text.firstIndex(where: { $0 == "\n" }) {
        text = String(text[text.index(after: firstNewline)...])
      }
      if let fenceRange = text.range(of: "```", options: .backwards) {
        text = String(text[..<fenceRange.lowerBound])
      }
      text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    guard let start = text.firstIndex(of: "{") else { return text }
    var depth = 0
    var inString = false
    var escaped = false
    var index = start
    while index < text.endIndex {
      let character = text[index]
      if inString {
        if escaped {
          escaped = false
        } else if character == "\\" {
          escaped = true
        } else if character == "\"" {
          inString = false
        }
      } else {
        switch character {
        case "\"": inString = true
        case "{": depth += 1
        case "}":
          depth -= 1
          if depth == 0 {
            return String(text[start...index])
          }
        default: break
        }
      }
      index = text.index(after: index)
    }
    return String(text[start...])
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
