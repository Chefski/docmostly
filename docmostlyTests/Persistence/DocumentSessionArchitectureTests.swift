import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
// swiftlint:disable:next type_body_length
struct DocumentSessionArchitectureTests {
    @Test func cleanReopenReplaysDurableUpdatesBeforeRemoteSync() async throws {
        let dependencies = makeDependencies()
        let update = Data("offline-edit".utf8)
        _ = try await dependencies.peer.append(update, origin: .local, key: dependencies.key)

        let registry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )
        let session = try await registry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )

        #expect(session.restoredLocalState)
        #expect(dependencies.factory.engines.last?.appliedUpdates == [update])
        #expect(session.initialSnapshot != nil)
    }

    @Test func documentStoreIdentityIncludesVersionWorkspaceUserAndPage() async throws {
        let dependencies = makeDependencies()
        let update = Data("scoped-update".utf8)
        _ = try await dependencies.peer.append(update, origin: .local, key: dependencies.key)

        let otherKeys = [
            DocumentStoreKey(
                schemaVersion: dependencies.key.schemaVersion + 1,
                serverBaseURL: dependencies.key.serverBaseURL,
                userID: dependencies.key.userID,
                workspaceID: dependencies.key.workspaceID,
                pageID: dependencies.key.pageID
            ),
            DocumentStoreKey(
                serverBaseURL: dependencies.key.serverBaseURL,
                userID: "user-2",
                workspaceID: dependencies.key.workspaceID,
                pageID: dependencies.key.pageID
            ),
            DocumentStoreKey(
                serverBaseURL: dependencies.key.serverBaseURL,
                userID: dependencies.key.userID,
                workspaceID: "workspace-2",
                pageID: dependencies.key.pageID
            ),
            DocumentStoreKey(
                serverBaseURL: dependencies.key.serverBaseURL,
                userID: dependencies.key.userID,
                workspaceID: dependencies.key.workspaceID,
                pageID: "page-2"
            )
        ]

        for key in otherKeys {
            #expect(try await dependencies.peer.load(key).updates.isEmpty)
        }
        #expect(try await dependencies.peer.load(dependencies.key).updates.map(\.payload) == [update])
    }

    @Test func manyOfflineEditsRemainOrderedAndPending() async throws {
        let dependencies = makeDependencies()
        let indexer = RecordingDocumentUpdateIndexer()
        let registry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory,
            indexer: indexer,
            compactionPolicy: DocumentCompactionPolicy(updateCount: 20, byteCount: .max)
        )
        let session = try await registry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )
        let coordinator = try #require(session.syncCoordinator)

        for index in 0..<250 {
            try await coordinator.integrateLocalChange(localChange(title: "Edit \(index)"))
        }

        let pending = try await dependencies.peer.pendingLocalUpdates(dependencies.key)
        #expect(pending.count == 250)
        #expect(pending.map(\.sequence) == Array(1...250).map(Int64.init))
        #expect(await indexer.count == 250)
    }

    @Test func localUpdatesArePersistedBeforeTheSocketCanObserveThem() async throws {
        let engine = SessionTestDocumentEngine()
        let events = DocumentSessionTestEventLog()
        let coordinator = NativeEditorCRDTSyncCoordinator(
            documentEngine: engine,
            localUpdateCommitter: { update in
                let value = String(bytes: update, encoding: .utf8) ?? ""
                await events.append("persist:\(value)")
                return true
            }
        )
        let stream = await coordinator.localUpdates()
        let sender = Task {
            for await update in stream {
                let value = String(bytes: update, encoding: .utf8) ?? ""
                await events.append("send:\(value)")
                return
            }
        }

        try await coordinator.integrateLocalChange(localChange(title: "ordered"))
        await sender.value

        #expect(await events.entries == ["persist:local-1", "send:local-1"])
    }

    @Test func duplicateAndReorderedRemoteUpdatesCommitAndApplyExactlyOnce() async throws {
        let dependencies = makeDependencies()
        let registry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )
        let session = try await registry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )
        let coordinator = try #require(session.syncCoordinator)
        let first = Data("remote-first".utf8)
        let second = Data("remote-second".utf8)

        _ = try await coordinator.receive(.update(second))
        _ = try await coordinator.receive(.update(first))
        _ = try await coordinator.receive(.update(second))

        let state = try await dependencies.peer.load(dependencies.key)
        #expect(state.updates.map(\.payload) == [second, first])
        #expect(dependencies.factory.engines.last?.appliedUpdates == [second, first])
    }

    @Test func reconnectResendsOnlyUnacknowledgedLocalUpdates() async throws {
        let dependencies = makeDependencies()
        let update = Data("pending-send".utf8)
        _ = try await dependencies.peer.append(update, origin: .local, key: dependencies.key)
        let registry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )
        let session = try await registry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )
        let driver = NativeEditorCollaborationSyncDriver(
            documentName: "page.\(dependencies.key.pageID)",
            coordinator: try #require(session.syncCoordinator)
        )

        #expect(try await driver.outboundFramesAfterAuthentication().count == 2)
        #expect(try await dependencies.peer.pendingLocalUpdates(dependencies.key).count == 1)
        try await driver.didSendOutboundFramesAfterAuthentication()
        #expect(try await dependencies.peer.pendingLocalUpdates(dependencies.key).count == 1)
        try await driver.didReceiveSyncAcknowledgement()
        #expect(try await dependencies.peer.pendingLocalUpdates(dependencies.key).isEmpty)
        #expect(try await driver.outboundFramesAfterAuthentication().count == 1)
    }

    @Test func twoWindowsResolveToOneAuthoritativeSession() async throws {
        let dependencies = makeDependencies()
        let registry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )

        let firstSession = try await registry.session(
            for: dependencies.key,
            title: "First window",
            document: NativeEditorDocument()
        )
        let secondSession = try await registry.session(
            for: dependencies.key,
            title: "Second window",
            document: NativeEditorDocument()
        )

        #expect(firstSession === secondSession)
        #expect(dependencies.factory.engines.count == 1)
        let snapshots = secondSession.snapshots()
        let nextProjection = Task<NativeEditorCRDTDocumentSnapshot?, Never> {
            for await snapshot in snapshots {
                return snapshot
            }
            return nil
        }
        let coordinator = try #require(firstSession.syncCoordinator)
        try await coordinator.integrateLocalChange(localChange(title: "Edited in first window"))
        #expect(await nextProjection.value != nil)

        let lateSnapshots = secondSession.snapshots()
        var lateIterator = lateSnapshots.makeAsyncIterator()
        #expect(await lateIterator.next() == secondSession.initialSnapshot)
    }

    @Test func restartDuringSyncRetainsAnUnacknowledgedUpdate() async throws {
        let dependencies = makeDependencies()
        let update = Data("crash-window".utf8)
        _ = try await dependencies.peer.append(update, origin: .local, key: dependencies.key)

        let restartedPeer = DocumentLocalPersistencePeer(modelContainer: dependencies.container)
        #expect(try await restartedPeer.pendingLocalUpdates(dependencies.key).map(\.payload) == [update])
        try await restartedPeer.markPushed(update, key: dependencies.key)
        #expect(try await restartedPeer.pendingLocalUpdates(dependencies.key).isEmpty)
    }

    @Test func corruptPrimarySnapshotRecoversFromTheLastCommittedRecoverySnapshot() async throws {
        let dependencies = makeDependencies()
        let update = Data("remote".utf8)
        _ = try await dependencies.peer.append(update, origin: .remote, key: dependencies.key)
        try await dependencies.peer.compact(dependencies.key, snapshot: Data("valid-state".utf8), through: 1)
        try corruptPrimarySnapshot(in: dependencies.container, key: dependencies.key)

        let registry = DocumentSessionRegistry(
            localPeer: DocumentLocalPersistencePeer(modelContainer: dependencies.container),
            engineFactory: dependencies.factory
        )
        let session = try await registry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )

        #expect(session.restoredLocalState)
        #expect(dependencies.factory.engines.last?.appliedUpdates == [Data("valid-state".utf8)])
    }

    @Test func legacyDocumentMigrationSeedsExactlyOnceAndLeavesOnlyMetadataQueued() async throws {
        let dependencies = makeDependencies()
        let scope = CacheScope(
            serverBaseURL: dependencies.key.serverBaseURL,
            userID: dependencies.key.userID
        )
        let legacyDocument = ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [
                ProseMirrorNode(type: "text", text: "Offline draft")
            ])
        ])
        let context = ModelContext(dependencies.container)
        context.insert(CachedCRDTDocument(
            pageId: dependencies.key.pageID,
            stateUpdate: Data("older-cache".utf8),
            scope: scope
        ))
        let queue = OfflineMutationQueue(context: context)
        _ = try queue.enqueue(
            .updatePage(
                pageId: dependencies.key.pageID,
                title: "Offline title",
                document: legacyDocument,
                baseTitle: "Server title"
            ),
            scope: scope
        )

        let firstRegistry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )
        _ = try await firstRegistry.session(
            for: dependencies.key,
            title: "Server title",
            document: NativeEditorDocument()
        )
        let firstState = try await dependencies.peer.load(dependencies.key)
        let pendingRecords = try OfflineMutationQueue(
            context: ModelContext(dependencies.container)
        ).pending(scope: scope)
        #expect(firstState.migrationVersion == DocumentLocalPersistencePeer.migrationVersion)
        #expect(firstState.lastCommittedSequence == 1)
        #expect(pendingRecords.count == 1)
        guard case .updatePageMetadata(let pageID, let title, _) = pendingRecords.first?.payload else {
            Issue.record("Expected a metadata-only page mutation after migration")
            return
        }
        #expect(pageID == dependencies.key.pageID)
        #expect(title == "Offline title")

        let secondRegistry = DocumentSessionRegistry(
            localPeer: DocumentLocalPersistencePeer(modelContainer: dependencies.container),
            engineFactory: dependencies.factory
        )
        _ = try await secondRegistry.session(
            for: dependencies.key,
            title: "Server title",
            document: NativeEditorDocument()
        )
        let secondState = try await dependencies.peer.load(dependencies.key)
        #expect(secondState.lastCommittedSequence == 1)
    }

    @Test func legacyFullStateCacheBecomesTheSnapshotWithoutDoubleSeeding() async throws {
        let dependencies = makeDependencies()
        let scope = CacheScope(
            serverBaseURL: dependencies.key.serverBaseURL,
            userID: dependencies.key.userID
        )
        let cachedState = Data("cached-full-state".utf8)
        let context = ModelContext(dependencies.container)
        context.insert(CachedCRDTDocument(
            pageId: dependencies.key.pageID,
            stateUpdate: cachedState,
            scope: scope
        ))
        try context.save()

        let firstRegistry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )
        _ = try await firstRegistry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )
        let migrated = try await dependencies.peer.load(dependencies.key)
        #expect(migrated.snapshot == cachedState)
        #expect(migrated.updates.isEmpty)
        #expect(migrated.migrationVersion == DocumentLocalPersistencePeer.migrationVersion)

        let secondRegistry = DocumentSessionRegistry(
            localPeer: DocumentLocalPersistencePeer(modelContainer: dependencies.container),
            engineFactory: dependencies.factory
        )
        _ = try await secondRegistry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )
        let reopened = try await dependencies.peer.load(dependencies.key)
        #expect(reopened.snapshot == cachedState)
        #expect(reopened.lastCommittedSequence == 0)
    }

    @Test func retainedConflictDraftPromotesToADurableYjsUpdateOnReopen() async throws {
        let dependencies = makeDependencies()
        let retainedDocument = ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [
                ProseMirrorNode(type: "text", text: "Keep this local draft")
            ])
        ])
        _ = try await dependencies.peer.append(
            Data("remote-base-update".utf8),
            origin: .remote,
            key: dependencies.key
        )
        try await dependencies.peer.compact(
            dependencies.key,
            snapshot: Data("remote-base-snapshot".utf8),
            through: 1
        )
        try await dependencies.peer.retainDraft(
            retainedDocument,
            title: "Retained title",
            key: dependencies.key
        )

        let registry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )
        _ = try await registry.session(
            for: dependencies.key,
            title: "Remote title",
            document: NativeEditorDocument()
        )

        let reopened = try await dependencies.peer.load(dependencies.key)
        #expect(reopened.retainedDraft == nil)
        #expect(reopened.retainedDraftTitle == nil)
        #expect(reopened.lastCommittedSequence == 2)
        #expect(reopened.updates.map(\.origin) == [.local])
        #expect(reopened.updates.map(\.payload) == [Data("local-1".utf8)])
    }

    @Test func legacyProseMirrorDraftWaitsForARemoteBaseBeforeYjsPromotion() async throws {
        let dependencies = makeDependencies()
        let scope = CacheScope(
            serverBaseURL: dependencies.key.serverBaseURL,
            userID: dependencies.key.userID
        )
        let legacyDocument = ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [
                ProseMirrorNode(type: "text", text: "Unsynced legacy draft")
            ])
        ])
        let queue = OfflineMutationQueue(context: ModelContext(dependencies.container))
        _ = try queue.enqueue(
            .updatePage(
                pageId: dependencies.key.pageID,
                title: "Legacy title",
                document: legacyDocument,
                baseTitle: "Remote title"
            ),
            scope: scope
        )
        let registry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )
        let session = try await registry.session(
            for: dependencies.key,
            title: "Remote title",
            document: NativeEditorDocument()
        )

        let beforeRemoteSync = try await dependencies.peer.load(dependencies.key)
        #expect(beforeRemoteSync.lastCommittedSequence == 0)
        #expect(beforeRemoteSync.retainedDraft == legacyDocument)
        #expect(session.initialSnapshot?.document.proseMirrorDocument == legacyDocument)
        let viewModel = NativeRichEditorViewModel(pageID: dependencies.key.pageID, initialTitle: "Remote title")
        viewModel.configureDocumentSession(session, restoredLocalState: session.restoredLocalState)
        #expect(viewModel.canEdit == false)

        _ = try await #require(session.syncCoordinator).receive(.update(Data("remote-base".utf8)))

        let afterRemoteSync = try await dependencies.peer.load(dependencies.key)
        #expect(afterRemoteSync.retainedDraft == nil)
        #expect(afterRemoteSync.lastCommittedSequence == 2)
        #expect(afterRemoteSync.updates.map(\.origin) == [.remote, .local])
        #expect(try await dependencies.peer.pendingLocalUpdates(dependencies.key).count == 1)
    }

    @Test func crashBeforeCompactionCommitPreservesTheReplayableUpdateLog() async throws {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let key = Self.makeKey()
        let failingPeer = DocumentLocalPersistencePeer(
            modelContainer: container,
            compactionFaultInjector: FailingDocumentCompactionFaultInjector()
        )
        let update = Data("last-valid-update".utf8)
        _ = try await failingPeer.append(update, origin: .remote, key: key)

        await #expect(throws: DocumentSessionTestError.self) {
            try await failingPeer.compact(key, snapshot: Data("new-snapshot".utf8), through: 1)
        }

        let restartedPeer = DocumentLocalPersistencePeer(modelContainer: container)
        let state = try await restartedPeer.load(key)
        #expect(state.snapshot == nil)
        #expect(state.updates.map(\.payload) == [update])
    }
}

