import Foundation
import SQLite3

public protocol VocabularyRepository: Sendable {
  func allCards() throws -> [VocabularyCard]
  func dueCards(now: Date) throws -> [VocabularyCard]
  func upsert(text: String, type: VocabularyType, cardJSON: String, sourceApp: String?, now: Date) throws -> VocabularyCard
  func applyReview(cardID: UUID, rating: ReviewRating, now: Date, scheduler: ReviewScheduler) throws
}

public final class SQLiteVocabularyRepository: VocabularyRepository, @unchecked Sendable {
  private let database: SQLiteDatabase

  public init(path: String) throws {
    self.database = try SQLiteDatabase(path: path)
    try migrate()
  }

  public static func inMemory() throws -> SQLiteVocabularyRepository {
    try SQLiteVocabularyRepository(path: ":memory:")
  }

  public func allCards() throws -> [VocabularyCard] {
    try fetchCards(whereClause: "1 = 1", bindings: [])
  }

  public func dueCards(now: Date) throws -> [VocabularyCard] {
    try fetchCards(whereClause: "status != 'mastered' AND nextReviewAt IS NOT NULL AND nextReviewAt <= ?", bindings: [.double(now.timeIntervalSince1970)])
  }

  public func upsert(text: String, type: VocabularyType, cardJSON: String, sourceApp: String?, now: Date) throws -> VocabularyCard {
    let normalized = normalize(text)
    if var existing = try card(normalizedText: normalized) {
      existing.cardJSON = cardJSON
      existing.sourceApp = sourceApp
      existing.updatedAt = now
      try save(existing, normalizedText: normalized)
      return existing
    }

    let card = VocabularyCard(
      text: text.trimmingCharacters(in: .whitespacesAndNewlines),
      type: type,
      cardJSON: cardJSON,
      sourceApp: sourceApp,
      createdAt: now,
      updatedAt: now,
      lastReviewedAt: nil,
      nextReviewAt: now,
      reviewCount: 0,
      status: .new,
      familiarityLevel: 0
    )
    try insert(card, normalizedText: normalized)
    return card
  }

  @available(*, deprecated, message: "Transitional bridge for Task 6; use cardJSON.")
  public func upsert(text: String, type: VocabularyType, cardMarkdown: String, sourceApp: String?, now: Date) throws -> VocabularyCard {
    let cardJSON = try legacyCardJSON(text: text, type: type, cardMarkdown: cardMarkdown)
    return try upsert(text: text, type: type, cardJSON: cardJSON, sourceApp: sourceApp, now: now)
  }

  public func applyReview(cardID: UUID, rating: ReviewRating, now: Date, scheduler: ReviewScheduler) throws {
    guard var card = try card(id: cardID) else { return }
    let result = scheduler.schedule(after: rating, now: now)
    card.lastReviewedAt = now
    card.nextReviewAt = result.nextReviewAt
    card.reviewCount += 1
    card.status = result.status
    card.familiarityLevel = result.familiarityLevel
    card.updatedAt = now
    try save(card, normalizedText: normalize(card.text))
  }

  private func migrate() throws {
    let version = try userVersion()
    if version < 2 {
      try database.execute("DROP TABLE IF EXISTS vocabulary_cards;")
    }
    try database.execute("""
    CREATE TABLE IF NOT EXISTS vocabulary_cards (
      id TEXT PRIMARY KEY,
      normalizedText TEXT UNIQUE NOT NULL,
      text TEXT NOT NULL,
      type TEXT NOT NULL,
      cardJSON TEXT NOT NULL,
      schemaVersion INTEGER NOT NULL,
      sourceApp TEXT,
      createdAt REAL NOT NULL,
      updatedAt REAL NOT NULL,
      lastReviewedAt REAL,
      nextReviewAt REAL,
      reviewCount INTEGER NOT NULL,
      status TEXT NOT NULL,
      familiarityLevel INTEGER NOT NULL
    );
    """)
    try database.execute("PRAGMA user_version = 2;")
  }

  private func userVersion() throws -> Int {
    let statement = try database.prepare("PRAGMA user_version;")
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
    return Int(sqlite3_column_int(statement, 0))
  }

  private func normalize(_ text: String) -> String {
    text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .lowercased()
  }

