import XCTest
import SQLite3
@testable import VocraCore

final class VocabularyRepositoryTests: XCTestCase {
  func testUpsertCreatesAndDeduplicatesByNormalizedText() throws {
    let repository = try SQLiteVocabularyRepository.inMemory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let cardJSON = #"{"schemaVersion":1,"mode":"phrase","sourceText":"Context Window","language":{"source":"en","explanation":"zh-Hans"},"sentenceAnalysis":null,"wordExplanation":null,"vocabularyCard":{"front":{"text":"Context Window","hint":null},"back":{"coreMeaning":"上下文窗口","memoryNote":"context + window","usage":"大模型上下文范围"},"examples":[],"reviewPrompts":[]},"warnings":[]}"#

    let first = try repository.upsert(text: "Context Window", type: .phrase, cardJSON: cardJSON, sourceApp: "Safari", now: now)
    let second = try repository.upsert(text: " context   window ", type: .phrase, cardJSON: cardJSON, sourceApp: "Codex", now: now)

    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(try repository.allCards().count, 1)
    XCTAssertEqual(try repository.allCards().first?.sourceApp, "Codex")
    XCTAssertEqual(try repository.allCards().first?.cardJSON, cardJSON)
  }

  func testDeprecatedMarkdownBridgeStoresDecodableVocabularyCardJSON() throws {
    let repository = try SQLiteVocabularyRepository.inMemory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    _ = try repository.upsert(text: " legacy term ", type: .word, cardMarkdown: "# Legacy", sourceApp: nil, now: now)

    let card = try XCTUnwrap(repository.allCards().first)
    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(card.cardJSON.utf8))
    XCTAssertNotNil(document.vocabularyCard)
    XCTAssertEqual(document.vocabularyCard?.back.coreMeaning, "# Legacy")
  }

  func testDueCardsExcludeMasteredCards() throws {
    let repository = try SQLiteVocabularyRepository.inMemory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let card = try repository.upsert(text: "embedding", type: .word, cardJSON: #"{"schemaVersion":1}"#, sourceApp: nil, now: now)

    try repository.applyReview(cardID: card.id, rating: .mastered, now: now, scheduler: ReviewScheduler())

    XCTAssertTrue(try repository.dueCards(now: now).isEmpty)
  }

  func testMigrationFromVersionOneDropsLegacyMarkdownTable() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("VocabularyRepositoryTests-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    try createVersionOneDatabase(at: fileURL.path)

    let repository = try SQLiteVocabularyRepository(path: fileURL.path)
    XCTAssertTrue(try repository.allCards().isEmpty)

    _ = try repository.upsert(text: "reset", type: .word, cardJSON: #"{"schemaVersion":1}"#, sourceApp: nil, now: Date(timeIntervalSince1970: 1_800_000_000))
    XCTAssertEqual(try repository.allCards().first?.cardJSON, #"{"schemaVersion":1}"#)
  }

  private func createVersionOneDatabase(at path: String) throws {
    var database: OpaquePointer?
    XCTAssertEqual(sqlite3_open(path, &database), SQLITE_OK)
    defer { sqlite3_close(database) }

    let sql = """
    CREATE TABLE vocabulary_cards (
      id TEXT PRIMARY KEY,
      normalizedText TEXT UNIQUE NOT NULL,
      text TEXT NOT NULL,
      type TEXT NOT NULL,
      cardMarkdown TEXT NOT NULL,
      sourceApp TEXT,
      createdAt REAL NOT NULL,
      updatedAt REAL NOT NULL,
      lastReviewedAt REAL,
      nextReviewAt REAL,
      reviewCount INTEGER NOT NULL,
      status TEXT NOT NULL,
      familiarityLevel INTEGER NOT NULL
    );
    INSERT INTO vocabulary_cards
    (id, normalizedText, text, type, cardMarkdown, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel)
    VALUES ('00000000-0000-0000-0000-000000000001', 'legacy', 'legacy', 'word', '# Legacy', NULL, 1, 1, NULL, 1, 0, 'new', 0);
    PRAGMA user_version = 1;
    """
    XCTAssertEqual(sqlite3_exec(database, sql, nil, nil, nil), SQLITE_OK)
  }
}
