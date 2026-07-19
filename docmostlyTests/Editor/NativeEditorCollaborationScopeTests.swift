import Foundation
import Testing
@testable import docmostly

struct NativeEditorCollaborationScopeTests {
    @Test func readOnlyScopesAllowPresenceAwarenessBroadcasts() {
        #expect(NativeEditorCollaborationScope.readWrite.allowsLocalAwarenessUpdates == true)
        #expect(NativeEditorCollaborationScope.readonly.allowsLocalAwarenessUpdates == true)
        #expect(NativeEditorCollaborationScope.unknown.allowsLocalAwarenessUpdates == false)
    }

    @Test func receiveOnlyParticipationDisablesLocalSendersButKeepsInboundSync() throws {
        let context = NativeEditorCollaborationSessionContext(
            url: try #require(URL(string: "wss://docs.example.com/collab")),
            token: "token",
            documentName: "page.page-1",
            participation: .receiveOnly,
            user: nil,
            syncDriver: nil,
            localAwarenessCursor: nil,
            localAwarenessUpdates: nil
        )

        #expect(context.allowsInitialDocumentSync(for: .readWrite))
        #expect(context.allowsLocalAwarenessUpdates(for: .readWrite) == false)
        #expect(context.allowsLocalDocumentUpdates(for: .readWrite) == false)
        #expect(context.allowsSyncReply(to: .stepOne(Data([1])), authenticatedScope: .readWrite) == false)
        #expect(context.allowsSyncReply(to: .stepTwo(Data([2])), authenticatedScope: .readWrite))
        #expect(context.allowsSyncReply(to: .update(Data([3])), authenticatedScope: .readWrite))
    }

    @Test func interactiveParticipationStartsLocalSendersWhenScopePermits() throws {
        let context = NativeEditorCollaborationSessionContext(
            url: try #require(URL(string: "wss://docs.example.com/collab")),
            token: "token",
            documentName: "page.page-1",
            participation: .interactive,
            user: nil,
            syncDriver: nil,
            localAwarenessCursor: nil,
            localAwarenessUpdates: nil
        )

        #expect(context.allowsInitialDocumentSync(for: .readWrite))
        #expect(context.allowsLocalAwarenessUpdates(for: .readWrite))
        #expect(context.allowsLocalDocumentUpdates(for: .readWrite))
        #expect(context.allowsSyncReply(to: .stepOne(Data([1])), authenticatedScope: .readWrite))
        #expect(context.allowsLocalDocumentUpdates(for: .readonly) == false)
        #expect(context.allowsLocalAwarenessUpdates(for: .unknown) == false)
    }
}
