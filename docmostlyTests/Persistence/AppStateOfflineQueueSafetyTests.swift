import Foundation
import SwiftData
import Testing
@testable import docmostly

struct AppStateOfflineQueueSafetyTests {
    @Test func cancellationStopsReplayWithoutRequestingRecordRemoval() {
        let disposition = OfflineMutationReplayFailureDisposition(error: CancellationError())

        #expect(disposition == .stopWithoutMutation)
    }

    @Test(arguments: [409, 412, 422])
    func permanentClientFailureRetainsAuthoredPageContent(status: Int) {
        let payload = OfflineMutationPayload.updatePage(
            pageId: "page-1",
            title: "Local draft",
            document: document(text: "Local body")
        )
        let disposition = OfflineMutationReplayFailureDisposition(
            error: APIError.httpStatus(status, nil),
            payload: payload
        )

        #expect(disposition == .retainForRetry)
    }

    @Test func permanentClientFailureRetainsAuthoredCommentAndLabelContent() {
        let payloads: [OfflineMutationPayload] = [
            .createComment(
                localId: "local-comment-1",
                pageId: "page-1",
                content: "<p>Keep this comment</p>",
                plainText: "Keep this comment",
                type: .page,
                selection: nil,
                yjsSelection: nil
            ),
            .addPageLabels(
                pageId: "page-1",
                labels: [OfflinePageLabel(pageId: "page-1", name: "Customer research")]
            )
        ]

        for payload in payloads {
            #expect(OfflineMutationReplayFailureDisposition(
                error: APIError.httpStatus(422, nil),
                payload: payload
            ) == .retainForRetry)
        }
    }

    @Test func explicitlyDisposableMutationMayDropAfterPermanentClientFailure() {
        let disposition = OfflineMutationReplayFailureDisposition(
            error: APIError.httpStatus(422, nil),
            payload: .watchPage(pageId: "page-1")
        )

        #expect(disposition == .dropRecord)
    }

    @Test func transientFailureRetainsTheRecordForRetry() {
        let disposition = OfflineMutationReplayFailureDisposition(
            error: APIError.connectionFailed("Offline")
        )

        #expect(disposition == .retainForRetry)
    }

    @MainActor
    @Test func retainedDocumentConflictDoesNotMasqueradeAsAConnectivityFailure() {
        let appState = AppState()

        #expect(appState.canQueueOfflineMutation(
            after: OfflinePageUpdateReplayConflict(pageID: "page-1")
        ) == false)
    }

    @MainActor
    @Test func conflictResolutionDiscardsOnlyTheCapturedCollaborativeDraft() async throws {
        let (appState, scope) = makeConfiguredAppState()
        let record = try await appState.queueOfflineMutation(.updatePage(
            pageId: "page-1",
            title: "Local draft",
            document: document(text: "Local body"),
            baseDocument: document(text: "Remote body")
        ))

        let result = try await appState.discardPendingCollaborativeDraft(
            pageId: "page-1",
            through: record.createdAt.addingTimeInterval(1)
        )
        let pending = try await appState.offlineQueueRepository?.pending(scope: scope)

        #expect(result == .acknowledged)
        #expect(pending?.isEmpty == true)
    }

    @MainActor
    @Test func conflictResolutionPreservesANewerCollaborativeDraft() async throws {
        let (appState, scope) = makeConfiguredAppState()
        let record = try await appState.queueOfflineMutation(.updatePage(
            pageId: "page-1",
            title: "Newer local draft",
            document: document(text: "Newer local body"),
            baseDocument: document(text: "Remote body")
        ))

        let result = try await appState.discardPendingCollaborativeDraft(
            pageId: "page-1",
            through: record.createdAt.addingTimeInterval(-1)
        )
        let pending = try await appState.offlineQueueRepository?.pending(scope: scope)

        #expect(result == .newerPendingUpdatePreserved)
        #expect(pending?.map(\.id) == [record.id])
    }

    @MainActor
    @Test func keepMineIsDurableBeforeTheEditorPublishesAgain() async throws {
        let (appState, scope) = makeConfiguredAppState()
        let remoteDocument = document(text: "Remote concurrent edit")
        let localDocument = document(text: "Local retained edit")
        try appState.cacheRepository?.saveEditablePage(
            DocmostEditablePage(
                id: "page-1",
                slugId: "page-1",
                title: "Remote",
                content: remoteDocument,
                icon: nil,
                spaceId: "space-1",
                updatedAt: .now,
                permissions: nil,
                lastUpdatedBy: nil
            ),
            scope: scope
        )
        let oldRecord = try await appState.queueOfflineMutation(.updatePage(
            pageId: "page-1",
            title: "Local",
            document: localDocument,
            baseDocument: document(text: "Original base")
        ))

        let result = try await appState.keepPendingCollaborativeDraft(
            pageId: "page-1",
            title: "Local",
            document: localDocument,
            remoteBaseTitle: "Remote title",
            remoteBaseDocument: remoteDocument,
            replacingThrough: oldRecord.createdAt.addingTimeInterval(1)
        )

        let pending = try await appState.offlineQueueRepository?.pending(scope: scope)
        let cached = try appState.cacheRepository?.loadEditablePage(idOrSlugId: "page-1", scope: scope)
        #expect(result == .superseded)
        #expect(pending?.map(\.payload) == [
            .updatePage(
                pageId: "page-1",
                title: "Local",
                document: localDocument,
                baseTitle: "Remote title",
                baseDocument: remoteDocument
            )
        ])
        #expect(cached?.title == "Local")
        #expect(cached?.content == localDocument)
    }

    @MainActor
    private func makeConfiguredAppState() -> (AppState, CacheScope) {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let appState = AppState()
        let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")
        appState.configure(modelContext: ModelContext(container), modelContainer: container)
        appState.configurePreviewCacheScope(scope)
        return (appState, scope)
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