  private func legacyCardJSON(text: String, type: VocabularyType, cardMarkdown: String) throws -> String {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedMarkdown = cardMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
    let coreMeaning = trimmedMarkdown.isEmpty ? trimmedText : cardMarkdown
    let document = LearningExplanationDocument(
      schemaVersion: LearningExplanationDocument.currentSchemaVersion,
      mode: type == .word ? .word : .phrase,
      sourceText: trimmedText,
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: nil,
      vocabularyCard: StructuredVocabularyCard(
        front: VocabularyCardFront(text: trimmedText, hint: nil),
        back: VocabularyCardBack(
          coreMeaning: coreMeaning,
          memoryNote: "Legacy card content captured before structured card generation.",
          usage: "Review this item with the saved legacy explanation."
        ),
        examples: [],
        reviewPrompts: []
      ),
      warnings: ["Converted from legacy markdown bridge."]
    )
    let data = try JSONEncoder().encode(document)
    return String(decoding: data, as: UTF8.self)
  }

  private func insert(_ card: VocabularyCard, normalizedText: String) throws {
    try executeSave(card, normalizedText: normalizedText, sql: """
    INSERT INTO vocabulary_cards
    (id, normalizedText, text, type, cardJSON, schemaVersion, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """)
  }

  private func save(_ card: VocabularyCard, normalizedText: String) throws {
    try executeSave(card, normalizedText: normalizedText, sql: """
    REPLACE INTO vocabulary_cards
    (id, normalizedText, text, type, cardJSON, schemaVersion, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """)
  }

  private func executeSave(_ card: VocabularyCard, normalizedText: String, sql: String) throws {
    let statement = try database.prepare(sql)
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_text(statement, 1, card.id.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 2, normalizedText, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 3, card.text, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 4, card.type.rawValue, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 5, card.cardJSON, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(statement, 6, Int32(LearningExplanationDocument.currentSchemaVersion))
    bindOptionalText(statement, 7, card.sourceApp)
    sqlite3_bind_double(statement, 8, card.createdAt.timeIntervalSince1970)
    sqlite3_bind_double(statement, 9, card.updatedAt.timeIntervalSince1970)
    bindOptionalDate(statement, 10, card.lastReviewedAt)
    bindOptionalDate(statement, 11, card.nextReviewAt)
    sqlite3_bind_int(statement, 12, Int32(card.reviewCount))
    sqlite3_bind_text(statement, 13, card.status.rawValue, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(statement, 14, Int32(card.familiarityLevel))
    guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.step("save vocabulary card failed") }
  }

  private func card(id: UUID) throws -> VocabularyCard? {
    try fetchCards(whereClause: "id = ?", bindings: [.text(id.uuidString)]).first
  }

  private func card(normalizedText: String) throws -> VocabularyCard? {
    try fetchCards(whereClause: "normalizedText = ?", bindings: [.text(normalizedText)]).first
  }

  private enum Binding {
    case text(String)
    case double(Double)
  }

  private func fetchCards(whereClause: String, bindings: [Binding]) throws -> [VocabularyCard] {
    let statement = try database.prepare("SELECT id, text, type, cardJSON, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel FROM vocabulary_cards WHERE \(whereClause) ORDER BY updatedAt DESC;")
    defer { sqlite3_finalize(statement) }

    for (index, binding) in bindings.enumerated() {
      let position = Int32(index + 1)
      switch binding {
      case .text(let value): sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
      case .double(let value): sqlite3_bind_double(statement, position, value)
      }
    }

    var cards: [VocabularyCard] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      cards.append(readCard(from: statement))
    }
    return cards
  }

  private func readCard(from statement: OpaquePointer?) -> VocabularyCard {
    VocabularyCard(
      id: UUID(uuidString: text(statement, 0))!,
      text: text(statement, 1),
      type: VocabularyType(rawValue: text(statement, 2))!,
      cardJSON: text(statement, 3),
      sourceApp: optionalText(statement, 4),
      createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
      updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
      lastReviewedAt: optionalDate(statement, 7),
      nextReviewAt: optionalDate(statement, 8),
      reviewCount: Int(sqlite3_column_int(statement, 9)),
      status: VocabularyStatus(rawValue: text(statement, 10))!,
      familiarityLevel: Int(sqlite3_column_int(statement, 11))
    )
  }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
  String(cString: sqlite3_column_text(statement, column))
}

private func optionalText(_ statement: OpaquePointer?, _ column: Int32) -> String? {
  guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
  return text(statement, column)
}

private func optionalDate(_ statement: OpaquePointer?, _ column: Int32) -> Date? {
  guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
  return Date(timeIntervalSince1970: sqlite3_column_double(statement, column))
}

private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
  guard let value else {
    sqlite3_bind_null(statement, index)
    return
  }
  sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
}

private func bindOptionalDate(_ statement: OpaquePointer?, _ index: Int32, _ value: Date?) {
  guard let value else {
    sqlite3_bind_null(statement, index)
    return
  }
  sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
}
