import XCTest
@testable import Vocra
import VocraCore

final class SentenceDisplayPiecesTests: XCTestCase {
  private func segment(_ text: String, _ labelZh: String, id: String? = nil) -> SentenceSegment {
    SentenceSegment(
      id: id ?? labelZh,
      text: text,
      role: "role",
      labelZh: labelZh,
      labelEn: "Role",
      color: .blue
    )
  }

  private func normalizedWords(_ string: String) -> String {
    string.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }

  private func reconstructed(_ pieces: [SentenceDisplayPiece]) -> String {
    normalizedWords(pieces.map(\.text).joined(separator: " "))
  }

  /// The whole sentence must survive even when the model marks only a few spans.
  func testKeepsFullSentenceWhenSegmentsCoverOnlyPart() {
    let text = "More than 5 million people now use Codex. Codex is useful."
    let segments = [
      segment("More than 5 million people", "主语"),
      segment("now use", "谓语")
    ]

    let pieces = sentenceDisplayPieces(text: text, segments: segments)

    XCTAssertEqual(reconstructed(pieces), normalizedWords(text))
    let roleTexts = pieces.compactMap { piece -> String? in
      if case .role = piece.kind { return piece.text }
      return nil
    }
    XCTAssertEqual(roleTexts, ["More than 5 million people", "now use"])
  }

  /// Spans are matched in reading order and rendered whole, with the connective
  /// tissue between them kept as plain words.
  func testRoleSpansStayWholeAndInOrder() {
    let text = "Codex started as a tool, but it's increasingly useful."
    let segments = [
      segment("Codex", "主语"),
      segment("but", "连词"),
      segment("increasingly useful", "表语")
    ]

    let pieces = sentenceDisplayPieces(text: text, segments: segments)

    XCTAssertEqual(reconstructed(pieces), normalizedWords(text))
    let labels = pieces.compactMap { piece -> String? in
      if case let .role(seg) = piece.kind { return seg.labelZh }
      return nil
    }
    XCTAssertEqual(labels, ["主语", "连词", "表语"])
  }

  /// A span whose whitespace differs from the source is still located.
  func testToleratesWhitespaceDifferencesWhenLocatingSpans() {
    let text = "Codex works best when configured."
    let pieces = sentenceDisplayPieces(text: text, segments: [segment("works  best", "谓语")])

    XCTAssertEqual(reconstructed(pieces), normalizedWords(text))
    XCTAssertTrue(pieces.contains { piece in
      if case .role = piece.kind { return piece.text == "works best" }
      return false
    })
  }

  /// Empty segments still yield the full sentence as plain words.
  func testEmptySegmentsRenderPlainSentence() {
    let text = "Codex is useful."
    let pieces = sentenceDisplayPieces(text: text, segments: [])

    XCTAssertEqual(reconstructed(pieces), normalizedWords(text))
    XCTAssertTrue(pieces.allSatisfy { if case .plain = $0.kind { return true } else { return false } })
  }

  /// A hallucinated span that does not occur in the text is dropped, but the
  /// sentence is still rendered in full.
  func testDropsSpanThatDoesNotOccurInText() {
    let text = "Codex is useful."
    let pieces = sentenceDisplayPieces(
      text: text,
      segments: [segment("nonexistent phrase", "主语"), segment("useful", "表语")]
    )

    XCTAssertEqual(reconstructed(pieces), normalizedWords(text))
    // Punctuation rides with its word, so the matched span shows "useful."
    let roleTexts = pieces.compactMap { piece -> String? in
      if case .role = piece.kind { return piece.text }
      return nil
    }
    XCTAssertEqual(roleTexts, ["useful."])
  }
}
