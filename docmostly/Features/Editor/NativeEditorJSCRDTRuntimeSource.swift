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
    static func bundledIfAvailable(in bundle: Bundle = .main) -> (any NativeEditorCRDTDocumentEngineFactory)? {
        do {
            let runtimeSource = try NativeEditorJSCRDTRuntimeSource.bundled(in: bundle)
            return NativeEditorJSCRDTEngineFactory(runtimeSource: runtimeSource)
        } catch NativeEditorJSCRDTRuntimeSourceError.missingBundledResource {
            return nil
        } catch {
            return NativeEditorFailingCRDTEngineFactory(error: error)
        }
    }
}

@MainActor
private final class NativeEditorFailingCRDTEngineFactory: NativeEditorCRDTDocumentEngineFactory {
    private let error: any Error

    init(error: any Error) {
        self.error = error
    }

    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine {
        throw error
    }
}
