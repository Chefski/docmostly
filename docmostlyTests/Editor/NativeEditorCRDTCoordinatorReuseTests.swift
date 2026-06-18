import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCRDTCoordinatorReuseTests {
    @Test func viewModelReusesCRDTCoordinatorAcrossCollaborationSessions() async throws {
        let engine = CoordinatorReuseCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        let firstDriver = try #require(viewModel.collaborationSession().syncDriver)
        let secondDriver = try #require(viewModel.collaborationSession().syncDriver)
        let update = Data([23, 24])

        _ = await firstDriver.outboundFrame(forLocalUpdate: update)
        let echoFrames = try await secondDriver.outboundFrames(for: .update(update))

        #expect(echoFrames == [])
        #expect(engine.appliedRemoteUpdates == [])
    }
}

@MainActor
struct CRDTEngineAttachmentTests {
    @Test func crdtAttachmentDoesNothingWithoutFactory() async {
        let appState = AppState()
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(
            to: viewModel,
            appState: appState
        )

        #expect(viewModel.usesCRDTDocumentEngine == false)
        #expect(viewModel.collaborationSession().syncDriver == nil)
        #expect(viewModel.realtimeStatus == .disconnected)
    }

    @Test func crdtAttachmentConfiguresFactoryEngineBeforeCollaborationSession() async throws {
        let engine = CoordinatorReuseCRDTDocumentEngine()
        engine.encodedStateVector = Data([42])
        let factory = CRDTAttachmentEngineFactory(engine: engine)
        let appState = AppState(crdtDocumentEngineFactory: factory)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Seed"), alignment: .left)
        ])

        await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(
            to: viewModel,
            appState: appState
        )

        #expect(factory.requests == [
            CRDTAttachmentEngineFactory.Request(
                pageID: "page-1",
                title: "Page",
                document: viewModel.document
            )
        ])
        #expect(viewModel.usesCRDTDocumentEngine == true)

        let driver = try #require(viewModel.collaborationSession().syncDriver)
        let frames = try await driver.outboundFramesAfterAuthentication()
        let frame = try NativeEditorHocuspocusFrame.parse(try #require(frames.first))
        #expect(frame.message == .sync(.stepOne(Data([42]))))
    }

    @Test func crdtAttachmentReportsFactoryFailureAsUnsupportedStatus() async {
        let appState = AppState(crdtDocumentEngineFactory: ThrowingCRDTDocumentEngineFactory())
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(
            to: viewModel,
            appState: appState
        )

        #expect(viewModel.usesCRDTDocumentEngine == false)
        #expect(viewModel.collaborationSession().syncDriver == nil)
        #expect(viewModel.realtimeStatus == .unsupported("Factory failed."))
    }

    @Test func crdtAttachmentDoesNotConfigureEngineAfterCancellation() async {
        let engine = CoordinatorReuseCRDTDocumentEngine()
        let factory = SuspendingCRDTAttachmentEngineFactory(engine: engine)
        let appState = AppState(crdtDocumentEngineFactory: factory)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        let attachTask = Task {
            await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(
                to: viewModel,
                appState: appState
            )
        }
        await factory.waitUntilSuspended()

        attachTask.cancel()
        factory.resume()
        await attachTask.value

        #expect(viewModel.usesCRDTDocumentEngine == false)
        #expect(viewModel.collaborationSession().syncDriver == nil)
        #expect(viewModel.realtimeStatus == .disconnected)
    }
}

@MainActor
private final class CoordinatorReuseCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    var encodedStateVector = Data()
    var appliedRemoteUpdates: [Data] = []

    func encodeStateVector() async throws -> Data {
        encodedStateVector
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws {
        appliedRemoteUpdates.append(update)
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        NativeEditorCRDTSaveResult()
    }
}

@MainActor
private final class CRDTAttachmentEngineFactory: NativeEditorCRDTDocumentEngineFactory {
    struct Request: Equatable {
        let pageID: String
        let title: String
        let document: NativeEditorDocument
    }

    let engine: CoordinatorReuseCRDTDocumentEngine
    var requests: [Request] = []

    init(engine: CoordinatorReuseCRDTDocumentEngine) {
        self.engine = engine
    }

    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine {
        requests.append(Request(pageID: pageID, title: title, document: document))
        return engine
    }
}

@MainActor
private final class ThrowingCRDTDocumentEngineFactory: NativeEditorCRDTDocumentEngineFactory {
    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine {
        throw APIError.connectionFailed("Factory failed.")
    }
}

@MainActor
private final class SuspendingCRDTAttachmentEngineFactory: NativeEditorCRDTDocumentEngineFactory {
    let engine: CoordinatorReuseCRDTDocumentEngine
    private var makeContinuation: CheckedContinuation<Void, Never>?
    private var suspensionContinuation: CheckedContinuation<Void, Never>?
    private var didSuspend = false

    init(engine: CoordinatorReuseCRDTDocumentEngine) {
        self.engine = engine
    }

    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine {
        await withCheckedContinuation { continuation in
            self.makeContinuation = continuation
            didSuspend = true
            suspensionContinuation?.resume()
            suspensionContinuation = nil
        }
        return engine
    }

    func waitUntilSuspended() async {
        if didSuspend {
            return
        }

        await withCheckedContinuation { continuation in
            self.suspensionContinuation = continuation
        }
    }

    func resume() {
        makeContinuation?.resume()
        makeContinuation = nil
    }
}
