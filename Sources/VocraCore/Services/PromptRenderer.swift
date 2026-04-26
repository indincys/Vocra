import Foundation

public enum PromptRenderError: Error, Equatable, Sendable {
  case unknownVariable(String)
  case malformedVariable(String)
}

public struct PromptRenderer: Sendable {
  public init() {}

  public func render(_ template: PromptTemplate, context: PromptContext) throws -> String {
    let variablePattern = #/\{\{([^}]*)\}\}/#
    let supportedVariablePattern = #/^[A-Za-z0-9_]+$/#
    let values: [String: String] = [
      "text": context.text,
      "type": context.type.rawValue,
      "sourceApp": context.sourceApp ?? "Unknown App",
      "surroundingContext": context.surroundingContext,
      "createdAt": context.createdAt
    ]

    let matches = template.body.matches(of: variablePattern)
    var output = ""
    var currentIndex = template.body.startIndex
    for match in matches {
      let literalSegment = template.body[currentIndex..<match.range.lowerBound]
      try validateLiteralSegment(literalSegment)
      output += literalSegment

      let name = String(match.1)
      guard name.wholeMatch(of: supportedVariablePattern) != nil else {
        throw PromptRenderError.malformedVariable(name)
      }
      guard let value = values[name] else {
        throw PromptRenderError.unknownVariable(name)
      }
      output += value
      currentIndex = match.range.upperBound
    }
    let trailingLiteralSegment = template.body[currentIndex...]
    try validateLiteralSegment(trailingLiteralSegment)
    output += trailingLiteralSegment

    return output
  }

  private func validateLiteralSegment(_ segment: Substring) throws {
    if let openingDelimiter = segment.range(of: "{{") {
      throw PromptRenderError.malformedVariable(
        String(segment[openingDelimiter.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }

    if let closingDelimiter = segment.range(of: "}}") {
      throw PromptRenderError.malformedVariable(
        String(segment[..<closingDelimiter.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }
  }
}
