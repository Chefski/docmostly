import Foundation
@preconcurrency import JavaScriptCore

nonisolated enum NativeEditorJSCRDTEngineError: Error, LocalizedError, Equatable {
    case contextUnavailable
    case scriptEvaluationFailed(String)
    case missingRuntimeFactory
    case documentCreationFailed
    case missingFunction(String)
    case invalidDataResult(String)
    case invalidJSONResult(String)
    case invalidDate(String)

    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            "The JavaScript collaboration runtime could not be created."
        case .scriptEvaluationFailed(let message):
            "The JavaScript collaboration runtime failed: \(message)"
        case .missingRuntimeFactory:
            "The JavaScript collaboration runtime did not expose docmostlyCRDT.createDocument."
        case .documentCreationFailed:
            "The JavaScript collaboration runtime did not create a document engine."
        case .missingFunction(let function):
            "The JavaScript collaboration runtime is missing \(function)."
        case .invalidDataResult(let function):
            "The JavaScript collaboration runtime returned invalid update data from \(function)."
        case .invalidJSONResult(let function):
            "The JavaScript collaboration runtime returned invalid JSON from \(function)."
        case .invalidDate(let value):
            "The JavaScript collaboration runtime returned an invalid date: \(value)."
        }
    }
}

@MainActor
final class NativeEditorJSCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    private let context: JSContext
    private let runtimeDocument: JSValue
    private let localUpdateStream: AsyncStream<Data>
    private let localUpdateContinuation: AsyncStream<Data>.Continuation
    private let snapshotStream: AsyncStream<NativeEditorCRDTDocumentSnapshot>
    private let snapshotContinuation: AsyncStream<NativeEditorCRDTDocumentSnapshot>.Continuation

    init(
        pageID: String,
        title: String,
        document: NativeEditorDocument,
        runtimeSource: String
    ) throws {
        guard let context = JSContext() else {
            throw NativeEditorJSCRDTEngineError.contextUnavailable
        }

        let localUpdates = AsyncStream.makeStream(of: Data.self)
        let snapshots = AsyncStream.makeStream(of: NativeEditorCRDTDocumentSnapshot.self)
        self.context = context
        localUpdateStream = localUpdates.stream
        localUpdateContinuation = localUpdates.continuation
        snapshotStream = snapshots.stream
        snapshotContinuation = snapshots.continuation

        context.exception = nil
        _ = context.evaluateScript(runtimeSource)
        try Self.throwIfException(in: context)

        guard
            let runtime = context.objectForKeyedSubscript("docmostlyCRDT"),
            let factory = runtime.objectForKeyedSubscript("createDocument"),
            factory.isUndefined == false,
            factory.isNull == false
        else {
            throw NativeEditorJSCRDTEngineError.missingRuntimeFactory
        }

        let seed = RuntimeSeed(
            pageID: pageID,
            title: title,
            document: document.proseMirrorDocument
        )
        let seedValue = try Self.javaScriptValue(from: seed, in: context)
        context.exception = nil
        guard let runtimeDocument = runtime.invokeMethod("createDocument", withArguments: [seedValue]) else {
            try Self.throwIfException(in: context)
            throw NativeEditorJSCRDTEngineError.documentCreationFailed
        }
        try Self.throwIfException(in: context)
        guard runtimeDocument.isUndefined == false, runtimeDocument.isNull == false else {
            throw NativeEditorJSCRDTEngineError.documentCreationFailed
        }

        self.runtimeDocument = runtimeDocument
    }

    isolated deinit {
        localUpdateContinuation.finish()
        snapshotContinuation.finish()
    }

    func encodeStateVector() async throws -> Data {
        try dataResult(from: callRequired("encodeStateVector"), function: "encodeStateVector")
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        try dataResult(
            from: callRequired("encodeStateAsUpdate", arguments: [stateVector.base64EncodedString()]),
            function: "encodeStateAsUpdate"
        )
    }

    func applyRemoteUpdate(_ update: Data) async throws {
        _ = try callRequired("applyRemoteUpdate", arguments: [update.base64EncodedString()])
        try drainRuntimeOutputs()
    }

    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws {
        let payload = RuntimeLocalChange(
            before: RuntimeHistorySnapshot(snapshot: change.before),
            after: RuntimeHistorySnapshot(snapshot: change.after)
        )
        _ = try callRequired("integrateLocalChange", arguments: [Self.javaScriptValue(from: payload, in: context)])
        try drainRuntimeOutputs()
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        let result = try decode(
            RuntimeSaveResult.self,
            from: callRequired(
                "flushPendingLocalChanges",
                arguments: [title, Self.javaScriptValue(from: document.proseMirrorDocument, in: context)]
            ),
            function: "flushPendingLocalChanges"
        )
        try drainRuntimeOutputs()

        return NativeEditorCRDTSaveResult(
            title: result.title,
            updatedAt: try NativeEditorJSCRDTDateParser.date(from: result.updatedAt)
        )
    }

    func localUpdates() async -> AsyncStream<Data> {
        localUpdateStream
    }

    func documentSnapshots() async -> AsyncStream<NativeEditorCRDTDocumentSnapshot> {
        snapshotStream
    }

    private func drainRuntimeOutputs() throws {
        try drainLocalUpdates()
        try drainDocumentSnapshots()
    }

    private func drainLocalUpdates() throws {
        guard let value = try callOptional("drainLocalUpdates") else { return }
        let updates = try decode([String].self, from: value, function: "drainLocalUpdates")

        for update in updates {
            guard let data = Data(base64Encoded: update) else {
                throw NativeEditorJSCRDTEngineError.invalidDataResult("drainLocalUpdates")
            }
            localUpdateContinuation.yield(data)
        }
    }

    private func drainDocumentSnapshots() throws {
        guard let value = try callOptional("drainDocumentSnapshots") else { return }
        let snapshots = try decode(
            [RuntimeDocumentSnapshot].self,
            from: value,
            function: "drainDocumentSnapshots"
        )

        for snapshot in snapshots {
            snapshotContinuation.yield(try snapshot.crdtSnapshot())
        }
    }

    private func callRequired(_ name: String, arguments: [Any] = []) throws -> JSValue {
        guard let result = try callOptional(name, arguments: arguments) else {
            throw NativeEditorJSCRDTEngineError.missingFunction(name)
        }
        return result
    }

    private func callOptional(_ name: String, arguments: [Any] = []) throws -> JSValue? {
        guard
            let function = runtimeDocument.objectForKeyedSubscript(name),
            function.isUndefined == false,
            function.isNull == false
        else {
            return nil
        }

        context.exception = nil
        guard let result = runtimeDocument.invokeMethod(name, withArguments: arguments) else {
            try Self.throwIfException(in: context)
            throw NativeEditorJSCRDTEngineError.missingFunction(name)
        }
        try Self.throwIfException(in: context)
        return result
    }

    private func dataResult(from value: JSValue, function: String) throws -> Data {
        guard
            value.isUndefined == false,
            value.isNull == false,
            let base64 = value.toString(),
            let data = Data(base64Encoded: base64)
        else {
            throw NativeEditorJSCRDTEngineError.invalidDataResult(function)
        }

        return data
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from value: JSValue, function: String) throws -> Value {
        let data = try jsonData(from: value, function: function)
        return try JSONDecoder().decode(type, from: data)
    }

    func optionalRuntimeResult<Payload: Encodable, Result: Decodable>(
        function: String,
        payload: Payload,
        as resultType: Result.Type
    ) throws -> Result? {
        guard let value = try callOptional(
            function,
            arguments: [Self.javaScriptValue(from: payload, in: context)]
        ) else { return nil }

        return try optionalDecoded(resultType, from: value, function: function)
    }

    private func optionalDecoded<Value: Decodable>(
        _ type: Value.Type,
        from value: JSValue,
        function: String
    ) throws -> Value? {
        guard value.isUndefined == false, value.isNull == false else { return nil }

        return try decode(type, from: value, function: function)
    }

    private func jsonData(from value: JSValue, function: String) throws -> Data {
        if value.isString, let string = value.toString() {
            return Data(string.utf8)
        }

        guard
            let json = context.objectForKeyedSubscript("JSON"),
            let stringified = json.invokeMethod("stringify", withArguments: [value])
        else {
            throw NativeEditorJSCRDTEngineError.invalidJSONResult(function)
        }
        try Self.throwIfException(in: context)

        guard
            stringified.isUndefined == false,
            stringified.isNull == false,
            let string = stringified.toString()
        else {
            throw NativeEditorJSCRDTEngineError.invalidJSONResult(function)
        }

        return Data(string.utf8)
    }

    private static func javaScriptValue<Value: Encodable>(
        from value: Value,
        in context: JSContext
    ) throws -> JSValue {
        let data = try JSONEncoder().encode(value)
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw NativeEditorJSCRDTEngineError.invalidJSONResult("JSONEncoder")
        }
        let literal = try javaScriptStringLiteral(json)

        context.exception = nil
        guard let value = context.evaluateScript("JSON.parse(\(literal))") else {
            try throwIfException(in: context)
            throw NativeEditorJSCRDTEngineError.invalidJSONResult("JSON.parse")
        }
        try throwIfException(in: context)
        return value
    }

    private static func javaScriptStringLiteral(_ string: String) throws -> String {
        let data = try JSONEncoder().encode(string)
        guard let literal = String(bytes: data, encoding: .utf8) else {
            throw NativeEditorJSCRDTEngineError.invalidJSONResult("JSONEncoder")
        }
        return literal
    }

    private static func throwIfException(in context: JSContext) throws {
        guard let exception = context.exception, exception.isUndefined == false else { return }

        let message = exception.toString() ?? "Unknown JavaScript exception."
        context.exception = nil
        throw NativeEditorJSCRDTEngineError.scriptEvaluationFailed(message)
    }
}

