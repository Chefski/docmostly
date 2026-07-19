import Foundation
import Testing
@testable import docmostly

struct CursorPageAccumulatorTests {
    @Test func appendingPagesDeduplicatesStableIDsAndAdvancesCursor() {
        var accumulator = CursorPageAccumulator<TestItem>()
        accumulator.replace(with: response(
            items: [TestItem(id: "1"), TestItem(id: "2")],
            nextCursor: "cursor-2"
        ))

        accumulator.append(
            response(items: [TestItem(id: "2"), TestItem(id: "3")], nextCursor: nil),
            requestedCursor: "cursor-2"
        )

        #expect(accumulator.items.map(\.id) == ["1", "2", "3"])
        #expect(accumulator.hasNextPage == false)
        #expect(accumulator.nextCursor == nil)
    }

    @Test func repeatedServerCursorStopsPaginationLoop() {
        var accumulator = CursorPageAccumulator<TestItem>()
        accumulator.replace(with: response(items: [TestItem(id: "1")], nextCursor: "same-cursor"))

        accumulator.append(
            response(items: [TestItem(id: "2")], nextCursor: "same-cursor"),
            requestedCursor: "same-cursor"
        )

        #expect(accumulator.items.map(\.id) == ["1", "2"])
        #expect(accumulator.hasNextPage == false)
    }

    private func response(
        items: [TestItem],
        nextCursor: String?
    ) -> PaginatedResponse<TestItem> {
        PaginatedResponse(
            items: items,
            meta: PaginationMeta(
                limit: 2,
                hasNextPage: nextCursor != nil,
                hasPrevPage: false,
                nextCursor: nextCursor,
                prevCursor: nil
            )
        )
    }
}

private struct TestItem: Codable, Identifiable, Sendable {
    let id: String
}
