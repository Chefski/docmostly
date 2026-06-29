import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorHTMLTagMatchingTests {
    @Test func htmlTagNameMatchingIsLocaleIndependent() {
        let turkish = Locale(identifier: "tr_TR")

        #expect(NativeEditorMarkdownParser.htmlTagNameMatches("DIV", "div", locale: turkish))
        #expect(NativeEditorMarkdownParser.htmlTagNameMatches("IMG", "img", locale: turkish))
        #expect(NativeEditorMarkdownParser.htmlTagNameMatches("SPAN", "span", locale: turkish))
    }

    @Test func matchingCloseSpanRangeIgnoresSpanCandidatesInsideMarkdownCode() throws {
        let markdown = ##"<span style="color: #2563EB">`<span data-type="mention"></span>` "##
            + ##"<span style="color: #DC2626">nested</span> outer</span>"##
        let openingTagEnd = try #require(markdown.firstIndex(of: ">"))
        let bodyStart = markdown.index(after: openingTagEnd)

        let closeRange = try #require(
            NativeEditorMarkdownParser.matchingCloseSpanRange(in: markdown[...], bodyStart: bodyStart)
        )
        let expectedCloseRange = try #require(markdown.range(of: "</span>", options: .backwards))

        #expect(closeRange == expectedCloseRange)
    }

    @Test func htmlTagDepthDeltaIgnoresTagLookalikesInsideQuotedAttributes() {
        let line = #"<div><span data-attr="</div>">x</span></div>"#

        #expect(NativeEditorMarkdownParser.htmlTagDepthDelta(in: line, tagName: "div") == 0)
    }
}
