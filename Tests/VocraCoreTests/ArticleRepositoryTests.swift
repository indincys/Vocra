import XCTest
@testable import VocraCore

final class ArticleRepositoryTests: XCTestCase {
  private let segmenter = ArticleSegmenter()

  private func makeDraft(
    _ text: String = "The client streams the response. The idle timeout never fires. We keep the parse."
  ) -> ArticleDraft {
    segmenter.segment(text)
  }

  func testInsertStoresArticleWithItsSentences() throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let article = try repository.insert(draft: makeDraft(), sourceApp: "Safari", now: Date())

    XCTAssertEqual(article.sentenceCount, 3)
    XCTAssertEqual(article.analyzedCount, 0)

    let sentences = try repository.sentences(articleID: article.id)
    XCTAssertEqual(sentences.map(\.index), [0, 1, 2])
    XCTAssertEqual(sentences.first?.text, "The client streams the response.")
    XCTAssertFalse(sentences.contains { $0.isAnalyzed })
  }

  func testSavedAnalysisIsReturnedOnReloadAndCountsTowardProgress() throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let article = try repository.insert(draft: makeDraft(), sourceApp: nil, now: Date())
    let sentence = try XCTUnwrap(repository.sentences(articleID: article.id).first)

    let document = LearningExplanationDocument(
      schemaVersion: LearningExplanationDocument.currentSchemaVersion,
      mode: .sentence,
      sourceText: sentence.text,
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: SentenceAnalysis(
        headline: LearningHeadline(title: "", subtitle: ""),
        sentence: AnalyzedSentence(text: sentence.text, segments: []),
        structureBreakdown: StructureBreakdown(title: "", items: []),
        relationshipDiagram: RelationshipDiagram(nodes: [], edges: []),
        logicSummary: LogicSummary(title: "", points: [], coreMeaning: "核心意思"),
        translation: TranslationBlock(title: "", text: "客户端会流式返回。"),
        keyVocabulary: []
      ),
      wordExplanation: nil,
      vocabularyCard: nil,
      warnings: []
    )
    let json = try XCTUnwrap(String(data: JSONEncoder().encode(document), encoding: .utf8))
    try repository.saveAnalysis(sentenceID: sentence.id, analysisJSON: json, analyzedAt: Date())

    let reloaded = try XCTUnwrap(repository.sentences(articleID: article.id).first)
    XCTAssertTrue(reloaded.isAnalyzed)
    XCTAssertEqual(reloaded.analysis?.translation.text, "客户端会流式返回。")
    XCTAssertEqual(try repository.article(id: article.id)?.analyzedCount, 1)
  }

  func testRetentionSweepDeletesArticlesUntouchedForTooLong() throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let now = Date()
    let stale = try repository.insert(
      draft: makeDraft(),
      sourceApp: nil,
      now: now.addingTimeInterval(-40 * 24 * 60 * 60)
    )
    let fresh = try repository.insert(draft: makeDraft(), sourceApp: nil, now: now)

    let expiry = try XCTUnwrap(ArticleRetention.default.expiryDate(now: now))
    XCTAssertEqual(try repository.deleteArticles(lastOpenedBefore: expiry), 1)

    XCTAssertNil(try repository.article(id: stale.id))
    XCTAssertNotNil(try repository.article(id: fresh.id))
    // The cascade takes the sentences (and their cached analyses) with the article.
    XCTAssertTrue(try repository.sentences(articleID: stale.id).isEmpty)
  }

  func testOpeningAnArticleResetsItsRetentionClock() throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let now = Date()
    let article = try repository.insert(
      draft: makeDraft(),
      sourceApp: nil,
      now: now.addingTimeInterval(-40 * 24 * 60 * 60)
    )

    try repository.markOpened(articleID: article.id, now: now)

    let expiry = try XCTUnwrap(ArticleRetention.default.expiryDate(now: now))
    XCTAssertEqual(try repository.deleteArticles(lastOpenedBefore: expiry), 0)
    XCTAssertNotNil(try repository.article(id: article.id))
  }

  func testForeverRetentionHasNoExpiry() {
    XCTAssertNil(ArticleRetention.forever.expiryDate(now: Date()))
  }

  func testDeleteRemovesArticleAndSentences() throws {
    let repository = try SQLiteArticleRepository.inMemory()
    let article = try repository.insert(draft: makeDraft(), sourceApp: nil, now: Date())

    try repository.delete(articleID: article.id)

    XCTAssertTrue(try repository.allArticles().isEmpty)
    XCTAssertTrue(try repository.sentences(articleID: article.id).isEmpty)
  }
}
