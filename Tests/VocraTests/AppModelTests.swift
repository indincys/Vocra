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
        return testWordDocument(text: "inconsistently", mode: .word)
      },
      vocabularyCardProvider: { captured in
        testVocabularyCardDocument(text: captured.cleanedText, mode: captured.mode)
      }
    )

    let task = Task { await model.handleShortcut() }

    await Task.yield()
    XCTAssertTrue(panelPresenter.contents.isEmpty)

    selectionReader.release()
    let didShowCapturedLoadingPanel = await waitForPanelContents(panelPresenter, count: 1)
    XCTAssertTrue(didShowCapturedLoadingPanel)
    XCTAssertEqual(panelPresenter.contents.first?.capturedText?.cleanedText, "inconsistently")
    XCTAssertNil(panelPresenter.contents.first?.document)
    XCTAssertNil(panelPresenter.contents.first?.errorMessage)
    XCTAssertNil(panelPresenter.contents.first?.validationErrorMessage)

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
        return testWordDocument(text: "inconsistently", mode: .word)
      },
      vocabularyCardProvider: { captured in
        testVocabularyCardDocument(text: captured.cleanedText, mode: captured.mode)
      }
    )

    let task = Task { await model.handleShortcut() }

    let didShowCapturedLoadingPanel = await waitForPanelContents(panelPresenter, count: 1)
    XCTAssertTrue(didShowCapturedLoadingPanel)
    guard panelPresenter.contents.count >= 1 else {
      return
    }
    XCTAssertEqual(panelPresenter.contents[0].capturedText?.cleanedText, "inconsistently")
    XCTAssertNil(panelPresenter.contents[0].document)
    XCTAssertNil(panelPresenter.contents[0].errorMessage)
    XCTAssertNil(panelPresenter.contents[0].validationErrorMessage)

    explanationGate.open()
    await task.value

    XCTAssertEqual(panelPresenter.contents.last?.document?.sourceText, "inconsistently")
    XCTAssertNil(panelPresenter.contents.last?.errorMessage)
    XCTAssertNil(panelPresenter.contents.last?.validationErrorMessage)
  }

  func testLatestShortcutResultWinsWhenExplanationsCompleteOutOfOrder() async throws {
    let panelPresenter = RecordingPanelPresenter()
    let selectionReader = SequencedSelectionReader(selections: [
      CapturedTextSelection(text: "ambitious", sourceApp: "Tests"),
      CapturedTextSelection(text: "bullet", sourceApp: "Tests")
    ])
    let firstExplanationGate = AsyncGate()
    let secondExplanationGate = AsyncGate()
    let model = try AppModel(
      selectionReader: selectionReader,
      vocabularyRepository: .inMemory(),
      panelPresenter: panelPresenter,
      explanationProvider: { captured in
        switch captured.cleanedText {
        case "ambitious":
          await firstExplanationGate.wait()
          return testWordDocument(text: "ambitious", mode: captured.mode)
        case "bullet":
          await secondExplanationGate.wait()
          return testWordDocument(text: "bullet", mode: captured.mode)
        default:
          return testWordDocument(text: captured.cleanedText, mode: captured.mode)
        }
      },
      vocabularyCardProvider: { captured in
        testVocabularyCardDocument(text: captured.cleanedText, mode: captured.mode)
      }
    )

    let firstTask = Task { await model.handleShortcut() }
    let didShowFirstLoadingPanel = await waitForPanelContents(panelPresenter, count: 1)
    XCTAssertTrue(didShowFirstLoadingPanel)
    XCTAssertEqual(panelPresenter.contents.last?.capturedText?.cleanedText, "ambitious")

    let secondTask = Task { await model.handleShortcut() }
    let didShowSecondLoadingPanel = await waitForPanelContents(panelPresenter, count: 2)
    XCTAssertTrue(didShowSecondLoadingPanel)
    XCTAssertEqual(panelPresenter.contents.last?.capturedText?.cleanedText, "bullet")

    secondExplanationGate.open()
    await secondTask.value
    XCTAssertEqual(panelPresenter.contents.last?.capturedText?.cleanedText, "bullet")
    XCTAssertEqual(panelPresenter.contents.last?.document?.sourceText, "bullet")

    firstExplanationGate.open()
    await firstTask.value

    XCTAssertEqual(panelPresenter.contents.last?.capturedText?.cleanedText, "bullet")
    XCTAssertEqual(panelPresenter.contents.last?.document?.sourceText, "bullet")
  }

  func testStaleShortcutDoesNotStoreVocabularyCardAfterNewerRequestStarts() async throws {
    let panelPresenter = RecordingPanelPresenter()
    let repository = try SQLiteVocabularyRepository.inMemory()
    let selectionReader = SequencedSelectionReader(selections: [
      CapturedTextSelection(text: "ambitious", sourceApp: "Tests"),
      CapturedTextSelection(text: "bullet", sourceApp: "Tests")
    ])
    let firstCardGate = AsyncGate()
    var requestedCardTexts: [String] = []
    let model = AppModel(
      selectionReader: selectionReader,
      vocabularyRepository: repository,
      panelPresenter: panelPresenter,
      explanationProvider: { captured in
        testWordDocument(text: captured.cleanedText, mode: captured.mode)
      },
      vocabularyCardProvider: { captured in
        requestedCardTexts.append(captured.cleanedText)
        if captured.cleanedText == "ambitious" {
          await firstCardGate.wait()
        }
        return testVocabularyCardDocument(text: captured.cleanedText, mode: captured.mode)
      }
    )

    let firstTask = Task { await model.handleShortcut() }
    let didRequestFirstCard = await waitForCondition { requestedCardTexts == ["ambitious"] }
    XCTAssertTrue(didRequestFirstCard)

    let secondTask = Task { await model.handleShortcut() }
    await secondTask.value

    firstCardGate.open()
    await firstTask.value

    let cards = try repository.allCards()
    XCTAssertEqual(cards.map(\.text), ["bullet"])
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
    XCTAssertNil(panelPresenter.contents.last?.validationErrorMessage)
  }

  func testShortcutPresentsValidationErrorSeparatelyWhenExplanationValidationFails() async throws {
    let panelPresenter = RecordingPanelPresenter()
    let model = try AppModel(
      selectionReader: StubSelectionReader(selection: CapturedTextSelection(text: "Codex works best.", sourceApp: "Tests")),
      vocabularyRepository: .inMemory(),
      panelPresenter: panelPresenter,
      explanationProvider: { _ in throw LearningExplanationValidationError.missingBranch("sentenceAnalysis") }
    )

    await model.handleShortcut()

    XCTAssertEqual(panelPresenter.contents.count, 2)
    XCTAssertEqual(panelPresenter.contents.last?.capturedText?.cleanedText, "Codex works best.")
    XCTAssertNil(panelPresenter.contents.last?.errorMessage)
    XCTAssertEqual(
      panelPresenter.contents.last?.validationErrorMessage,
      LearningExplanationValidationError.missingBranch("sentenceAnalysis").description
    )
  }

  func testShortcutStoresVocabularyCardsFromDedicatedCardProvider() async throws {
    let panelPresenter = RecordingPanelPresenter()
    let repository = try SQLiteVocabularyRepository.inMemory()
    var capturedForExplanation: CapturedText?
    var capturedForCard: CapturedText?
    let model = AppModel(
      selectionReader: StubSelectionReader(selection: CapturedTextSelection(text: "context window", sourceApp: "Tests")),
      vocabularyRepository: repository,
      panelPresenter: panelPresenter,
      explanationProvider: { captured in
        capturedForExplanation = captured
        return testWordDocument(text: captured.cleanedText, mode: captured.mode)
      },
      vocabularyCardProvider: { captured in
        capturedForCard = captured
        return testVocabularyCardDocument(text: captured.cleanedText, mode: captured.mode)
      }
    )

    await model.handleShortcut()

    XCTAssertEqual(capturedForExplanation?.cleanedText, "context window")
    XCTAssertEqual(capturedForCard?.cleanedText, "context window")
    let card = try XCTUnwrap(repository.allCards().first)
    XCTAssertEqual(card.text, "context window")
    XCTAssertEqual(card.type, .phrase)
    let storedDocument = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(card.cardJSON.utf8))
    XCTAssertNil(storedDocument.wordExplanation)
    XCTAssertNotNil(storedDocument.vocabularyCard)
    XCTAssertEqual(storedDocument.vocabularyCard?.back.coreMeaning, "Card meaning for context window")
    XCTAssertEqual(storedDocument.sourceText, "context window")
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

