import XCTest
@testable import VocraCore

final class ExplanationCacheTests: XCTestCase {
  private func makeDocument(text: String) -> LearningExplanationDocument {
    LearningExplanationDocument(
      schemaVersion: 1, mode: .word, sourceText: text,
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: WordExplanation(
        term: text, pronunciation: nil, partOfSpeech: "n.",
        coreMeaning: "meaning", contextualMeaning: "context",
        usageNotes: [], collocations: [], examples: [], commonMistakes: []
      ),
      vocabularyCard: nil, warnings: []
    )
  }

  func testStoresAndRetrievesByNormalizedKey() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vocra-cache-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let cache = DiskExplanationCache(directory: dir)

    XCTAssertNil(cache.cached(text: "idempotent", mode: .word, model: "m"))
    cache.store(makeDocument(text: "idempotent"), text: "idempotent", mode: .word, model: "m")

    XCTAssertNotNil(cache.cached(text: "  Idempotent ", mode: .word, model: "m")) // case + space normalized
    XCTAssertNil(cache.cached(text: "idempotent", mode: .sentence, model: "m"))   // mode differs
    XCTAssertNil(cache.cached(text: "idempotent", mode: .word, model: "other"))   // model differs
  }

  func testVariantSeparatesEntries() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vocra-cache-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let cache = DiskExplanationCache(directory: dir)

    cache.store(makeDocument(text: "resolve"), text: "resolve", mode: .word, model: "m", variant: "a")

    XCTAssertNotNil(cache.cached(text: "resolve", mode: .word, model: "m", variant: "a"))
    XCTAssertNil(cache.cached(text: "resolve", mode: .word, model: "m", variant: "b"), "different variant misses")
  }

  func testDiskEvictsOldestBeyondLimit() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vocra-cache-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let cache = DiskExplanationCache(directory: dir, memoryLimit: 2, diskLimit: 3)

    for index in 0..<5 {
      cache.store(makeDocument(text: "term\(index)"), text: "term\(index)", mode: .word, model: "m")
    }

    let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    XCTAssertLessThanOrEqual(files.count, 3, "disk cache pruned to the limit")
    // The most recent entry is still retrievable.
    XCTAssertNotNil(cache.cached(text: "term4", mode: .word, model: "m"))
  }

  func testPersistsAcrossInstances() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vocra-cache-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }

    DiskExplanationCache(directory: dir).store(makeDocument(text: "throttle"), text: "throttle", mode: .word, model: "m")
    let reloaded = DiskExplanationCache(directory: dir)

    XCTAssertEqual(reloaded.cached(text: "throttle", mode: .word, model: "m")?.sourceText, "throttle")
  }
}
