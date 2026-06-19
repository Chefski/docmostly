import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorJSCRDTEngineTests {
    @Test func seedsRuntimeAndEncodesInitialStateVector() async throws {
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: Self.runtimeSource
        )

        let stateVector = try await engine.encodeStateVector()

        #expect(stateVector == Data([1, 2, 3]))
    }

    @Test func repliesToRemoteStateVectorWithRuntimeUpdate() async throws {
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: Self.runtimeSource
        )

        let update = try await engine.encodeStateAsUpdate(for: Data([9, 8]))

        #expect(update == Data([7, 6, 5]))
    }

    @Test func integratesLocalChangeAndPublishesRuntimeUpdate() async throws {
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: Self.runtimeSource
        )
        let updates = await engine.localUpdates()
        var iterator = updates.makeAsyncIterator()
        let change = NativeEditorCRDTLocalChange(
            before: historySnapshot(title: "Page", text: "Seed"),
            after: historySnapshot(title: "Page", text: "Edited")
        )

        try await engine.integrateLocalChange(change)

        #expect(await iterator.next() == Data([4, 5, 6]))
    }

    @Test func appliesRemoteUpdateAndPublishesDecodedSnapshot() async throws {
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: Self.runtimeSource
        )
        let snapshots = await engine.documentSnapshots()
        var iterator = snapshots.makeAsyncIterator()

        try await engine.applyRemoteUpdate(Data([8, 7]))

        let snapshot = try #require(await iterator.next())
        #expect(snapshot.title == "Remote")
        #expect(snapshot.document.blocks.map(\.kind) == [.paragraph])
        #expect(snapshot.document.blocks.map { String($0.text.characters) } == ["Merged"])
        #expect(snapshot.updatedAt == Date(timeIntervalSince1970: 20))
    }

    @Test func flushesPendingLocalChangesThroughRuntime() async throws {
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: Self.runtimeSource
        )

        let result = try await engine.flushPendingLocalChanges(
            title: " Saved ",
            document: document(text: "Saved body")
        )

        #expect(result == NativeEditorCRDTSaveResult(
            title: "Saved",
            updatedAt: Date(timeIntervalSince1970: 30)
        ))
    }

    @Test func resolvesRemoteCursorThroughRuntime() async throws {
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: Self.runtimeSource
        )
        let cursor = NativeEditorRemoteCursor(
            id: "user-2",
            name: "Alice",
            colorName: "#2563EB",
            cursor: NativeEditorAwarenessCursor(anchor: nil, head: nil)
        )

        let resolvedCursor = try await engine.resolveRemoteCursor(cursor)

        #expect(resolvedCursor == NativeEditorResolvedRemoteCursor(
            id: "user-2",
            name: "Alice",
            colorName: "#2563EB",
            anchor: NativeEditorRemoteTextPosition(blockIndex: 1, characterOffset: 2),
            head: NativeEditorRemoteTextPosition(blockIndex: 1, characterOffset: 6)
        ))
    }

    @Test func encodesLocalAwarenessCursorThroughRuntime() async throws {
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: Self.runtimeSource
        )

        let cursor = try await engine.encodeLocalAwarenessCursor(for: NativeEditorLocalTextSelection(
            anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 1),
            head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 3)
        ))

        #expect(cursor == NativeEditorAwarenessCursor(
            anchor: yjsRelativePosition(clock: 10),
            head: yjsRelativePosition(clock: 12)
        ))
    }

    @Test func encodesInlineCommentSelectionThroughRuntime() async throws {
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: Self.runtimeSource
        )

        let selection = try await engine.encodeInlineCommentSelection(for: NativeEditorLocalTextSelection(
            anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 2),
            head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 5)
        ))

        #expect(selection == NativeEditorYjsSelection(
            anchor: yjsSelectionPosition(clock: 20),
            head: yjsSelectionPosition(clock: 25)
        ))
    }

    @Test func reportsMissingRuntimeFactory() throws {
        #expect(throws: NativeEditorJSCRDTEngineError.missingRuntimeFactory) {
            _ = try NativeEditorJSCRDTDocumentEngine(
                pageID: "page-1",
                title: "Page",
                document: document(text: "Seed"),
                runtimeSource: "globalThis.docmostlyCRDT = {};"
            )
        }
    }

    @Test func rejectsRuntimeWithoutLocalUpdateDrain() throws {
        #expect(throws: NativeEditorJSCRDTEngineError.missingFunction("drainLocalUpdates")) {
            _ = try NativeEditorJSCRDTDocumentEngine(
                pageID: "page-1",
                title: "Page",
                document: document(text: "Seed"),
                runtimeSource: """
                globalThis.docmostlyCRDT = {
                  createDocument() {
                    return {
                      encodeStateVector() { return ""; },
                      encodeStateAsUpdate() { return ""; },
                      applyRemoteUpdate() {},
                      integrateLocalChange() {},
                      flushPendingLocalChanges() { return { title: null, updatedAt: null }; },
                      drainDocumentSnapshots() { return []; }
                    };
                  }
                };
                """
            )
        }
    }

    @Test func rejectsRuntimeWithoutDocumentSnapshotDrain() throws {
        #expect(throws: NativeEditorJSCRDTEngineError.missingFunction("drainDocumentSnapshots")) {
            _ = try NativeEditorJSCRDTDocumentEngine(
                pageID: "page-1",
                title: "Page",
                document: document(text: "Seed"),
                runtimeSource: """
                globalThis.docmostlyCRDT = {
                  createDocument() {
                    return {
                      encodeStateVector() { return ""; },
                      encodeStateAsUpdate() { return ""; },
                      applyRemoteUpdate() {},
                      integrateLocalChange() {},
                      flushPendingLocalChanges() { return { title: null, updatedAt: null }; },
                      drainLocalUpdates() { return []; }
                    };
                  }
                };
                """
            )
        }
    }

    @Test func rejectsRuntimeWithNonCallableRequiredFunction() throws {
        #expect(throws: NativeEditorJSCRDTEngineError.missingFunction("drainLocalUpdates")) {
            _ = try NativeEditorJSCRDTDocumentEngine(
                pageID: "page-1",
                title: "Page",
                document: document(text: "Seed"),
                runtimeSource: """
                globalThis.docmostlyCRDT = {
                  createDocument() {
                    return {
                      encodeStateVector() { return ""; },
                      encodeStateAsUpdate() { return ""; },
                      applyRemoteUpdate() {},
                      integrateLocalChange() {},
                      flushPendingLocalChanges() { return { title: null, updatedAt: null }; },
                      drainLocalUpdates: [],
                      drainDocumentSnapshots() { return []; }
                    };
                  }
                };
                """
            )
        }
    }

    private static let runtimeSource = """
    globalThis.docmostlyCRDT = {
      createDocument(seed) {
        return {
          encodeStateVector() {
            if (
              seed.pageID === "page-1" &&
              seed.title === "Page" &&
              seed.document.content[0].content[0].text === "Seed"
            ) {
              return "AQID";
            }
            return "";
          },
          encodeStateAsUpdate(stateVector) {
            if (stateVector === "CQg=") {
              return "BwYF";
            }
            return "";
          },
          applyRemoteUpdate(update) {
            if (update === "CAc=") {
              this.snapshots.push({
                title: "Remote",
                updatedAt: "1970-01-01T00:00:20Z",
                document: {
                  type: "doc",
                  content: [{
                    type: "paragraph",
                    content: [{ type: "text", text: "Merged" }]
                  }]
                }
              });
            }
          },
          integrateLocalChange(change) {
            if (
              change.before.document.content[0].content[0].text === "Seed" &&
              change.after.document.content[0].content[0].text === "Edited"
            ) {
              this.localUpdates.push("BAUG");
            }
          },
          flushPendingLocalChanges(title, document) {
            return {
              title: title.trim(),
              updatedAt: "1970-01-01T00:00:30Z"
            };
          },
          resolveRemoteCursor(cursor) {
            if (cursor.id === "user-2" && cursor.cursor.anchor === null) {
              return {
                id: cursor.id,
                name: cursor.name,
                colorName: cursor.colorName,
                anchor: { blockIndex: 1, characterOffset: 2 },
                head: { blockIndex: 1, characterOffset: 6 }
              };
            }
            return null;
          },
          encodeLocalAwarenessCursor(selection) {
            if (selection.anchor.characterOffset === 1 && selection.head.characterOffset === 3) {
              return {
                anchor: { type: "text", tname: "default", item: { client: 1, clock: 10 }, assoc: 0 },
                head: { type: "text", tname: "default", item: { client: 1, clock: 12 }, assoc: 0 }
              };
            }
            return null;
          },
          encodeInlineCommentSelection(selection) {
            if (selection.anchor.characterOffset === 2 && selection.head.characterOffset === 5) {
              return {
                anchor: { type: { client: 1, clock: 20 }, tname: "default", item: null, assoc: 0 },
                head: { type: { client: 1, clock: 25 }, tname: "default", item: null, assoc: 0 }
              };
            }
            return null;
          },
          drainLocalUpdates() {
            const updates = this.localUpdates;
            this.localUpdates = [];
            return updates;
          },
          drainDocumentSnapshots() {
            const snapshots = this.snapshots;
            this.snapshots = [];
            return snapshots;
          },
          localUpdates: [],
          snapshots: []
        };
      }
    };
    """

    private func document(text: String) -> NativeEditorDocument {
        NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString(text), alignment: .left)
        ])
    }

    private func historySnapshot(title: String, text: String) -> NativeEditorHistorySnapshot {
        NativeEditorHistorySnapshot(
            title: title,
            document: document(text: text),
            activeBlockID: nil,
            selectedBlockID: nil,
            visibleBlockControlsID: nil,
            isTitleFocused: false
        )
    }
}

private func yjsRelativePosition(clock: Int) -> NativeEditorYjsRelativePosition {
    NativeEditorYjsRelativePosition(
        type: .name("text"),
        targetName: "default",
        item: NativeEditorYjsID(client: 1, clock: clock),
        assoc: 0
    )
}

private func yjsSelectionPosition(clock: Int) -> NativeEditorYjsSelectionPosition {
    NativeEditorYjsSelectionPosition(
        type: NativeEditorYjsID(client: 1, clock: clock),
        targetName: "default",
        item: nil,
        assoc: 0
    )
}
