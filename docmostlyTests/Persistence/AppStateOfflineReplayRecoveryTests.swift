import Foundation
import SwiftData
import Testing
@testable import docmostly

struct AppStateOfflineReplayRecoveryTests {
    @MainActor
    @Test func reopeningAPageSurfacesItsQueuedDraftOverTheRemoteCopy() async throws {
        let loader = OfflineReplayHTTPDataLoader(stubs: [
            .init(statusCode: 200, data: try editablePageEnvelope(title: "Remote title", body: "Remote body"))
        ])
        let (appState, scope) = try makeConfiguredAppState(loader: loader)
        let localDocument = document(text: "Durable local body")
        _ = try await appState.queueOfflineMutation(.updatePage(
            pageId: "page-1",
            title: "Durable local title",
            document: localDocument,
            baseDocument: document(text: "Original body")
        ))

        let loadedPage = try await appState.loadEditablePage(idOrSlugId: "remote-slug")
        let pending = try await appState.offlineQueueRepository?.pending(scope: scope)
        let requestedPaths = await loader.requestedPaths

        #expect(loadedPage.id == "page-1")
        #expect(loadedPage.slugId == "remote-slug")
        #expect(loadedPage.title == "Durable local title")
        #expect(loadedPage.content == localDocument)
        #expect(loadedPage.icon == "📝")
        #expect(pending?.count == 1)
        #expect(requestedPaths == ["/api/pages/info"])
    }

    @MainActor
    @Test func pageConflictDoesNotBlockAnUnrelatedQueuedMutation() async throws {
        let loader = OfflineReplayHTTPDataLoader(stubs: [
            .init(statusCode: 200, data: try editablePageEnvelope(title: "Remote", body: "Remote change")),
            .init(statusCode: 200)
        ])
        let (appState, scope) = try makeConfiguredAppState(loader: loader)
        _ = try await appState.queueOfflineMutation(.updatePage(
            pageId: "page-1",
            title: "Local",
            document: document(text: "Local change"),
            baseDocument: document(text: "Original body")
        ))
        _ = try await appState.queueOfflineMutation(.movePage(
            pageId: "page-2",
            parentPageId: nil,
            position: "a0"
        ))

        appState.scheduleOfflineQueueReconciliation()
        let replayTask = try #require(appState.offlineReplayTask)
        await replayTask.value

        let pendingRecords = try await appState.offlineQueueRepository?.pending(scope: scope)
        let pending = try #require(pendingRecords)
        let requestedPaths = await loader.requestedPaths
        #expect(pending.count == 1)
        #expect(pending.first?.kind == .updatePage)
        #expect(pending.first?.attemptCount == 1)
        #expect(requestedPaths == ["/api/pages/info", "/api/pages/move"])
    }

    @MainActor
    @Test func rejectedPageContentIsRetainedWithoutBlockingLaterQueuedWork() async throws {
        let loader = OfflineReplayHTTPDataLoader(stubs: [
            .init(statusCode: 422),
            .init(statusCode: 200)
        ])
        let (appState, scope) = try makeConfiguredAppState(loader: loader)
        _ = try await appState.queueOfflineMutation(.updatePage(
            pageId: "page-1",
            title: "Local",
            document: document(text: "Never discard this"),
            baseDocument: document(text: "Original body")
        ))
        _ = try await appState.queueOfflineMutation(.movePage(
            pageId: "page-2",
            parentPageId: nil,
            position: "a0"
        ))

        appState.scheduleOfflineQueueReconciliation()
        let replayTask = try #require(appState.offlineReplayTask)
        await replayTask.value

        let pendingRecords = try await appState.offlineQueueRepository?.pending(scope: scope)
        let pending = try #require(pendingRecords)
        let requestedPaths = await loader.requestedPaths
        #expect(pending.count == 1)
        #expect(pending.first?.kind == .updatePage)
        #expect(pending.first?.attemptCount == 1)
        #expect(requestedPaths == ["/api/pages/info", "/api/pages/move"])
    }

    @MainActor
    private func makeConfiguredAppState(
        loader: OfflineReplayHTTPDataLoader
    ) throws -> (AppState, CacheScope) {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let appState = AppState(apiClient: DocmostAPIClient(baseURL: baseURL, loader: loader))
        let scope = CacheScope(serverBaseURL: baseURL, userID: "user-1")
        appState.configure(modelContext: ModelContext(container), modelContainer: container)
        appState.configurePreviewCacheScope(scope)
        return (appState, scope)
    }

    private func editablePageEnvelope(title: String, body: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "data": [
                "id": "page-1",
                "slugId": "remote-slug",
                "title": title,
                "content": [
                    "type": "doc",
                    "content": [[
                        "type": "paragraph",
                        "content": [["type": "text", "text": body]]
                    ]]
                ],
                "icon": "📝",
                "spaceId": "space-1"
            ],
            "success": true,
            "status": 200
        ])
    }

    private func document(text: String) -> ProseMirrorDocument {
        ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "paragraph",
                content: [ProseMirrorNode(type: "text", text: text)]
            )
        ])
    }
}

private actor OfflineReplayHTTPDataLoader: HTTPDataLoading {
    struct Stub: Sendable {
        let statusCode: Int
        let data: Data

        init(statusCode: Int, data: Data = Data()) {
            self.statusCode = statusCode
            self.data = data
        }
    }

    private var stubs: [Stub]
    private(set) var requestedPaths: [String] = []

    init(stubs: [Stub]) {
        self.stubs = stubs
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url, stubs.isEmpty == false else {
            throw APIError.connectionFailed("Missing offline replay test response.")
        }
        requestedPaths.append(url.path)
        let stub = stubs.removeFirst()
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        ) else {
            throw APIError.invalidResponse
        }
        return (stub.data, response)
    }

    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        throw APIError.connectionFailed("Uploads are not used by offline replay tests.")
    }
}
