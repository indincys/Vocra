import XCTest
@testable import VocraCore

final class MarkdownHTMLRendererTests: XCTestCase {
  func testRendersCommonMarkdownBlocksAndInlineEmphasisAsHTML() {
    let markdown = """
    # inconsistently

    ## Meaning
    **Part of speech**: adverb

    ---

    - unstable
    - not regular
    """

    let html = MarkdownHTMLRenderer().renderDocument(markdown)

    XCTAssertTrue(html.contains("<h1>inconsistently</h1>"))
    XCTAssertTrue(html.contains("<h2>Meaning</h2>"))
    XCTAssertTrue(html.contains("<strong>Part of speech</strong>"))
    XCTAssertTrue(html.contains("<hr>"))
    XCTAssertTrue(html.contains("<ul><li>unstable</li><li>not regular</li></ul>"))
    XCTAssertFalse(html.contains("# inconsistently"))
    XCTAssertFalse(html.contains("**Part of speech**"))
  }

  func testEscapesHTMLFromMarkdownText() {
    let markdown = """
    # <script>alert(1)</script>

    Use <unsafe> tags.
    """

    let html = MarkdownHTMLRenderer().renderDocument(markdown)

    XCTAssertTrue(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
    XCTAssertTrue(html.contains("Use &lt;unsafe&gt; tags."))
    XCTAssertFalse(html.contains("<script>alert(1)</script>"))
  }
}
