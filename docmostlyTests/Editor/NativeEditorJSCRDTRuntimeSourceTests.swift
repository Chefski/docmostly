import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorJSCRDTRuntimeSourceTests {
    @Test func loadsRuntimeSourceFromURL() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "docmostly-runtime-\(UUID().uuidString).js")
        let source = "globalThis.docmostlyCRDT = { createDocument() {} };"
        try source.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let loadedSource = try NativeEditorJSCRDTRuntimeSource.load(from: url)

        #expect(loadedSource == source)
    }

    @Test func bundledFactoryIsNilWhenRuntimeResourceIsMissing() throws {
        let bundle = try makeBundle(runtimeSource: nil)
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }

        let factory = NativeEditorJSCRDTEngineFactory.bundledIfAvailable(in: bundle)

        #expect(factory == nil)
    }

    @Test func bundledFactoryUsesRuntimeResourceWhenPresent() async throws {
        let bundle = try makeBundle(runtimeSource: Self.runtimeSource)
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let factory = try #require(NativeEditorJSCRDTEngineFactory.bundledIfAvailable(in: bundle))

        let engine = try await factory.makeDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed")
        )

        #expect(try await engine.encodeStateVector() == Data([1]))
    }

    @Test func productionAppStateLoadsBundledRuntimeFactory() async throws {
        let bundle = try makeBundle(runtimeSource: Self.runtimeSource)
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let appState = AppState.production(crdtRuntimeBundle: bundle)

        let engine = try #require(try await appState.makeCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed")
        ))

        #expect(try await engine.encodeStateVector() == Data([1]))
    }

    @Test func productionAppStateDefersMissingRuntimeFailureUntilEngineCreation() async throws {
        let bundle = try makeBundle(runtimeSource: nil)
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let appState = AppState.production(crdtRuntimeBundle: bundle)

        do {
            _ = try await appState.makeCRDTDocumentEngine(
                pageID: "page-1",
                title: "Page",
                document: document(text: "Seed")
            )
            Issue.record("Expected missing runtime resource to throw")
        } catch let error as NativeEditorJSCRDTRuntimeSourceError {
            #expect(error == .missingBundledResource(filename: NativeEditorJSCRDTRuntimeSource.bundledResourceFilename))
        }
    }

    @Test func mainBundleRuntimeIntegratesLocalTextChange() async throws {
        let source = try NativeEditorJSCRDTRuntimeSource.bundled(in: .main)
        let engine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: source
        )
        let updates = await engine.localUpdates()
        var iterator = updates.makeAsyncIterator()

        try await engine.integrateLocalChange(NativeEditorCRDTLocalChange(
            before: historySnapshot(title: "Page", text: "Seed"),
            after: historySnapshot(title: "Page", text: "Edited")
        ))

        #expect(await iterator.next()?.isEmpty == false)
        #expect(try await engine.flushPendingLocalChanges(
            title: "Page",
            document: document(text: "Edited")
        ).title == "Page")
    }

    @Test func mainBundleRuntimeAppliesRemoteYjsUpdateAsSnapshot() async throws {
        let source = try NativeEditorJSCRDTRuntimeSource.bundled(in: .main)
        let firstEngine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: source
        )
        let secondEngine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: source
        )
        let updates = await firstEngine.localUpdates()
        var updateIterator = updates.makeAsyncIterator()
        let snapshots = await secondEngine.documentSnapshots()
        var snapshotIterator = snapshots.makeAsyncIterator()

        try await firstEngine.integrateLocalChange(NativeEditorCRDTLocalChange(
            before: historySnapshot(title: "Page", text: "Seed"),
            after: historySnapshot(title: "Page", text: "Shared edit")
        ))
        let update = try #require(await updateIterator.next())

        try await secondEngine.applyRemoteUpdate(update)

        let snapshot = try #require(await snapshotIterator.next())
        #expect(snapshot.title == "Page")
        #expect(snapshot.document.blocks.map { String($0.text.characters) } == ["Shared edit"])
    }

    @Test func mainBundleRuntimeRoundTripsAwarenessCursorAfterSync() async throws {
        let source = try NativeEditorJSCRDTRuntimeSource.bundled(in: .main)
        let sourceEngine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: source
        )
        let syncedEngine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: source
        )
        let updates = await sourceEngine.localUpdates()
        var updateIterator = updates.makeAsyncIterator()
        try await sourceEngine.integrateLocalChange(NativeEditorCRDTLocalChange(
            before: historySnapshot(title: "Page", text: "Seed"),
            after: historySnapshot(title: "Page", text: "Shared edit")
        ))
        try await syncedEngine.applyRemoteUpdate(try #require(await updateIterator.next()))

        let cursor = try #require(try await syncedEngine.encodeLocalAwarenessCursor(
            for: NativeEditorLocalTextSelection(
                anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 0),
                head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 6)
            )
        ))
        let resolvedCursor = try await syncedEngine.resolveRemoteCursor(NativeEditorRemoteCursor(
            id: "user-2",
            name: "Alice",
            colorName: "#2563EB",
            cursor: cursor
        ))

        #expect(resolvedCursor == NativeEditorResolvedRemoteCursor(
            id: "user-2",
            name: "Alice",
            colorName: "#2563EB",
            anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 0),
            head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 6)
        ))
    }

    @Test func mainBundleRuntimeEncodesInlineCommentSelectionAfterSync() async throws {
        let source = try NativeEditorJSCRDTRuntimeSource.bundled(in: .main)
        let sourceEngine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: source
        )
        let syncedEngine = try NativeEditorJSCRDTDocumentEngine(
            pageID: "page-1",
            title: "Page",
            document: document(text: "Seed"),
            runtimeSource: source
        )
        let updates = await sourceEngine.localUpdates()
        var updateIterator = updates.makeAsyncIterator()
        try await sourceEngine.integrateLocalChange(NativeEditorCRDTLocalChange(
            before: historySnapshot(title: "Page", text: "Seed"),
            after: historySnapshot(title: "Page", text: "Shared edit")
        ))
        try await syncedEngine.applyRemoteUpdate(try #require(await updateIterator.next()))

        let selection = try #require(try await syncedEngine.encodeInlineCommentSelection(
            for: NativeEditorLocalTextSelection(
                anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 0),
                head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 6)
            )
        ))

        #expect(selection.anchor.targetName == NativeEditorCollaborationDocument.yjsFragmentName)
        #expect(selection.head.targetName == NativeEditorCollaborationDocument.yjsFragmentName)
        #expect(selection.anchor.assoc == 0)
        #expect(selection.head.assoc == 0)
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
              return "AQ==";
            }
            return "";
          },
          encodeStateAsUpdate() { return ""; },
          applyRemoteUpdate() {},
          integrateLocalChange() {},
          flushPendingLocalChanges(title) { return { title, updatedAt: null }; },
          resolveRemoteCursor() { return null; },
          encodeLocalAwarenessCursor() { return null; },
          encodeInlineCommentSelection() { return null; },
          drainLocalUpdates() { return []; },
          drainDocumentSnapshots() { return []; }
        };
      }
    };
    """

    private func makeBundle(runtimeSource: String?) throws -> Bundle {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "DocmostlyRuntimeTest-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Self.infoPlist.write(to: url.appending(path: "Info.plist"), atomically: true, encoding: .utf8)

        if let runtimeSource {
            try runtimeSource.write(
                to: url.appending(path: NativeEditorJSCRDTRuntimeSource.bundledResourceFilename),
                atomically: true,
                encoding: .utf8
            )
        }

        return try #require(Bundle(url: url))
    }

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

    private static let infoPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>com.docmostly.runtime-test</string>
      <key>CFBundlePackageType</key>
      <string>BNDL</string>
    </dict>
    </plist>
    """
}
