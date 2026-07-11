import Foundation

/// The sections split out of the first-screen sentence request and fetched separately.
public struct SentenceSupplement: Sendable, Equatable {
  public var relationshipDiagram: RelationshipDiagram
  public var keyVocabulary: [KeyVocabularyItem]

  public init(relationshipDiagram: RelationshipDiagram, keyVocabulary: [KeyVocabularyItem]) {
    self.relationshipDiagram = relationshipDiagram
    self.keyVocabulary = keyVocabulary
  }
}

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

  /// Best-effort follow-up request for the parts kept out of the first-screen sentence
  /// analysis (relationship diagram + key vocabulary). No repair retry — if it fails or
  /// decodes empty, the caller simply skips those sections.
  public func sentenceSupplement(captured: CapturedText, template: PromptTemplate) async throws -> SentenceSupplement {
    let prompt = try promptFactory.prompt(for: captured, template: template, preferences: preferences)
    let raw = try await aiClient.complete(prompt: prompt)
    let json = Self.extractJSONObject(from: raw)
    let document = try decoder.decode(LearningExplanationDocument.self, from: Data(json.utf8))
    let analysis = document.sentenceAnalysis
    return SentenceSupplement(
      relationshipDiagram: analysis?.relationshipDiagram ?? RelationshipDiagram(nodes: [], edges: []),
      keyVocabulary: analysis?.keyVocabulary ?? []
    )
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
    // The prompt no longer echoes the sentence; fill it locally so the UI can render and
    // underline segments against the exact selected text.
    if captured.mode == .sentence,
       var analysis = document.sentenceAnalysis,
       analysis.sentence.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      analysis.sentence = AnalyzedSentence(text: captured.cleanedText, segments: analysis.sentence.segments)
      document.sentenceAnalysis = analysis
    }
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
