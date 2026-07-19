import Foundation
import Testing
@testable import DocmostlyMac

@MainActor
@Suite(.serialized)
struct NativeEditorCollaborationPresenceTests {
    @Test func awarenessStoreHonorsMonotonicClocksRefreshExpiryAndExplicitRemoval() throws {
        var store = NativeEditorAwarenessStateStore()
        let initialDate = Date(timeIntervalSince1970: 1_000)
        let alice = awarenessState(clientID: 11, clock: 5, userID: "user-2", name: "Alice")

        #expect(store.apply([alice], receivedAt: initialDate) == [alice])
        #expect(store.apply([
            awarenessState(clientID: 11, clock: 4, userID: "user-2", name: "Outdated")
        ], receivedAt: initialDate.addingTimeInterval(5)) == [alice])

        #expect(store.apply([alice], receivedAt: initialDate.addingTimeInterval(20)) == [alice])
        #expect(store.pruneStaleStates(now: initialDate.addingTimeInterval(49)) == nil)
        #expect(store.pruneStaleStates(now: initialDate.addingTimeInterval(50)) == [])

        let rejoined = awarenessState(clientID: 11, clock: 6, userID: "user-2", name: "Alice")
        #expect(store.apply([rejoined], receivedAt: initialDate.addingTimeInterval(51)) == [rejoined])
        #expect(store.apply([
            NativeEditorAwarenessState(clientID: 11, clock: 6, payload: nil)
        ], receivedAt: initialDate.addingTimeInterval(52)) == [])
    }

    @Test func awarenessStoreResetAllowsLowerClocksAfterReconnect() {
        var store = NativeEditorAwarenessStateStore()
        let highClock = awarenessState(clientID: 11, clock: 100, userID: "user-2", name: "Alice")
        let reconnected = awarenessState(clientID: 11, clock: 1, userID: "user-2", name: "Alice")

        #expect(store.apply([highClock]) == [highClock])
        store.reset()
        #expect(store.apply([reconnected]) == [reconnected])
    }

    @Test func multipleSessionsKeepDistinctCursorIdentityAndSuppressLocalClient() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        let states = [
            awarenessState(clientID: 10, clock: 1, userID: "local", name: "Local", cursorClock: 1),
            awarenessState(clientID: 11, clock: 1, userID: "user-2", name: "Alice", cursorClock: 2),
            awarenessState(clientID: 12, clock: 1, userID: "user-2", name: "Alice", cursorClock: 3)
        ]

        viewModel.applyAwarenessStates(states, localClientID: 10)

        #expect(viewModel.activeCollaborators.map(\.id) == ["user-2"])
        #expect(viewModel.remoteCursors.map(\.id) == ["client-11", "client-12"])
        #expect(viewModel.remoteCursors.map(\.collaboratorID) == ["user-2", "user-2"])
        #expect(viewModel.remoteCursors.allSatisfy { $0.colorName == "#958DF1" })
    }

    @Test func projectionRoutesRootNestedAndMultiBlockSelectionsWithoutMergingSessions() throws {
        let document = nestedDocument()
        let projection = NativeEditorRemotePresenceProjection(document: document, cursors: [
            resolvedCursor(
                id: "client-11",
                collaboratorID: "user-2",
                name: "Alice",
                anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 2),
                head: NativeEditorRemoteTextPosition(blockIndex: 2, characterOffset: 3)
            ),
            resolvedCursor(
                id: "client-12",
                collaboratorID: "user-2",
                name: "Alice",
                anchor: NativeEditorRemoteTextPosition(blockIndex: 3, characterOffset: 2),
                head: NativeEditorRemoteTextPosition(blockIndex: 3, characterOffset: 2)
            ),
            resolvedCursor(
                id: "client-20",
                collaboratorID: "user-3",
                name: "Bob",
                anchor: NativeEditorRemoteTextPosition(blockIndex: 3, characterOffset: 4),
                head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 1)
            )
        ])
        let calloutScope = [NativeEditorRemotePresenceScope(containerBlockIndex: 1, target: .callout)]

        let rootStart = projection.segments(scope: [], blockIndex: 0)
        let aliceRootStart = try #require(rootStart.first { $0.cursorID == "client-11" })
        let bobRootStart = try #require(rootStart.first { $0.cursorID == "client-20" })
        #expect(aliceRootStart.characterRange == 2..<4)
        #expect(aliceRootStart.caretOffset == nil)
        #expect(bobRootStart.characterRange == 1..<4)
        #expect(bobRootStart.caretOffset == 1)

        let firstNested = projection.segments(scope: calloutScope, blockIndex: 0)
        let secondNested = projection.segments(scope: calloutScope, blockIndex: 1)
        #expect(firstNested.first { $0.cursorID == "client-11" }?.characterRange == 0..<6)
        #expect(secondNested.first { $0.cursorID == "client-11" }?.characterRange == 0..<3)
        #expect(secondNested.first { $0.cursorID == "client-11" }?.caretOffset == 3)

        let rootTail = projection.segments(scope: [], blockIndex: 2)
        #expect(rootTail.first { $0.cursorID == "client-12" }?.caretOffset == 2)
        #expect(rootTail.first { $0.cursorID == "client-20" }?.characterRange == 0..<4)
        #expect(projection.rootBlockIndex(for: "user-2") == 2)
        #expect(projection.rootBlockIndex(for: "user-3") == 0)
    }

    @Test func collaboratorJumpTargetsNestedCaretContainerWithoutChangingFocus() throws {
        let document = nestedDocument()
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = document
        let originalActiveBlockID = viewModel.activeBlockID
        viewModel.resolvedRemoteCursors = [resolvedCursor(
            id: "client-11",
            collaboratorID: "user-2",
            name: "Alice",
            anchor: NativeEditorRemoteTextPosition(blockIndex: 2, characterOffset: 3),
            head: NativeEditorRemoteTextPosition(blockIndex: 2, characterOffset: 3)
        )]

        #expect(viewModel.rootBlockID(forCollaboratorID: "user-2") == document.blocks[1].id)
        #expect(viewModel.activeBlockID == originalActiveBlockID)
    }

    @Test func relativeSelectionSurvivesRemoteSnapshotAfterInsertionBeforeCaret() async throws {
        let source = try NativeEditorJSCRDTRuntimeSource.bundled(in: .main)
        let sourceEngine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: textDocument("Seed"),
            runtimeSource: source
        )
        let receivingEngine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: textDocument("Seed"),
            runtimeSource: source
        )
        let updates = await sourceEngine.localUpdates()
        var iterator = updates.makeAsyncIterator()

        try await sourceEngine.integrateLocalChange(change(before: "Seed", after: "Hello world"))
        _ = try await receivingEngine.applyRemoteUpdateCapturingSnapshot(try #require(await iterator.next()))
        let relativeCursor = try #require(try await receivingEngine.encodeLocalAwarenessCursor(
            for: NativeEditorLocalTextSelection(
                anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 6),
                head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 11)
            )
        ))
        #expect(relativeCursor.targetsDocmostDefaultFragment)

        try await sourceEngine.integrateLocalChange(change(before: "Hello world", after: "Hello brave world"))
        let secondUpdate = try #require(await iterator.next())
        let snapshot = try #require(
            try await receivingEngine.applyRemoteUpdateCapturingSnapshot(secondUpdate)
        )
        let resolved = try #require(try await receivingEngine.resolveRemoteCursor(NativeEditorRemoteCursor(
            id: "client-11",
            collaboratorID: "user-2",
            name: "Alice",
            colorName: "#958DF1",
            cursor: relativeCursor
        )))

        #expect(snapshot.document.blocks.map { String($0.text.characters) } == ["Hello brave world"])
        #expect(resolved.anchor == NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 12))
        #expect(resolved.head == NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 17))
    }

    private func awarenessState(
        clientID: Int,
        clock: Int,
        userID: String,
        name: String,
        cursorClock: Int? = nil
    ) -> NativeEditorAwarenessState {
        NativeEditorAwarenessState(
            clientID: clientID,
            clock: clock,
            payload: NativeEditorAwarenessPayload(
                user: NativeEditorAwarenessUser(id: userID, name: name, color: "#958DF1"),
                cursor: cursorClock.map { clock in
                    NativeEditorAwarenessCursor(
                        anchor: relativePosition(client: clientID, clock: clock),
                        head: relativePosition(client: clientID, clock: clock)
                    )
                }
            )
        )
    }

    private func relativePosition(client: Int, clock: Int) -> NativeEditorYjsRelativePosition {
        NativeEditorYjsRelativePosition(
            type: .name("text"),
            targetName: NativeEditorCollaborationDocument.yjsFragmentName,
            item: NativeEditorYjsID(client: client, clock: clock),
            assoc: 0
        )
    }

    private func resolvedCursor(
        id: String,
        collaboratorID: String,
        name: String,
        anchor: NativeEditorRemoteTextPosition,
        head: NativeEditorRemoteTextPosition
    ) -> NativeEditorResolvedRemoteCursor {
        NativeEditorResolvedRemoteCursor(
            id: id,
            collaboratorID: collaboratorID,
            name: name,
            colorName: "#958DF1",
            anchor: anchor,
            head: head
        )
    }

    private func nestedDocument() -> NativeEditorDocument {
        NativeEditorDocument(proseMirrorDocument: ProseMirrorDocument(content: [
            paragraph("Root"),
            ProseMirrorNode(
                type: "callout",
                attrs: ["type": .string("info")],
                content: [paragraph("Inside"), paragraph("Again")]
            ),
            paragraph("Tail")
        ]))
    }

    private func paragraph(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(type: "paragraph", content: [ProseMirrorNode(type: "text", text: text)])
    }

    private func textDocument(_ text: String) -> NativeEditorDocument {
        NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString(text), alignment: .left)
        ])
    }

    private func change(before: String, after: String) -> NativeEditorCRDTLocalChange {
        NativeEditorCRDTLocalChange(
            before: historySnapshot(text: before),
            after: historySnapshot(text: after)
        )
    }

    private func historySnapshot(text: String) -> NativeEditorHistorySnapshot {
        NativeEditorHistorySnapshot(
            title: "Page",
            document: textDocument(text),
            activeBlockID: nil,
            selectedBlockID: nil,
            visibleBlockControlsID: nil,
            isTitleFocused: false
        )
    }
}
