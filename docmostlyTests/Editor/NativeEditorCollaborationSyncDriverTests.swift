import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollaborationSyncDriverTests {
    @Test func sessionSyncAcknowledgementCoversTheWholeInitialBatch() async throws {
        let updates = [Data([1]), Data([2])]
        let acknowledgements = SyncAcknowledgementRecorder()
        let coordinator = NativeEditorCRDTSyncCoordinator(
            documentEngine: SessionTestDocumentEngine(),
            pendingLocalUpdatesProvider: { updates },
            localUpdateDidAcknowledge: { update in
                await acknowledgements.append(update)
            }
        )
        let driver = NativeEditorCollaborationSyncDriver(documentName: "page.page-1", coordinator: coordinator)

        #expect(try await driver.outboundFramesAfterAuthentication().count == 3)
        try await driver.didSendOutboundFramesAfterAuthentication()
        try await driver.didReceiveSyncAcknowledgement()

        #expect(await acknowledgements.updates == updates)
    }

    @Test func sessionSyncAcknowledgementDoesNotCoverALiveUpdate() async throws {
        let initialUpdate = Data([1])
        let liveUpdate = Data([2])
        let acknowledgements = SyncAcknowledgementRecorder()
        let coordinator = NativeEditorCRDTSyncCoordinator(
            documentEngine: SessionTestDocumentEngine(),
            pendingLocalUpdatesProvider: { [initialUpdate] },
            localUpdateDidAcknowledge: { update in
                await acknowledgements.append(update)
            }
        )
        let driver = NativeEditorCollaborationSyncDriver(documentName: "page.page-1", coordinator: coordinator)

        #expect(try await driver.outboundFramesAfterAuthentication().count == 2)
        try await driver.didSendOutboundFramesAfterAuthentication()
        #expect(await driver.outboundFrameIfNeeded(forLocalUpdate: liveUpdate) != nil)
        try await driver.didReceiveSyncAcknowledgement()

        #expect(await acknowledgements.updates == [initialUpdate])
    }

    @Test func preSubscribedLocalStreamDoesNotDuplicateAnUpdateInTheInitialBatch() async throws {
        let persistedUpdates = PersistedSyncUpdateStore()
        let coordinator = NativeEditorCRDTSyncCoordinator(
            documentEngine: SessionTestDocumentEngine(),
            localUpdateCommitter: { update in
                await persistedUpdates.append(update)
                return true
            },
            pendingLocalUpdatesProvider: {
                await persistedUpdates.updates
            }
        )
        let driver = NativeEditorCollaborationSyncDriver(documentName: "page.page-1", coordinator: coordinator)
        let stream = await driver.localUpdates()
        var iterator = stream.makeAsyncIterator()

        try await coordinator.integrateLocalChange(localChange())
        #expect(try await driver.outboundFramesAfterAuthentication().count == 2)
        try await driver.didSendOutboundFramesAfterAuthentication()
        let bufferedUpdate = try #require(await iterator.next())

        #expect(await driver.outboundFrameIfNeeded(forLocalUpdate: bufferedUpdate) == nil)
    }

    @Test func cancelledPreAuthenticationSubscriptionStopsBufferingLocalUpdates() async throws {
        let coordinator = NativeEditorCRDTSyncCoordinator(
            documentEngine: SessionTestDocumentEngine()
        )
        let driver = NativeEditorCollaborationSyncDriver(documentName: "page.page-1", coordinator: coordinator)
        let subscription = await driver.localUpdateSubscription()

        await subscription.cancel()
        try await coordinator.integrateLocalChange(localChange())
        var iterator = subscription.updates.makeAsyncIterator()

        #expect(await iterator.next() == nil)
    }

    private func localChange() -> NativeEditorCRDTLocalChange {
        let snapshot = NativeEditorHistorySnapshot(
            title: "Page",
            document: NativeEditorDocument(),
            activeBlockID: nil,
            selectedBlockID: nil,
            visibleBlockControlsID: nil,
            isTitleFocused: false
        )
        return NativeEditorCRDTLocalChange(before: snapshot, after: snapshot)
    }
}

private actor SyncAcknowledgementRecorder {
    private(set) var updates: [Data] = []

    func append(_ update: Data) {
        updates.append(update)
    }
}

private actor PersistedSyncUpdateStore {
    private(set) var updates: [Data] = []

    func append(_ update: Data) {
        updates.append(update)
    }
}
