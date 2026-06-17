import Foundation
import Testing
@testable import docmostly

struct NativeEditorCollaborationScopeTests {
    @Test func readOnlyScopesDoNotAllowLocalAwarenessBroadcasts() {
        #expect(NativeEditorCollaborationScope.readWrite.allowsLocalAwarenessUpdates == true)
        #expect(NativeEditorCollaborationScope.readonly.allowsLocalAwarenessUpdates == false)
        #expect(NativeEditorCollaborationScope.unknown.allowsLocalAwarenessUpdates == false)
    }
}
