import Foundation
import SQLite3

public protocol ArticleRepository: Sendable {
  func allArticles() throws -> [Article]
  func article(id: UUID) throws -> Article?
  func sentences(articleID: UUID) throws -> [ArticleSentence]
  @discardableResult
  func insert(draft: ArticleDraft, sourceApp: String?, now: Date) throws -> Article
  func saveAnalysis(sentenceID: UUID, analysisJSON: String, analyzedAt: Date) throws
  func markOpened(articleID: UUID, now: Date) throws
  func delete(articleID: UUID) throws
  /// Deletes every article last opened before `date`, returning how many went away.
  @discardableResult
  func deleteArticles(lastOpenedBefore date: Date) throws -> Int
}

/// SQLite-backed article store.
///
/// Articles live in their own database file rather than sharing `vocra.sqlite`: the two
/// schemas migrate independently (both use `PRAGMA user_version`), and reading material with
/// a 30-day sweep has a very different lifecycle from the permanent vocabulary notebook.
public final class SQLiteArticleRepository: ArticleRepository, @unchecked Sendable {
  private let database: SQLiteDatabase

  public init(path: String) throws {
    self.database = try SQLiteDatabase(path: path)
    try migrate()
  }

  public static func inMemory() throws -> SQLiteArticleRepository {
    try SQLiteArticleRepository(path: ":memory:")
  }

  // MARK: Reads

  public func allArticles() throws -> [Article] {
    try fetchArticles(whereClause: "1 = 1", bindings: [])
  }

  public func article(id: UUID) throws -> Article? {
    try fetchArticles(whereClause: "a.id = ?", bindings: [.text(id.uuidString)]).first
  }