extension DocumentSessionArchitectureTests {
    @Test func receiveOnlyAuthenticationDoesNotUploadOrAcknowledgePendingUpdates() async throws {
        let dependencies = makeDependencies()
        let update = Data("private-draft".utf8)
        _ = try await dependencies.peer.append(update, origin: .local, key: dependencies.key)
        let registry = DocumentSessionRegistry(
            localPeer: dependencies.peer,
            engineFactory: dependencies.factory
        )
        let session = try await registry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )
        let driver = NativeEditorCollaborationSyncDriver(
            documentName: "page.\(dependencies.key.pageID)",
            coordinator: try #require(session.syncCoordinator)
        )

        let frames = try await driver.outboundFramesAfterAuthentication(includePendingLocalUpdates: false)
        try await driver.didSendOutboundFramesAfterAuthentication()

        #expect(frames.count == 1)
        #expect(try await dependencies.peer.pendingLocalUpdates(dependencies.key).map(\.payload) == [update])
    }

    @Test func laterCompactionKeepsThePreviousSnapshotAndReplayTailForRecovery() async throws {
        let dependencies = makeDependencies()
        let firstUpdate = Data("first-remote".utf8)
        let secondUpdate = Data("second-local".utf8)
        _ = try await dependencies.peer.append(firstUpdate, origin: .remote, key: dependencies.key)
        try await dependencies.peer.compact(
            dependencies.key,
            snapshot: Data("snapshot-one".utf8),
            through: 1
        )
        _ = try await dependencies.peer.append(secondUpdate, origin: .local, key: dependencies.key)
        try await dependencies.peer.compact(
            dependencies.key,
            snapshot: Data("snapshot-two".utf8),
            through: 2
        )

        let compacted = try await dependencies.peer.load(dependencies.key)
        #expect(compacted.recoverySnapshot == Data("snapshot-one".utf8))
        #expect(compacted.recoverySnapshotSequence == 1)
        #expect(compacted.updates.map(\.payload) == [secondUpdate])

        try corruptPrimarySnapshot(in: dependencies.container, key: dependencies.key)
        let registry = DocumentSessionRegistry(
            localPeer: DocumentLocalPersistencePeer(modelContainer: dependencies.container),
            engineFactory: dependencies.factory
        )
        _ = try await registry.session(
            for: dependencies.key,
            title: "Page",
            document: NativeEditorDocument()
        )

        #expect(dependencies.factory.engines.last?.appliedUpdates == [
            Data("snapshot-one".utf8),
            secondUpdate
        ])
    }

    @Test func acknowledgedCompactedPayloadIsReleasedOnceBothSnapshotsCoverIt() async throws {
        let dependencies = makeDependencies()
        let update = Data("local".utf8)
        _ = try await dependencies.peer.append(update, origin: .local, key: dependencies.key)
        try await dependencies.peer.compact(dependencies.key, snapshot: Data("one".utf8), through: 1)
        try await dependencies.peer.compact(dependencies.key, snapshot: Data("two".utf8), through: 1)

        try await dependencies.peer.markPushed(update, key: dependencies.key)

        #expect(try await dependencies.peer.load(dependencies.key).updates.isEmpty)
    }
}

