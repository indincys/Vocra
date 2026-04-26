import XCTest
@testable import VocraCore

final class VocabularyRepositoryTests: XCTestCase {
  func testUpsertCreatesAndDeduplicatesByNormalizedText() throws {
    let repository = try SQLiteVocabularyRepository.inMemory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    let first = try repository.upsert(text: "Context Window", type: .phrase, cardMarkdown: "Card A", sourceApp: "Safari", now: now)
    let second = try repository.upsert(text: " context   window ", type: .phrase, cardMarkdown: "Card B", sourceApp: "Codex", now: now)

    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(try repository.allCards().count, 1)
    XCTAssertEqual(try repository.allCards().first?.sourceApp, "Codex")
  }

  func testDueCardsExcludeMasteredCards() throws {
    let repository = try SQLiteVocabularyRepository.inMemory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let card = try repository.upsert(text: "embedding", type: .word, cardMarkdown: "Card", sourceApp: nil, now: now)

    try repository.applyReview(cardID: card.id, rating: .mastered, now: now, scheduler: ReviewScheduler())

    XCTAssertTrue(try repository.dueCards(now: now).isEmpty)
  }
}
