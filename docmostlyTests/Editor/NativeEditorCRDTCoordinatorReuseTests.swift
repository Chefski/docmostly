import Foundation
import SwiftData
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
@Suite(.serialized)
struct CRDTEngineAttachmentTests {
    @Test func appStateDoesNotAttachCRDTEngineWithoutFactory() async throws {
        let appState = try configuredAppState(crdtDocumentEngineFactory: nil)
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page"
        )

        await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(
            to: viewModel,
            appState: appState
        )

        #expect(viewModel.usesCRDTDocumentEngine == false)
        #expect(viewModel.collaborationSession().syncDriver == nil)
        #expect(viewModel.canEdit == false)
        #expect(viewModel.realtimeStatus == .failed("Native CRDT runtime is unavailable."))
    }

    @Test func crdtAttachmentConfiguresFactoryEngineBeforeCollaborationSession() async throws {
        let engine = CoordinatorReuseCRDTDocumentEngine()
        engine.encodedStateVector = Data([42])
        let factory = CRDTAttachmentEngineFactory(engine: engine)
        let appState = try configuredAppState(crdtDocumentEngineFactory: factory)
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

    @Test func crdtAttachmentReportsFactoryFailureAsCollaborationFailure() async throws {
        let appState = try configuredAppState(
            crdtDocumentEngineFactory: ThrowingCRDTDocumentEngineFactory()
        )
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(
            to: viewModel,
            appState: appState
        )

        #expect(viewModel.usesCRDTDocumentEngine == false)
        #expect(viewModel.collaborationSession().syncDriver == nil)
        #expect(viewModel.canEdit == false)
        #expect(viewModel.realtimeStatus == .failed("Factory failed."))
    }

    @Test func offlineAttachmentRestoresCachedYjsStateBeforeEnablingEditing() async throws {
        let cachedState = Data([7, 8, 9])
        let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try CacheRepository(context: context).saveCRDTStateUpdate(
            pageId: "page-1",
            update: cachedState,
            scope: scope
        )
        let engine = CoordinatorReuseCRDTDocumentEngine()
        let appState = AppState(crdtDocumentEngineFactory: CRDTAttachmentEngineFactory(engine: engine))
        appState.configure(modelContext: context, modelContainer: container)
        appState.configurePreviewCacheScope(scope)
        appState.currentUser = try currentUser()
        appState.isOffline = true
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(to: viewModel, appState: appState)

        #expect(engine.appliedRemoteUpdates == [cachedState])
        #expect(viewModel.canEdit)
    }

    @Test func offlineAttachmentFailsClosedWithoutCachedYjsState() async throws {
        let engine = CoordinatorReuseCRDTDocumentEngine()
        let appState = try configuredAppState(
            crdtDocumentEngineFactory: CRDTAttachmentEngineFactory(engine: engine),
            isOffline: true
        )
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(to: viewModel, appState: appState)

        #expect(viewModel.canEdit == false)
        #expect(viewModel.realtimeStatus == .failed(
            "Open this page online once before editing it offline so its collaborative state can be cached."
        ))
    }

    @Test func crdtAttachmentDoesNotConfigureEngineAfterCancellation() async throws {
        let engine = CoordinatorReuseCRDTDocumentEngine()
        let factory = SuspendingCRDTAttachmentEngineFactory(engine: engine)
        let appState = try configuredAppState(crdtDocumentEngineFactory: factory)
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

    private func configuredAppState(
        crdtDocumentEngineFactory: (any NativeEditorCRDTDocumentEngineFactory)?,
        isOffline: Bool = false
    ) throws -> AppState {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let appState = AppState(crdtDocumentEngineFactory: crdtDocumentEngineFactory)
        appState.configure(modelContext: ModelContext(container), modelContainer: container)
        appState.configurePreviewCacheScope(CacheScope(
            serverBaseURL: "https://docs.example.com",
            userID: "user-1"
        ))
        appState.currentUser = try currentUser()
        appState.isOffline = isOffline
        return appState
    }

    private func currentUser() throws -> CurrentUserResponse {
        let data = try JSONSerialization.data(withJSONObject: [
            "user": ["id": "user-1", "name": "User"],
            "workspace": ["id": "workspace-1", "name": "Workspace"]
        ])
        return try JSONDecoder().decode(CurrentUserResponse.self, from: data)
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
