import XCTest
@testable import Vocra
import VocraCore

@MainActor
final class AppModelTests: XCTestCase {
  func testShortcutPresentsPanelOnlyAfterExplanationCompletes() async throws {
    let panelPresenter = RecordingPanelPresenter()
    let model = try AppModel(
      selectionReader: StubSelectionReader(selection: CapturedTextSelection(text: "inconsistently", sourceApp: "Tests")),
      vocabularyRepository: .inMemory(),
      panelPresenter: panelPresenter,
      explanationProvider: { _ in
        XCTAssertTrue(panelPresenter.contents.isEmpty)
        return "# inconsistently\n\n**Meaning**"
      }
    )

    await model.handleShortcut()

    XCTAssertEqual(panelPresenter.contents.count, 1)
    XCTAssertEqual(panelPresenter.contents.first?.markdown, "# inconsistently\n\n**Meaning**")
    XCTAssertNil(panelPresenter.contents.first?.errorMessage)
  }

  func testShortcutPresentsSingleErrorPanelWhenExplanationFails() async throws {
    let panelPresenter = RecordingPanelPresenter()
    let model = try AppModel(
      selectionReader: StubSelectionReader(selection: CapturedTextSelection(text: "inconsistently", sourceApp: "Tests")),
      vocabularyRepository: .inMemory(),
      panelPresenter: panelPresenter,
      explanationProvider: { _ in throw TestError.explanationFailed }
    )

    await model.handleShortcut()

    XCTAssertEqual(panelPresenter.contents.count, 1)
    XCTAssertEqual(panelPresenter.contents.first?.capturedText?.cleanedText, "inconsistently")
    XCTAssertEqual(panelPresenter.contents.first?.errorMessage, String(describing: TestError.explanationFailed))
  }
}

private struct StubSelectionReader: SelectionReader {
  let selection: CapturedTextSelection

  func readSelection() async throws -> CapturedTextSelection {
    selection
  }
}

@MainActor
private final class RecordingPanelPresenter: ExplanationPanelPresenting {
  private(set) var contents: [ExplanationPanelContent] = []

  func show(
    content: ExplanationPanelContent,
    onSwitchMode: @escaping (ExplanationMode) -> Void,
    onClose: @escaping () -> Void
  ) {
    contents.append(content)
  }

  func close() {}
}

private enum TestError: Error {
  case explanationFailed
}
