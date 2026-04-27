import XCTest
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

  func testDueCardsExcludeMasteredCards() throws {
    let repository = try SQLiteVocabularyRepository.inMemory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let card = try repository.upsert(text: "embedding", type: .word, cardJSON: #"{"schemaVersion":1}"#, sourceApp: nil, now: now)

    try repository.applyReview(cardID: card.id, rating: .mastered, now: now, scheduler: ReviewScheduler())

    XCTAssertTrue(try repository.dueCards(now: now).isEmpty)
  }
}
