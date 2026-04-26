import Foundation

public struct MarkdownHTMLRenderer: Sendable {
  public init() {}

  public func renderDocument(_ markdown: String) -> String {
    let body = renderBody(markdown)
    return """
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
    :root { color-scheme: light dark; }
    html, body { margin: 0; padding: 0; background: transparent; }
    body { color: #f2f2f2; font: 16px -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; line-height: 1.45; overflow-wrap: anywhere; }
    h1, h2, h3, h4, h5, h6 { margin: 0.95em 0 0.45em; line-height: 1.18; font-weight: 700; }
    h1 { font-size: 1.55em; }
    h2 { font-size: 1.32em; }
    h3 { font-size: 1.16em; }
    p { margin: 0 0 0.85em; }
    strong { font-weight: 700; }
    em { font-style: italic; }
    code { border-radius: 5px; padding: 0.08em 0.28em; background: rgba(255,255,255,0.11); font-family: "SF Mono", Menlo, monospace; font-size: 0.92em; }
    pre { margin: 0.85em 0; padding: 0.75em; border-radius: 8px; background: rgba(255,255,255,0.11); overflow-x: auto; }
    pre code { padding: 0; background: transparent; }
    ul, ol { margin: 0 0 0.85em 1.35em; padding: 0; }
    li { margin: 0.22em 0; }
    blockquote { margin: 0 0 0.85em; padding-left: 0.85em; border-left: 3px solid rgba(255,255,255,0.28); color: rgba(242,242,242,0.82); }
    hr { border: 0; border-top: 1px solid rgba(255,255,255,0.16); margin: 1.05em 0; }
    a { color: #8cc8ff; text-decoration: none; }
    @media (prefers-color-scheme: light) {
      body { color: #1c1c1e; }
      code, pre { background: rgba(0,0,0,0.08); }
      blockquote { border-left-color: rgba(0,0,0,0.22); color: rgba(28,28,30,0.72); }
      hr { border-top-color: rgba(0,0,0,0.14); }
      a { color: #0066cc; }
    }
    </style>
    </head>
    <body>\(body)</body>
    </html>
    """
  }

  private func renderBody(_ markdown: String) -> String {
    let lines = markdown
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")

    var html: [String] = []
    var paragraphLines: [String] = []
    var index = 0

    func flushParagraph() {
      guard !paragraphLines.isEmpty else { return }
      let paragraph = paragraphLines
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .joined(separator: " ")
      html.append("<p>\(renderInline(paragraph))</p>")
      paragraphLines.removeAll()
    }

    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

      if trimmed.isEmpty {
        flushParagraph()
        index += 1
        continue
      }

      if trimmed.hasPrefix("```") {
        flushParagraph()
        index += 1
        var codeLines: [String] = []
        while index < lines.count {
          let codeLine = lines[index]
          if codeLine.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
            index += 1
            break
          }
          codeLines.append(codeLine)
          index += 1
        }
        html.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
        continue
      }

      if let heading = heading(from: line) {
        flushParagraph()
        html.append("<h\(heading.level)>\(renderInline(heading.text))</h\(heading.level)>")
        index += 1
        continue
      }

      if isHorizontalRule(trimmed) {
        flushParagraph()
        html.append("<hr>")
        index += 1
        continue
      }

      if let item = unorderedListItem(from: line) {
        flushParagraph()
        var items = [item]
        index += 1
        while index < lines.count, let nextItem = unorderedListItem(from: lines[index]) {
          items.append(nextItem)
          index += 1
        }
        html.append("<ul>\(items.map { "<li>\(renderInline($0))</li>" }.joined())</ul>")
        continue
      }

      if let item = orderedListItem(from: line) {
        flushParagraph()
        var items = [item]
        index += 1
        while index < lines.count, let nextItem = orderedListItem(from: lines[index]) {
          items.append(nextItem)
          index += 1
        }
        html.append("<ol>\(items.map { "<li>\(renderInline($0))</li>" }.joined())</ol>")
        continue
      }

      if let quote = blockquoteLine(from: line) {
        flushParagraph()
        var quoteLines = [quote]
        index += 1
        while index < lines.count, let nextQuote = blockquoteLine(from: lines[index]) {
          quoteLines.append(nextQuote)
          index += 1
        }
        html.append("<blockquote><p>\(renderInline(quoteLines.joined(separator: " ")))</p></blockquote>")
        continue
      }

