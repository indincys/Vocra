import XCTest
import VocraCore
@testable import Vocra

@MainActor
final class ArticleLibraryModelTests: XCTestCase {
  private let longSelection = """
  The client streams the response. The idle timeout never fires mid-generation. \
  We cache the parse so the next open is instant.
  """

  private func makeModel(
    repository: SQLiteArticleRepository,
    analysisProvider: ArticleLibraryModel.AnalysisProvider? = { text in stubDocument(for: text) }
  ) throws -> (model: ArticleLibraryModel, suiteName: String) {
    let suiteName = "ArticleLibraryModelTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    return (
      ArticleLibraryModel(
        repository: repository,
        settingsStore: UserDefaultsSettingsStore(defaults: defaults),
        analysisProvider: analysisProvider
      ),
      suiteName
    )
  }

  func testCollectSegmentsAndStoresTheSelection() throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let (model, suiteName) = try makeModel(repository: repository)
    defer { UserDefaults().removePersistentDomain(forName: suiteName) }

    let article = try XCTUnwrap(model.collect(text: longSelection, sourceApp: "Safari"))

    XCTAssertEqual(article.sentenceCount, 3)
    XCTAssertEqual(model.articles.map(\.id), [article.id])
    XCTAssertNil(model.errorMessage)
  }

  func testCollectRejectsATooShortSelection() throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let (model, suiteName) = try makeModel(repository: repository)
    defer { UserDefaults().removePersistentDomain(forName: suiteName) }

    XCTAssertNil(model.collect(text: "Too short.", sourceApp: nil))
    XCTAssertTrue(model.articles.isEmpty)
    XCTAssertNotNil(model.errorMessage)
  }

  func testSelectingAnArticleAnalyzesEverySentenceAndPersistsTheResult() async throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let (model, suiteName) = try makeModel(repository: repository)
    defer { UserDefaults().removePersistentDomain(forName: suiteName) }
    let article = try XCTUnwrap(model.collect(text: longSelection, sourceApp: nil))

    model.select(articleID: article.id)
    try await waitUntil { model.pendingSentenceCount == 0 }

    XCTAssertTrue(model.sentences.allSatisfy(\.isAnalyzed))
    XCTAssertEqual(model.selectedArticle?.analyzedCount, 3)
    // Persisted, so reopening the article is a local read rather than another model call.
    XCTAssertTrue(try repository.sentences(articleID: article.id).allSatisfy(\.isAnalyzed))
  }

  func testReopeningAnAnalyzedArticleMakesNoFurtherModelCalls() async throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let counter = CallCounter()
    let (model, suiteName) = try makeModel(
      repository: repository,
      analysisProvider: { text in
        await counter.increment()
        return stubDocument(for: text)
      }
    )
    defer { UserDefaults().removePersistentDomain(forName: suiteName) }
    let article = try XCTUnwrap(model.collect(text: longSelection, sourceApp: nil))

    model.select(articleID: article.id)
    try await waitUntil { model.pendingSentenceCount == 0 }
    let callsAfterFirstPass = await counter.count

    model.select(articleID: nil)
    model.select(articleID: article.id)
    try await waitUntil { model.sentences.count == 3 }

    let callsAfterReopen = await counter.count
    XCTAssertEqual(callsAfterReopen, callsAfterFirstPass)
    XCTAssertTrue(model.sentences.allSatisfy(\.isAnalyzed))
  }

  func testAFailingSentenceIsNotRetriedInALoop() async throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let counter = CallCounter()
    let (model, suiteName) = try makeModel(
      repository: repository,
      analysisProvider: { _ in
        await counter.increment()
        throw StubAnalysisError.unavailable
      }
    )
    defer { UserDefaults().removePersistentDomain(forName: suiteName) }
    let article = try XCTUnwrap(model.collect(text: longSelection, sourceApp: nil))

    model.select(articleID: article.id)
    try await waitUntil { model.hasFailedSentences && !model.isAnalyzing }

    // Each sentence is attempted once and then parked; the queue must not spin.
    let attempts = await counter.count
    XCTAssertEqual(attempts, 3)
    XCTAssertEqual(model.pendingSentenceCount, 3)
    XCTAssertNotNil(model.errorMessage)
  }

  func testSweepRemovesArticlesPastTheRetentionWindow() throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let (model, suiteName) = try makeModel(repository: repository)
    defer { UserDefaults().removePersistentDomain(forName: suiteName) }
    _ = model.collect(text: longSelection, sourceApp: nil)

    model.sweepExpired(now: Date().addingTimeInterval(31 * 24 * 60 * 60))
    model.start()

    XCTAssertTrue(model.articles.isEmpty)
  }

  /// Polls `condition` on the main actor until it holds, so the assertions run against a
  /// settled model rather than a fixed sleep.
  private func waitUntil(
    timeout: TimeInterval = 5,
    _ condition: @MainActor () -> Bool
  ) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
      if Date() > deadline { XCTFail("Timed out waiting for the model to settle.") ; return }
      try await Task.sleep(for: .milliseconds(10))
    }
  }
}

private enum StubAnalysisError: Error {
  case unavailable
}

private actor CallCounter {
  private(set) var count = 0
  func increment() { count += 1 }
}

private func stubDocument(for text: String) -> LearningExplanationDocument {
  LearningExplanationDocument(
    schemaVersion: LearningExplanationDocument.currentSchemaVersion,
    mode: .sentence,
    sourceText: text,
    language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
    sentenceAnalysis: SentenceAnalysis(
      headline: LearningHeadline(title: "", subtitle: ""),
      sentence: AnalyzedSentence(text: text, segments: []),
      structureBreakdown: StructureBreakdown(title: "", items: []),
      relationshipDiagram: RelationshipDiagram(nodes: [], edges: []),
      logicSummary: LogicSummary(title: "", points: [], coreMeaning: "核心"),
      translation: TranslationBlock(title: "", text: "译文"),
      keyVocabulary: []
    ),
    wordExplanation: nil,
    vocabularyCard: nil,
    warnings: []
  )
}