private actor SequencedSelectionReader: SelectionReader {
  private var selections: [CapturedTextSelection]

  init(selections: [CapturedTextSelection]) {
    self.selections = selections
  }

  func readSelection() async throws -> CapturedTextSelection {
    return selections.removeFirst()
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

private func testSentenceDocument(text: String) -> LearningExplanationDocument {
  LearningExplanationDocument(
    schemaVersion: LearningExplanationDocument.currentSchemaVersion,
    mode: .sentence,
    sourceText: text,
    language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
    sentenceAnalysis: SentenceAnalysis(
      headline: LearningHeadline(title: "Sentence", subtitle: "Analysis"),
      sentence: AnalyzedSentence(
        text: text,
        segments: [
          SentenceSegment(id: "s1", text: text, role: "sentence", labelZh: "句子", labelEn: "Sentence", color: .blue)
        ]
      ),
      structureBreakdown: StructureBreakdown(title: "Structure", items: []),
      relationshipDiagram: RelationshipDiagram(nodes: [], edges: []),
      logicSummary: LogicSummary(title: "Meaning", points: ["Point for \(text)"], coreMeaning: "Meaning for \(text)"),
      translation: TranslationBlock(title: "Translation", text: "Translation for \(text)"),
      keyVocabulary: []
    ),
    wordExplanation: nil,
    vocabularyCard: nil,
    warnings: []
  )
}

private func testWordDocument(text: String, mode: ExplanationMode) -> LearningExplanationDocument {
  LearningExplanationDocument(
    schemaVersion: LearningExplanationDocument.currentSchemaVersion,
    mode: mode,
    sourceText: text,
    language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
    sentenceAnalysis: nil,
    wordExplanation: WordExplanation(
      term: text,
      pronunciation: nil,
      partOfSpeech: mode == .word ? "word" : "phrase",
      coreMeaning: "Explanation meaning for \(text)",
      contextualMeaning: "Contextual meaning for \(text)",
      usageNotes: ["Usage for \(text)"],
      collocations: ["\(text) example"],
      examples: [
        LearningExample(sentence: "Use \(text).", translation: "使用 \(text)。", note: nil)
      ],
      commonMistakes: []
    ),
    vocabularyCard: nil,
    warnings: []
  )
}

private func testVocabularyCardDocument(text: String, mode: ExplanationMode) -> LearningExplanationDocument {
  LearningExplanationDocument(
    schemaVersion: LearningExplanationDocument.currentSchemaVersion,
    mode: mode,
    sourceText: text,
    language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
    sentenceAnalysis: nil,
    wordExplanation: nil,
    vocabularyCard: StructuredVocabularyCard(
      front: VocabularyCardFront(text: text, hint: "Hint for \(text)"),
      back: VocabularyCardBack(
        coreMeaning: "Card meaning for \(text)",
        memoryNote: "Memory note for \(text)",
        usage: "Usage for \(text)"
      ),
      examples: [
        VocabularyCardExample(sentence: "Review \(text).", translation: "复习 \(text)。")
      ],
      reviewPrompts: ["What does \(text) mean?"]
    ),
    warnings: []
  )
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
  await waitForCondition {
    presenter.contents.count >= count
  }
}

@MainActor
private func waitForCondition(_ condition: () -> Bool) async -> Bool {
  for _ in 0..<20 {
    if condition() {
      return true
    }
    await Task.yield()
  }
  return false
}