@MainActor
final class NativeEditorJSCRDTEngineFactory: NativeEditorCRDTDocumentEngineFactory {
    private let runtimeSource: String

    init(runtimeSource: String) {
        self.runtimeSource = runtimeSource
    }

    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine {
        try NativeEditorJSCRDTDocumentEngine(
            pageID: pageID,
            title: title,
            document: document,
            runtimeSource: runtimeSource
        )
    }
}

private struct RuntimeSeed: Encodable {
    let pageID: String
    let title: String
    let document: ProseMirrorDocument
}

private struct RuntimeLocalChange: Encodable {
    let before: RuntimeHistorySnapshot
    let after: RuntimeHistorySnapshot
}

private struct RuntimeHistorySnapshot: Encodable {
    let title: String
    let document: ProseMirrorDocument

    init(snapshot: NativeEditorHistorySnapshot) {
        title = snapshot.title
        document = snapshot.document.proseMirrorDocument
    }
}

private struct RuntimeSaveResult: Decodable {
    let title: String?
    let updatedAt: String?
}

private struct RuntimeDocumentSnapshot: Decodable {
    let title: String?
    let document: ProseMirrorDocument
    let updatedAt: String?

    func crdtSnapshot() throws -> NativeEditorCRDTDocumentSnapshot {
        NativeEditorCRDTDocumentSnapshot(
            title: title,
            document: NativeEditorDocument(proseMirrorDocument: document),
            updatedAt: try NativeEditorJSCRDTDateParser.date(from: updatedAt)
        )
    }
}

private enum NativeEditorJSCRDTDateParser {
    static func date(from value: String?) throws -> Date? {
        guard let value else { return nil }

        do {
            return try Date(value, strategy: .iso8601)
        } catch {
            throw NativeEditorJSCRDTEngineError.invalidDate(value)
        }
    }
}
