import Foundation
import Testing
@testable import docmostly

struct NativeEditorHTMLTagMatchingTests {
    @Test func htmlTagNameMatchingIsLocaleIndependent() {
        let turkish = Locale(identifier: "tr_TR")

        #expect(NativeEditorMarkdownParser.htmlTagNameMatches("DIV", "div", locale: turkish))
        #expect(NativeEditorMarkdownParser.htmlTagNameMatches("IMG", "img", locale: turkish))
        #expect(NativeEditorMarkdownParser.htmlTagNameMatches("SPAN", "span", locale: turkish))
    }
}
