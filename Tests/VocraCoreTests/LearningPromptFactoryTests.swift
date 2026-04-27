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
}
