import XCTest
@testable import Vocra
import VocraCore

@MainActor
final class AppModelTests: XCTestCase {
  func testShortcutDoesNotPresentPanelBeforeSelectionReadCompletes() async throws {
    let panelPresenter = RecordingPanelPresenter()
    let selectionReader = BlockingSelectionReader(selection: CapturedTextSelection(text: "inconsistently", sourceApp: "Tests"))
    let explanationGate = AsyncGate()
    let model = try AppModel(
      selectionReader: selectionReader,
      vocabularyRepository: .inMemory(),
      panelPresenter: panelPresenter,
      explanationProvider: { _ in
        await explanationGate.wait()
        return "# inconsistently\n\n**Meaning**"
      }
    )

    let task = Task { await model.handleShortcut() }

    await Task.yield()
    XCTAssertTrue(panelPresenter.contents.isEmpty)

    selectionReader.release()
    let didShowCapturedLoadingPanel = await waitForPanelContents(panelPresenter, count: 1)
    XCTAssertTrue(didShowCapturedLoadingPanel)
    XCTAssertEqual(panelPresenter.contents.first?.capturedText?.cleanedText, "inconsistently")
    XCTAssertEqual(panelPresenter.contents.first?.markdown, "")
    XCTAssertNil(panelPresenter.contents.first?.errorMessage)

    explanationGate.open()
    await task.value
  }

  func testShortcutShowsCapturedLoadingPanelWhileExplanationIsPending() async throws {
    let panelPresenter = RecordingPanelPresenter()
    let explanationGate = AsyncGate()
    let model = try AppModel(
      selectionReader: StubSelectionReader(selection: CapturedTextSelection(text: "inconsistently", sourceApp: "Tests")),
      vocabularyRepository: .inMemory(),
      panelPresenter: panelPresenter,
      explanationProvider: { _ in
        await explanationGate.wait()
        return "# inconsistently\n\n**Meaning**"
      }
    )

    let task = Task { await model.handleShortcut() }

    let didShowCapturedLoadingPanel = await waitForPanelContents(panelPresenter, count: 1)
    XCTAssertTrue(didShowCapturedLoadingPanel)
    guard panelPresenter.contents.count >= 1 else {
      return
    }
    XCTAssertEqual(panelPresenter.contents[0].capturedText?.cleanedText, "inconsistently")
    XCTAssertEqual(panelPresenter.contents[0].markdown, "")
    XCTAssertNil(panelPresenter.contents[0].errorMessage)

    explanationGate.open()
    await task.value

    XCTAssertEqual(panelPresenter.contents.last?.markdown, "# inconsistently\n\n**Meaning**")
    XCTAssertNil(panelPresenter.contents.last?.errorMessage)
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

    XCTAssertEqual(panelPresenter.contents.count, 2)
    XCTAssertEqual(panelPresenter.contents.last?.capturedText?.cleanedText, "inconsistently")
    XCTAssertEqual(panelPresenter.contents.last?.errorMessage, String(describing: TestError.explanationFailed))
  }

  func testStartStoresShortcutRegistrationFailureMessage() throws {
    let shortcutService = StubShortcutService(registrationResult: .failed(.registerHotKey(-9878)))
    let model = try AppModel(
      selectionReader: StubSelectionReader(selection: CapturedTextSelection(text: "inconsistently", sourceApp: "Tests")),
      vocabularyRepository: .inMemory(),
      shortcutService: shortcutService
    )

    model.start()

    XCTAssertEqual(model.shortcutRegistrationErrorMessage, "Could not register global shortcut (status -9878).")
  }
}

private struct StubSelectionReader: SelectionReader {
  let selection: CapturedTextSelection

  func readSelection() async throws -> CapturedTextSelection {
    selection
  }
}

private final class BlockingSelectionReader: SelectionReader, @unchecked Sendable {
  private let gate = AsyncGate()
  private let selection: CapturedTextSelection

  init(selection: CapturedTextSelection) {
    self.selection = selection
  }

  func readSelection() async throws -> CapturedTextSelection {
    await gate.wait()
    return selection
  }

  func release() {
    gate.open()
  }
}

private final class StubShortcutService: ShortcutRegistering {
  private let registrationResult: ShortcutRegistrationResult
  private(set) var registeredShortcut: KeyboardShortcut?
  private(set) var handler: (() -> Void)?

  init(registrationResult: ShortcutRegistrationResult = .registered) {
    self.registrationResult = registrationResult
  }

  func register(shortcut: KeyboardShortcut, handler: @escaping () -> Void) -> ShortcutRegistrationResult {
    registeredShortcut = shortcut
    self.handler = handler
    return registrationResult
  }

  func unregister() {}
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

private final class AsyncGate: @unchecked Sendable {
  private let lock = NSLock()
  private var isOpen = false
  private var continuation: CheckedContinuation<Void, Never>?

  func wait() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if isOpen {
        lock.unlock()
        continuation.resume()
        return
      }

      self.continuation = continuation
      lock.unlock()
    }
  }

  func open() {
    lock.lock()
    isOpen = true
    let continuation = self.continuation
    self.continuation = nil
    lock.unlock()
    continuation?.resume()
  }
}

@MainActor
private func waitForPanelContents(_ presenter: RecordingPanelPresenter, count: Int) async -> Bool {
  for _ in 0..<20 {
    if presenter.contents.count >= count {
      return true
    }
    await Task.yield()
  }
  return false
}
