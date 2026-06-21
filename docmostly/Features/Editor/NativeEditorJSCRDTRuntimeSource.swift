import Foundation

nonisolated enum NativeEditorJSCRDTRuntimeSourceError: Error, Equatable, LocalizedError {
    case missingBundledResource(filename: String)
    case unreadableResource(URL)

    var errorDescription: String? {
        switch self {
        case .missingBundledResource(let filename):
            "The JavaScript collaboration runtime resource is missing: \(filename)."
        case .unreadableResource(let url):
            "The JavaScript collaboration runtime could not be read: \(url.lastPathComponent)."
        }
    }
}

nonisolated enum NativeEditorJSCRDTRuntimeSource {
    static let bundledResourceName = "DocmostlyCRDTRuntime"
    static let bundledResourceExtension = "js"

    static var bundledResourceFilename: String {
        "\(bundledResourceName).\(bundledResourceExtension)"
    }

    static func bundled(in bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: bundledResourceName, withExtension: bundledResourceExtension) else {
            throw NativeEditorJSCRDTRuntimeSourceError.missingBundledResource(filename: bundledResourceFilename)
        }

        return try load(from: url)
    }

    static func load(from url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw NativeEditorJSCRDTRuntimeSourceError.unreadableResource(url)
        }
    }
}

@MainActor
extension NativeEditorJSCRDTEngineFactory {
    static func lazyBundled(in bundle: Bundle = .main) -> any NativeEditorCRDTDocumentEngineFactory {
        NativeEditorLazyJSCRDTEngineFactory(bundle: bundle)
    }

    static func bundledIfAvailable(in bundle: Bundle = .main) -> (any NativeEditorCRDTDocumentEngineFactory)? {
        guard bundle.url(
            forResource: NativeEditorJSCRDTRuntimeSource.bundledResourceName,
            withExtension: NativeEditorJSCRDTRuntimeSource.bundledResourceExtension
        ) != nil else {
            return nil
        }

        return lazyBundled(in: bundle)
    }
}

@MainActor
private final class NativeEditorLazyJSCRDTEngineFactory: NativeEditorCRDTDocumentEngineFactory {
    private let bundle: Bundle
    private var runtimeSource: String?

    init(bundle: Bundle) {
        self.bundle = bundle
    }

    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine {
        let runtimeSource = try cachedRuntimeSource()
        return try NativeEditorJSCRDTDocumentEngine(
            pageID: pageID,
            title: title,
            document: document,
            runtimeSource: runtimeSource
        )
    }

    private func cachedRuntimeSource() throws -> String {
        if let runtimeSource {
            return runtimeSource
        }

        let loadedSource = try NativeEditorJSCRDTRuntimeSource.bundled(in: bundle)
        runtimeSource = loadedSource
        return loadedSource
    }
}
