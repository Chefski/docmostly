import Foundation
import Testing
@testable import docmostly

struct NativeEditorCollaborationScopeTests {
    @Test func readOnlyScopesAllowPresenceAwarenessBroadcasts() {
        #expect(NativeEditorCollaborationScope.readWrite.allowsLocalAwarenessUpdates == true)
        #expect(NativeEditorCollaborationScope.readonly.allowsLocalAwarenessUpdates == true)
        #expect(NativeEditorCollaborationScope.unknown.allowsLocalAwarenessUpdates == false)
    }
}
