import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollaborationTests {
    @Test func buildsCollaborationWebSocketURLFromServerURL() throws {
        let secureURL = try NativeEditorCollaborationEndpoint.webSocketURL(
            serverBaseURL: #require(URL(string: "https://docs.example.com"))
        )
        let insecureURL = try NativeEditorCollaborationEndpoint.webSocketURL(
            serverBaseURL: #require(URL(string: "http://localhost:3000/api"))
        )

        #expect(secureURL.absoluteString == "wss://docs.example.com/collab")
        #expect(insecureURL.absoluteString == "ws://localhost:3000/collab")
    }

    @Test func buildsRealtimeEventSocketURLFromServerURL() throws {
        let secureURL = try NativeEditorRealtimeEventEndpoint.webSocketURL(
            serverBaseURL: #require(URL(string: "https://docs.example.com/api"))
        )

        #expect(
            secureURL.absoluteString == "wss://docs.example.com/socket.io/?EIO=4&transport=websocket"
        )
    }

    @Test func parsesSocketIOPageUpdateMessageEvent() throws {
        let frame = """
        42[
          "message",
          {
            "operation": "updateOne",
            "spaceId": "space-1",
            "entity": ["pages"],
            "id": "page-1",
            "payload": {
              "title": "Remote",
              "updatedAt": "2026-06-17T10:05:00.000Z"
            }
          }
        ]
        """

        let parsedFrame = try NativeEditorRealtimeSocketFrame.parse(frame)
        guard case .event(.pageUpdated(let event)) = parsedFrame else {
            Issue.record("Expected a page update event")
            return
        }

        #expect(event.pageID == "page-1")
        #expect(event.spaceID == "space-1")
        #expect(event.title == "Remote")
        let expectedDate = try Date(
            "2026-06-17T10:05:00.000Z",
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        )
        #expect(event.updatedAt == expectedDate)
    }

    @Test func parsesSocketIOCommentCreatedMessageEvent() throws {
        let frame = """
        42[
          "message",
          {
            "operation": "commentCreated",
            "pageId": "page-1",
            "comment": {
              "id": "comment-1",
              "content": {
                "type": "doc",
                "content": [
                  {
                    "type": "paragraph",
                    "content": [
                      { "type": "text", "text": "Looks good" }
                    ]
                  }
                ]
              },
              "selection": "Selected",
              "type": "inline",
              "creatorId": "user-1",
              "pageId": "page-1",
              "parentCommentId": null,
              "resolvedById": null,
              "resolvedAt": null,
              "workspaceId": "workspace-1",
              "createdAt": "2026-06-17T10:05:00.000Z",
              "editedAt": null,
              "deletedAt": null,
              "creator": {
                "id": "user-1",
                "name": "Chefling",
                "email": "chef@example.com"
              }
            }
          }
        ]
        """

        let parsedFrame = try NativeEditorRealtimeSocketFrame.parse(frame)
        guard case .event(.commentCreated(let event)) = parsedFrame else {
            Issue.record("Expected a comment created event")
            return
        }

        #expect(event.pageID == "page-1")
        #expect(event.comment.id == "comment-1")
        #expect(event.comment.content == "Looks good")
        #expect(event.comment.type == "inline")
    }

    @Test func parsesEngineIOControlFrames() throws {
        #expect(try NativeEditorRealtimeSocketFrame.parse("2") == .ping)
        #expect(try NativeEditorRealtimeSocketFrame.parse("40") == .connected)
        #expect(NativeEditorRealtimeSocketFrame.connectMessage == "40")
        #expect(NativeEditorRealtimeSocketFrame.pongMessage == "3")
    }

    @Test func appliesRemoteSnapshotWhenEditorIsClean() {
        let viewModel = configuredViewModel()
        let remotePage = editablePage(
            title: "Remote",
            text: "Remote body",
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        viewModel.handleRemotePageSnapshot(remotePage)

        #expect(viewModel.title == "Remote")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Remote body")
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func defersRemoteSnapshotWhenLocalEditorIsDirty() {
        let viewModel = configuredViewModel()
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()

        let remotePage = editablePage(
            title: "Remote",
            text: "Remote body",
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        viewModel.handleRemotePageSnapshot(remotePage)

        #expect(viewModel.title == "Local")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.pendingRemoteUpdate?.updatedAt == remotePage.updatedAt)
        #expect(viewModel.realtimeStatus == .conflict)
    }

    @Test func acceptsPendingRemoteSnapshotAfterConflict() {
        let viewModel = configuredViewModel()
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()

        viewModel.handleRemotePageSnapshot(editablePage(
            title: "Remote",
            text: "Remote body",
            updatedAt: Date(timeIntervalSince1970: 20)
        ))
        viewModel.acceptPendingRemoteUpdate()

        #expect(viewModel.title == "Remote")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Remote body")
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.isDirty == false)
    }

    private func configuredViewModel() -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Local")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Local body"), alignment: .left)
        ])
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        viewModel.resetEditingHistory()
        return viewModel
    }

    private func editablePage(title: String, text: String, updatedAt: Date) -> DocmostEditablePage {
        DocmostEditablePage(
            id: "page-1",
            slugId: "slug-1",
            title: title,
            content: ProseMirrorDocument(content: [
                ProseMirrorNode(type: "paragraph", content: [
                    ProseMirrorNode(type: "text", text: text)
                ])
            ]),
            icon: nil,
            spaceId: "space-1",
            updatedAt: updatedAt,
            permissions: nil
        )
    }
}
