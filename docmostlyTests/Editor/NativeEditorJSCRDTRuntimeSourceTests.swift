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
          flushPendingLocalChanges(title) { return { title, updatedAt: null }; }
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