  public func sentences(articleID: UUID) throws -> [ArticleSentence] {
    let statement = try database.prepare("""
    SELECT id, articleID, sentenceIndex, paragraphIndex, text, analysisJSON, analyzedAt
    FROM article_sentences WHERE articleID = ? ORDER BY sentenceIndex ASC;
    """)
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_text(statement, 1, articleID.uuidString, -1, SQLITE_TRANSIENT)

    var sentences: [ArticleSentence] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      sentences.append(ArticleSentence(
        id: UUID(uuidString: columnText(statement, 0)) ?? UUID(),
        articleID: articleID,
        index: Int(sqlite3_column_int(statement, 2)),
        paragraphIndex: Int(sqlite3_column_int(statement, 3)),
        text: columnText(statement, 4),
        analysisJSON: optionalColumnText(statement, 5),
        analyzedAt: optionalColumnDate(statement, 6)
      ))
    }
    return sentences
  }

  // MARK: Writes

  @discardableResult
  public func insert(draft: ArticleDraft, sourceApp: String?, now: Date) throws -> Article {
    let article = Article(
      title: draft.title,
      sourceText: draft.text,
      sourceApp: sourceApp,
      createdAt: now,
      lastOpenedAt: now,
      sentenceCount: draft.sentences.count,
      analyzedCount: 0
    )

    try database.execute("BEGIN;")
    do {
      let statement = try database.prepare("""
      INSERT INTO articles (id, title, sourceText, sourceApp, createdAt, lastOpenedAt, sentenceCount)
      VALUES (?, ?, ?, ?, ?, ?, ?);
      """)
      defer { sqlite3_finalize(statement) }
      sqlite3_bind_text(statement, 1, article.id.uuidString, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(statement, 2, article.title, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(statement, 3, article.sourceText, -1, SQLITE_TRANSIENT)
      bindOptional(statement, 4, sourceApp)
      sqlite3_bind_double(statement, 5, now.timeIntervalSince1970)
      sqlite3_bind_double(statement, 6, now.timeIntervalSince1970)
      sqlite3_bind_int(statement, 7, Int32(draft.sentences.count))
      guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.step("insert article failed") }

      for (index, sentence) in draft.sentences.enumerated() {
        try insertSentence(articleID: article.id, index: index, sentence: sentence)
      }
      try database.execute("COMMIT;")
    } catch {
      try? database.execute("ROLLBACK;")
      throw error
    }
    return article
  }

  private func insertSentence(articleID: UUID, index: Int, sentence: ArticleDraft.Sentence) throws {
    let statement = try database.prepare("""
    INSERT INTO article_sentences (id, articleID, sentenceIndex, paragraphIndex, text, analysisJSON, analyzedAt)
    VALUES (?, ?, ?, ?, ?, NULL, NULL);
    """)
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_text(statement, 1, UUID().uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 2, articleID.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(statement, 3, Int32(index))
    sqlite3_bind_int(statement, 4, Int32(sentence.paragraphIndex))
    sqlite3_bind_text(statement, 5, sentence.text, -1, SQLITE_TRANSIENT)
    guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.step("insert article sentence failed") }
  }

  public func saveAnalysis(sentenceID: UUID, analysisJSON: String, analyzedAt: Date) throws {
    let statement = try database.prepare("""
    UPDATE article_sentences SET analysisJSON = ?, analyzedAt = ? WHERE id = ?;
    """)
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_text(statement, 1, analysisJSON, -1, SQLITE_TRANSIENT)
    sqlite3_bind_double(statement, 2, analyzedAt.timeIntervalSince1970)
    sqlite3_bind_text(statement, 3, sentenceID.uuidString, -1, SQLITE_TRANSIENT)
    guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.step("save sentence analysis failed") }
  }

  public func markOpened(articleID: UUID, now: Date) throws {
    let statement = try database.prepare("UPDATE articles SET lastOpenedAt = ? WHERE id = ?;")
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_double(statement, 1, now.timeIntervalSince1970)
    sqlite3_bind_text(statement, 2, articleID.uuidString, -1, SQLITE_TRANSIENT)
    guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.step("mark article opened failed") }
  }

  public func delete(articleID: UUID) throws {
    let statement = try database.prepare("DELETE FROM articles WHERE id = ?;")
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_text(statement, 1, articleID.uuidString, -1, SQLITE_TRANSIENT)
    guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.step("delete article failed") }
  }

  @discardableResult
  public func deleteArticles(lastOpenedBefore date: Date) throws -> Int {
    let statement = try database.prepare("DELETE FROM articles WHERE lastOpenedAt < ?;")
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
    guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.step("sweep expired articles failed") }
    return database.changes
  }

  // MARK: Schema

  private func migrate() throws {
    // Sentences are removed with their article via ON DELETE CASCADE, so the retention sweep
    // is a single DELETE.
    try database.execute("PRAGMA foreign_keys = ON;")
    try database.execute("""
    CREATE TABLE IF NOT EXISTS articles (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      sourceText TEXT NOT NULL,
      sourceApp TEXT,
      createdAt REAL NOT NULL,
      lastOpenedAt REAL NOT NULL,
      sentenceCount INTEGER NOT NULL
    );
    """)
    try database.execute("""
    CREATE TABLE IF NOT EXISTS article_sentences (
      id TEXT PRIMARY KEY,
      articleID TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
      sentenceIndex INTEGER NOT NULL,
      paragraphIndex INTEGER NOT NULL,
      text TEXT NOT NULL,
      analysisJSON TEXT,
      analyzedAt REAL
    );
    """)
    try database.execute("CREATE INDEX IF NOT EXISTS article_sentences_article ON article_sentences(articleID, sentenceIndex);")
    try database.execute("PRAGMA user_version = 1;")
  }

  private enum Binding {
    case text(String)
    case double(Double)
  }

  /// Joins in the analyzed-sentence count so the list can show progress without a second
  /// query per article.
  private func fetchArticles(whereClause: String, bindings: [Binding]) throws -> [Article] {
    let statement = try database.prepare("""
    SELECT a.id, a.title, a.sourceText, a.sourceApp, a.createdAt, a.lastOpenedAt, a.sentenceCount,
      (SELECT COUNT(*) FROM article_sentences s WHERE s.articleID = a.id AND s.analysisJSON IS NOT NULL)
    FROM articles a WHERE \(whereClause) ORDER BY a.lastOpenedAt DESC;
    """)
    defer { sqlite3_finalize(statement) }

    for (index, binding) in bindings.enumerated() {
      let position = Int32(index + 1)
      switch binding {
      case .text(let value): sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
      case .double(let value): sqlite3_bind_double(statement, position, value)
      }
    }

    var articles: [Article] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      articles.append(Article(
        id: UUID(uuidString: columnText(statement, 0)) ?? UUID(),
        title: columnText(statement, 1),
        sourceText: columnText(statement, 2),
        sourceApp: optionalColumnText(statement, 3),
        createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
        lastOpenedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
        sentenceCount: Int(sqlite3_column_int(statement, 6)),
        analyzedCount: Int(sqlite3_column_int(statement, 7))
      ))
    }
    return articles
  }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func columnText(_ statement: OpaquePointer?, _ column: Int32) -> String {
  guard let pointer = sqlite3_column_text(statement, column) else { return "" }
  return String(cString: pointer)
}

private func optionalColumnText(_ statement: OpaquePointer?, _ column: Int32) -> String? {
  guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
  return columnText(statement, column)
}

private func optionalColumnDate(_ statement: OpaquePointer?, _ column: Int32) -> Date? {
  guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
  return Date(timeIntervalSince1970: sqlite3_column_double(statement, column))
}

private func bindOptional(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
  guard let value else {
    sqlite3_bind_null(statement, index)
    return
  }
  sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
}
