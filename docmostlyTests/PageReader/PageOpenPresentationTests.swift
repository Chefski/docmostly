import Testing
@testable import docmostly

@MainActor
struct PageOpenPresentationTests {
    @Test func stackReaderClearsSelectionWhenItDisappears() {
        #expect(PageOpenPresentation.stack.shouldClearSelectedPageOnReaderDisappear)
    }

    @Test func detailColumnTransitionPreservesTheSelectedPage() {
        #expect(!PageOpenPresentation.detailColumn.shouldClearSelectedPageOnReaderDisappear)
    }
}