      paragraphLines.append(line)
      index += 1
    }

    flushParagraph()
    return html.joined()
  }

  private func heading(from line: String) -> (level: Int, text: String)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var level = 0
    var index = trimmed.startIndex
    while index < trimmed.endIndex, trimmed[index] == "#", level < 6 {
      level += 1
      index = trimmed.index(after: index)
    }

    guard level > 0, index < trimmed.endIndex, trimmed[index].isWhitespace else {
      return nil
    }

    let text = trimmed[index...].trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : (level, text)
  }

  private func isHorizontalRule(_ line: String) -> Bool {
    let compact = line.filter { !$0.isWhitespace }
    guard compact.count >= 3, let first = compact.first, first == "-" || first == "*" || first == "_" else {
      return false
    }
    return compact.allSatisfy { $0 == first }
  }

  private func unorderedListItem(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.count > 2, let first = trimmed.first, first == "-" || first == "*" || first == "+" else {
      return nil
    }
    let second = trimmed.index(after: trimmed.startIndex)
    guard trimmed[second].isWhitespace else { return nil }
    return trimmed[trimmed.index(after: second)...].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func orderedListItem(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var index = trimmed.startIndex
    var sawDigit = false
    while index < trimmed.endIndex, trimmed[index].isNumber {
      sawDigit = true
      index = trimmed.index(after: index)
    }
    guard sawDigit, index < trimmed.endIndex, trimmed[index] == "." || trimmed[index] == ")" else {
      return nil
    }
    index = trimmed.index(after: index)
    guard index < trimmed.endIndex, trimmed[index].isWhitespace else { return nil }
    return trimmed[trimmed.index(after: index)...].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func blockquoteLine(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.first == ">" else { return nil }
    let contentStart = trimmed.index(after: trimmed.startIndex)
    return trimmed[contentStart...].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func renderInline(_ text: String) -> String {
    var output = ""
    var index = text.startIndex

    while index < text.endIndex {
      if starts(with: "`", in: text, at: index),
         let end = text[text.index(after: index)...].firstIndex(of: "`") {
        let contentStart = text.index(after: index)
        output += "<code>\(escapeHTML(String(text[contentStart..<end])))</code>"
        index = text.index(after: end)
        continue
      }

      if starts(with: "**", in: text, at: index),
         let end = text[text.index(index, offsetBy: 2)...].range(of: "**") {
        let contentStart = text.index(index, offsetBy: 2)
        output += "<strong>\(renderInline(String(text[contentStart..<end.lowerBound])))</strong>"
        index = end.upperBound
        continue
      }

      if starts(with: "__", in: text, at: index),
         let end = text[text.index(index, offsetBy: 2)...].range(of: "__") {
        let contentStart = text.index(index, offsetBy: 2)
        output += "<strong>\(renderInline(String(text[contentStart..<end.lowerBound])))</strong>"
        index = end.upperBound
        continue
      }

      if text[index] == "[", let renderedLink = renderLink(in: text, at: index) {
        output += renderedLink.html
        index = renderedLink.endIndex
        continue
      }

      if text[index] == "*",
         !starts(with: "**", in: text, at: index),
         let end = text[text.index(after: index)...].firstIndex(of: "*") {
        let contentStart = text.index(after: index)
        output += "<em>\(renderInline(String(text[contentStart..<end])))</em>"
        index = text.index(after: end)
        continue
      }

      output += escapeHTML(String(text[index]))
      index = text.index(after: index)
    }

    return output
  }

  private func renderLink(in text: String, at index: String.Index) -> (html: String, endIndex: String.Index)? {
    guard
      let labelEnd = text[index...].firstIndex(of: "]"),
      labelEnd < text.index(before: text.endIndex)
    else {
      return nil
    }

    let openParen = text.index(after: labelEnd)
    guard openParen < text.endIndex, text[openParen] == "(" else { return nil }
    let urlStart = text.index(after: openParen)
    guard let urlEnd = text[urlStart...].firstIndex(of: ")") else { return nil }

    let labelStart = text.index(after: index)
    let label = renderInline(String(text[labelStart..<labelEnd]))
    let url = String(text[urlStart..<urlEnd])
    guard isSafeLink(url) else { return nil }

    return ("<a href=\"\(escapeHTMLAttribute(url))\">\(label)</a>", text.index(after: urlEnd))
  }

  private func starts(with prefix: String, in text: String, at index: String.Index) -> Bool {
    text[index...].hasPrefix(prefix)
  }

  private func isSafeLink(_ url: String) -> Bool {
    guard let components = URLComponents(string: url), let scheme = components.scheme?.lowercased() else {
      return false
    }
    return scheme == "http" || scheme == "https"
  }

  private func escapeHTML(_ text: String) -> String {
    text
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }

  private func escapeHTMLAttribute(_ text: String) -> String {
    escapeHTML(text)
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}
