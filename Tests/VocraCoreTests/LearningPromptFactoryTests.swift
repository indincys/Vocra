import XCTest
@testable import VocraCore

final class LearningPromptFactoryTests: XCTestCase {
  func testBuildsPromptWithTextTypePreferencesAndJSONInstruction() throws {
    let template = PromptTemplate(
      kind: .sentenceAnalysisSchema,
      body: "Return JSON for {{type}}: {{text}} from {{sourceApp}} at {{createdAt}}."
    )
    let captured = CapturedText(
      originalText: "Codex works best.",
      cleanedText: "Codex works best.",
      mode: .sentence,
      sourceApp: "Safari"
    )

    let prompt = try LearningPromptFactory().prompt(
      for: captured,
      template: template,
      preferences: LearningPreferences(explanationDepth: .detailed, exampleCount: 3, chineseStyle: .teacherLike, diagramDensity: .full),
      createdAt: "2026-04-27T00:00:00Z"
    )

    XCTAssertTrue(prompt.contains("Return JSON for sentence: Codex works best."))
    XCTAssertTrue(prompt.contains("Safari"))
    XCTAssertTrue(prompt.contains("single JSON object"))
    XCTAssertTrue(prompt.contains("exampleCount: 3"))
    XCTAssertTrue(prompt.contains("diagramDensity: full"))
  }

  func testIncludesSurroundingContextWhenPresentAndOmitsWhenEmpty() throws {
    let template = PromptTemplate(kind: .wordExplanationSchema, body: "Explain {{text}}.")
    let withContext = CapturedText(
      originalText: "resolve",
      cleanedText: "resolve",
      mode: .word,
      sourceApp: "Safari",
      surroundingContext: "They finally resolve the dispute in court."
    )
    let withoutContext = CapturedText(originalText: "resolve", cleanedText: "resolve", mode: .word, sourceApp: "Safari")

    let promptWithContext = try LearningPromptFactory().prompt(for: withContext, template: template)
    let promptWithoutContext = try LearningPromptFactory().prompt(for: withoutContext, template: template)

    XCTAssertTrue(promptWithContext.contains("Surrounding context"))
    XCTAssertTrue(promptWithContext.contains("They finally resolve the dispute in court."))
    XCTAssertFalse(promptWithoutContext.contains("Surrounding context"))
  }
}
