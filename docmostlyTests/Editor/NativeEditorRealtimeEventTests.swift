import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorRealtimeEventTests {
    @Test func buildsRealtimeEventSocketURLFromServerURL() throws {
        let secureURL = try NativeEditorRealtimeEventEndpoint.webSocketURL(
            serverBaseURL: #require(URL(string: "https://docs.example.com/docmost"))
        )

        #expect(
            secureURL.absoluteString == "wss://docs.example.com/docmost/socket.io/?EIO=4&transport=websocket"
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
              "updatedAt": "2026-06-17T10:05:00.000Z",
              "lastUpdatedBy": {
                "id": "user-2",
                "name": "Remote Editor",
                "avatarUrl": null
              }
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
        #expect(event.lastUpdatedBy?.name == "Remote Editor")
    }

    @Test func parsesSocketIOTitleEditorUpdateWithoutUpdatedAt() throws {
        let frame = """
        42[
          "message",
          {
            "operation": "updateOne",
            "spaceId": "space-1",
            "entity": ["pages"],
            "id": "page-1",
            "payload": {
              "title": "Renamed",
              "slugId": "renamed-abc",
              "parentPageId": null,
              "icon": null
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
        #expect(event.title == "Renamed")
        #expect(event.slugID == "renamed-abc")
        #expect(event.updatedAt == nil)
        #expect(event.lastUpdatedBy == nil)
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

    @Test func parsesSocketIOPageDeletedTreeMessageEvent() throws {
        let frame = """
        42[
          "message",
          {
            "operation": "deleteTreeNode",
            "spaceId": "space-1",
            "payload": {
              "node": {
                "id": "page-1",
                "slugId": "deleted-page-abc",
                "title": "Deleted page"
              }
            }
          }
        ]
        """

        let parsedFrame = try NativeEditorRealtimeSocketFrame.parse(frame)
        guard case .event(.pageDeleted(let event)) = parsedFrame else {
            Issue.record("Expected a page deleted event")
            return
        }

        #expect(event.pageID == "page-1")
        #expect(event.spaceID == "space-1")
    }

    @Test func parsesEngineIOControlFrames() throws {
        #expect(try NativeEditorRealtimeSocketFrame.parse("2") == .ping)
        #expect(try NativeEditorRealtimeSocketFrame.parse("40") == .connected)
        #expect(try NativeEditorRealtimeSocketFrame.parse("40{\"sid\":\"socket-1\"}") == .connected)
        #expect(try NativeEditorRealtimeSocketFrame.parse("41") == .disconnected)
        #expect(NativeEditorRealtimeSocketFrame.connectMessage == "40")
        #expect(NativeEditorRealtimeSocketFrame.pongMessage == "3")
    }

    @Test func parsesSocketIOUnauthorizedEvent() throws {
        #expect(try NativeEditorRealtimeSocketFrame.parse("42[\"Unauthorized\"]") == .unauthorized)
    }

    @Test func backsOffRealtimeReconnectAttemptsAndCanReset() {
        var policy = NativeEditorRealtimeReconnectPolicy()

        #expect(policy.nextDelaySeconds() == 1)
        #expect(policy.nextDelaySeconds() == 2)
        #expect(policy.nextDelaySeconds() == 5)

        policy.reset()

        #expect(policy.nextDelaySeconds() == 1)
    }

    @Test func realtimeSocketRequestUsesExplicitActiveCookiesOnly() throws {
        let url = try #require(URL(string: "wss://docs.example.com/socket.io/?EIO=4&transport=websocket"))
        let cookies = [
            StoredHTTPCookie(
                name: "authToken",
                value: "secret",
                domain: "docs.example.com",
                path: "/",
                expiresAt: nil,
                isSecure: true,
                isHTTPOnly: true
            )
        ]

        let request = NativeEditorRealtimeEventClient.webSocketRequest(url: url, cookies: cookies)

        #expect(request.value(forHTTPHeaderField: "Cookie") == "authToken=secret")
        #expect(request.httpShouldHandleCookies == false)
    }

    @Test func rejectsOversizedSocketIOFramesBeforeParsing() {
        let oversized = String(
            repeating: "a",
            count: NativeEditorRealtimeSocketFrame.maximumFrameCharacters + 1
        )

        #expect(throws: NativeEditorRealtimeSocketFrameError.frameTooLarge) {
            _ = try NativeEditorRealtimeSocketFrame.parse(oversized)
        }
    }
}