@MainActor
private extension DocumentSessionArchitectureTests {
    struct Dependencies {
        let container: ModelContainer
        let peer: DocumentLocalPersistencePeer
        let factory: SessionTestDocumentEngineFactory
        let key: DocumentStoreKey
    }

    func makeDependencies() -> Dependencies {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        return Dependencies(
            container: container,
            peer: DocumentLocalPersistencePeer(modelContainer: container),
            factory: SessionTestDocumentEngineFactory(),
            key: Self.makeKey()
        )
    }

    static func makeKey() -> DocumentStoreKey {
        DocumentStoreKey(
            serverBaseURL: "https://docs.example.com",
            userID: "user-1",
            workspaceID: "workspace-1",
            pageID: "page-1"
        )
    }

    func localChange(title: String) -> NativeEditorCRDTLocalChange {
        let before = NativeEditorHistorySnapshot(
            title: "Before",
            document: NativeEditorDocument(),
            activeBlockID: nil,
            selectedBlockID: nil,
            visibleBlockControlsID: nil,
            isTitleFocused: false
        )
        let after = NativeEditorHistorySnapshot(
            title: title,
            document: NativeEditorDocument(),
            activeBlockID: nil,
            selectedBlockID: nil,
            visibleBlockControlsID: nil,
            isTitleFocused: false
        )
        return NativeEditorCRDTLocalChange(before: before, after: after)
    }

    func corruptPrimarySnapshot(in container: ModelContainer, key: DocumentStoreKey) throws {
        let context = ModelContext(container)
        let serverBaseURL = key.serverBaseURL
        let userID = key.userID
        let workspaceID = key.workspaceID
        let pageID = key.pageID
        var descriptor = FetchDescriptor<StoredDocument>(predicate: #Predicate { document in
            document.serverBaseURL == serverBaseURL &&
                document.userID == userID &&
                document.workspaceID == workspaceID &&
                document.pageID == pageID
        })
        descriptor.fetchLimit = 1
        let document = try #require(context.fetch(descriptor).first)
        document.snapshot = Data("corrupt-state".utf8)
        try context.save()
    }
}
