import Foundation

/// A long-form selection (paragraph or article) collected for line-by-line study.
///
/// Articles are deliberately a separate domain from `VocabularyCard`: they are reading
/// material with a retention window, not spaced-repetition items.
public struct Article: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var title: String
  public var sourceText: String
  public var sourceApp: String?
  public var createdAt: Date
  /// Bumped whenever the article is opened in the reader; retention is measured from here so
  /// material you keep coming back to isn't swept away.
  public var lastOpenedAt: Date
  public var sentenceCount: Int
  public var analyzedCount: Int

  public init(
    id: UUID = UUID(),
    title: String,
    sourceText: String,
    sourceApp: String?,
    createdAt: Date,
    lastOpenedAt: Date,
    sentenceCount: Int = 0,
    analyzedCount: Int = 0
  ) {
    self.id = id
    self.title = title
    self.sourceText = sourceText
    self.sourceApp = sourceApp
    self.createdAt = createdAt
    self.lastOpenedAt = lastOpenedAt
    self.sentenceCount = sentenceCount
    self.analyzedCount = analyzedCount
  }

  public var isFullyAnalyzed: Bool {
    sentenceCount > 0 && analyzedCount >= sentenceCount
  }

  public var wordCount: Int {
    sourceText.split(whereSeparator: { $0.isWhitespace }).count
  }
}

/// One sentence of an article, plus the cached model analysis for it.
///
/// `analysisJSON` holds an encoded `LearningExplanationDocument`; caching the whole document
/// (rather than re-deriving it) is what makes reopening an article instant.
public struct ArticleSentence: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var articleID: UUID
  /// Position in the article, counted across all paragraphs.
  public var index: Int
  /// Which paragraph this sentence belongs to, so the reader can keep the original blocking.
  public var paragraphIndex: Int
  public var text: String
  public var analysisJSON: String?
  public var analyzedAt: Date?

  public init(
    id: UUID = UUID(),
    articleID: UUID,
    index: Int,
    paragraphIndex: Int,
    text: String,
    analysisJSON: String? = nil,
    analyzedAt: Date? = nil
  ) {
    self.id = id
    self.articleID = articleID
    self.index = index
    self.paragraphIndex = paragraphIndex
    self.text = text
    self.analysisJSON = analysisJSON
    self.analyzedAt = analyzedAt
  }

  public var isAnalyzed: Bool {
    analysisJSON != nil
  }

  /// Decodes the cached document, returning nil when nothing is cached (or the cache predates
  /// a schema change and no longer decodes).
  public var analysis: SentenceAnalysis? {
    guard let analysisJSON,
          let document = try? JSONDecoder().decode(LearningExplanationDocument.self, from: Data(analysisJSON.utf8))
    else { return nil }
    return document.sentenceAnalysis
  }
}

/// How long collected articles are kept before they're swept.
public struct ArticleRetention: Equatable, Sendable {
  /// Days to keep an article after it was last opened. `0` means keep forever.
  public var days: Int

  public init(days: Int) {
    self.days = max(0, days)
  }

  public static let `default` = ArticleRetention(days: 30)
  public static let forever = ArticleRetention(days: 0)
  public static let options: [ArticleRetention] = [
    ArticleRetention(days: 7),
    ArticleRetention(days: 30),
    ArticleRetention(days: 90),
    .forever
  ]

  public var keepsForever: Bool { days == 0 }

  public var displayName: String {
    keepsForever ? "永久保留" : "\(days) 天"
  }

  /// Articles last opened before this instant are expired. Nil when nothing expires.
  public func expiryDate(now: Date) -> Date? {
    guard !keepsForever else { return nil }
    return now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
  }
}
