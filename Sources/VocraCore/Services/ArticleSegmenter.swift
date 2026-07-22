import Foundation
import NaturalLanguage

/// A collected selection normalized into paragraphs and sentences, ready to persist.
public struct ArticleDraft: Equatable, Sendable {
  public struct Sentence: Equatable, Sendable {
    public var text: String
    public var paragraphIndex: Int

    public init(text: String, paragraphIndex: Int) {
      self.text = text
      self.paragraphIndex = paragraphIndex
    }
  }

  public var title: String
  public var text: String
  public var sentences: [Sentence]

  public init(title: String, text: String, sentences: [Sentence]) {
    self.title = title
    self.text = text
    self.sentences = sentences
  }

  public var isEmpty: Bool { sentences.isEmpty }
  public var paragraphCount: Int { (sentences.map(\.paragraphIndex).max() ?? -1) + 1 }
}

/// Decides whether a selection is long-form reading material.
///
/// The dedicated shortcut is the user's explicit intent, so the thresholds here are a guard
/// against fat-fingered captures (a single word) rather than a gate — `isLongForm` is the
/// stricter test used to recognize an article that arrived through the plain lookup path.
public enum ArticleLengthPolicy {
  /// Below this, a selection isn't worth an article; the lookup panel handles it better.
  public static let minimumCharacters = 60
  public static let longFormCharacters = 240
  public static let longFormSentences = 3

  public static func isCollectable(_ draft: ArticleDraft) -> Bool {
    !draft.isEmpty && draft.text.count >= minimumCharacters
  }

  public static func isLongForm(_ draft: ArticleDraft) -> Bool {
    draft.text.count >= longFormCharacters && draft.sentences.count >= longFormSentences
  }
}

/// Splits raw selected text into paragraphs and sentences.
///
/// Copied text arrives with hard-wrapped lines (PDFs, terminals, narrow web columns), so
/// lines inside a paragraph are rejoined before sentence tokenization — otherwise every
/// visual line would become its own "sentence".
public struct ArticleSegmenter: Sendable {
  public init() {}

  public func segment(_ raw: String, titleHint: String? = nil) -> ArticleDraft {
    let paragraphs = paragraphs(in: raw)
    var sentences: [ArticleDraft.Sentence] = []
    for (paragraphIndex, paragraph) in paragraphs.enumerated() {
      for sentence in splitIntoSentences(paragraph) {
        sentences.append(ArticleDraft.Sentence(text: sentence, paragraphIndex: paragraphIndex))
      }
    }

    let text = paragraphs.joined(separator: "\n\n")
    return ArticleDraft(
      title: title(hint: titleHint, paragraphs: paragraphs, sentences: sentences),
      text: text,
      sentences: sentences
    )
  }

  // MARK: Paragraphs

  /// Blank lines separate paragraphs; single line breaks inside a paragraph are soft wraps
  /// and get folded back into one line.
  private func paragraphs(in raw: String) -> [String] {
    raw
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
      .split(whereSeparator: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
      .map { unwrapLines(Array($0)) }
      .filter { !$0.isEmpty }
  }

  /// Rejoins soft-wrapped lines, healing the hyphenation PDFs insert at a line break
  /// ("informa-\ntion" → "information").
  private func unwrapLines(_ lines: [String]) -> String {
    var result = ""
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }
      if result.isEmpty {
        result = trimmed
      } else if result.hasSuffix("-"), let next = trimmed.first, next.isLowercase {
        result.removeLast()
        result += trimmed
      } else {
        result += " " + trimmed
      }
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: Sentences

  private func splitIntoSentences(_ paragraph: String) -> [String] {
    let tokenizer = NLTokenizer(unit: .sentence)
    tokenizer.string = paragraph
    var sentences: [String] = []
    tokenizer.enumerateTokens(in: paragraph.startIndex..<paragraph.endIndex) { range, _ in
      let sentence = paragraph[range].trimmingCharacters(in: .whitespacesAndNewlines)
      if !sentence.isEmpty {
        sentences.append(sentence)
      }
      return true
    }
    // NLTokenizer returns nothing for a few pathological inputs (e.g. only punctuation);
    // fall back to the paragraph itself so no text is silently dropped.
    if sentences.isEmpty, !paragraph.isEmpty {
      sentences = [paragraph]
    }
    return sentences
  }

  // MARK: Title

  /// Prefers an explicit hint, then a short standalone opening line (a heading), then the
  /// first sentence truncated.
  private func title(hint: String?, paragraphs: [String], sentences: [ArticleDraft.Sentence]) -> String {
    if let hint = hint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
      return truncated(hint)
    }
    if let first = paragraphs.first, first.count <= 80, !endsSentence(first) {
      return truncated(first)
    }
    if let first = sentences.first?.text {
      return truncated(first)
    }
    return "未命名文章"
  }

  private func endsSentence(_ text: String) -> Bool {
    guard let last = text.last else { return false }
    return ".?!。？！".contains(last)
  }

  private func truncated(_ text: String, limit: Int = 42) -> String {
    let collapsed = text
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    guard collapsed.count > limit else { return collapsed }
    return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
  }
}
