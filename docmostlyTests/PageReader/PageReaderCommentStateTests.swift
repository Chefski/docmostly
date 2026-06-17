import Foundation
import Testing
@testable import docmostly

@MainActor
struct PageReaderCommentStateTests {
    @Test func appliesUpdatedCommentWithoutChangingListOrder() throws {
        let viewModel = PageReaderViewModel()
        viewModel.comments = [
            try comment(id: "comment-1", text: "Open", resolvedAt: nil),
            try comment(id: "comment-2", text: "Needs decision", resolvedAt: nil)
        ]

        let resolvedAt = "2026-06-17T10:05:00.000Z"
        let updatedComment = try comment(id: "comment-2", text: "Needs decision", resolvedAt: resolvedAt)
        let expectedResolvedAt = try resolvedDate(resolvedAt)

        viewModel.applyUpdatedComment(updatedComment)

        #expect(viewModel.comments.map(\.id) == ["comment-1", "comment-2"])
        #expect(viewModel.comments[1].resolvedAt == expectedResolvedAt)
    }

    @Test func removesDeletedCommentByID() throws {
        let viewModel = PageReaderViewModel()
        viewModel.comments = [
            try comment(id: "comment-1", text: "Keep", resolvedAt: nil),
            try comment(id: "comment-2", text: "Delete", resolvedAt: nil)
        ]

        viewModel.removeComment(id: "comment-2")

        #expect(viewModel.comments.map(\.id) == ["comment-1"])
    }

    @Test func createdCommentIsPrependedOnce() throws {
        let viewModel = PageReaderViewModel()
        let existingComment = try comment(id: "comment-1", text: "Existing", resolvedAt: nil)
        let newComment = try comment(id: "comment-2", text: "New", resolvedAt: nil)
        viewModel.comments = [existingComment]

        viewModel.applyCreatedComment(newComment)
        viewModel.applyCreatedComment(newComment)

        #expect(viewModel.comments.map(\.id) == ["comment-2", "comment-1"])
    }

    private func comment(id: String, text: String, resolvedAt: String?) throws -> DocmostComment {
        let resolvedAtJSON = resolvedAt.map { "\"\($0)\"" } ?? "null"
        let data = Data("""
        {
          "id": "\(id)",
          "content": "\(text)",
          "selection": null,
          "type": "page",
          "creatorId": "user-1",
          "pageId": "page-1",
          "parentCommentId": null,
          "resolvedById": null,
          "resolvedAt": \(resolvedAtJSON),
          "workspaceId": "workspace-1",
          "createdAt": "2026-06-17T09:00:00.000Z",
          "editedAt": null,
          "deletedAt": null,
          "creator": {
            "id": "user-1",
            "name": "Chefling",
            "email": "chefling@example.com"
          }
        }
        """.utf8)

        return try DocmostJSONDecoder.make().decode(DocmostComment.self, from: data)
    }

    private func resolvedDate(_ value: String) throws -> Date {
        try Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}
