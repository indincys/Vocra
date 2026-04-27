import XCTest
import VocraCore
@testable import Vocra

final class SettingsViewTests: XCTestCase {
  func testAPIConnectionStatusUsesExpectedIcons() {
    XCTAssertNil(APIConnectionTestStatus.idle.systemImageName)
    XCTAssertEqual(APIConnectionTestStatus.testing.systemImageName, "arrow.triangle.2.circlepath")
    XCTAssertEqual(APIConnectionTestStatus.succeeded.systemImageName, "checkmark.circle.fill")
    XCTAssertEqual(APIConnectionTestStatus.failed.systemImageName, "xmark.octagon.fill")
  }

  func testSchemaPromptEditorsUseSchemaPromptKinds() {
    XCTAssertEqual(SettingsSchemaPromptEditors.all.map(\.title), [
      "Sentence Analysis Schema",
      "Word and Term Explanation Schema",
      "Vocabulary Card Schema"
    ])
    XCTAssertEqual(SettingsSchemaPromptEditors.all.map(\.kind), [
      PromptKind.sentenceAnalysisSchema,
      .wordExplanationSchema,
      .vocabularyCardSchema
    ])
  }
}
