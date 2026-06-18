import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeCRDTStatelessEventTests {
    @Test func crdtBackedPageUpdatedEventDoesNotCreateSnapshotConflict() {
        let engine = StatelessEventCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Local",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Local draft"), alignment: .left)
        ])
        let presenceCollaborator = NativeEditorCollaborator(
            id: "user-3",
            name: "Bob",
            colorName: "#059669",
            source: .presence
        )
        viewModel.activeCollaborators = [presenceCollaborator]
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        viewModel.handleDocumentChanged()
        let event = NativeEditorCollaborationStatelessEvent(
            type: "page.updated",
            updatedAt: Date(timeIntervalSince1970: 20),
            lastUpdatedById: "user-2",
            lastUpdatedBy: DocmostPagePerson(id: "user-2", name: "Alice", avatarUrl: nil)
        )

        let handled = viewModel.handleCRDTBackedPageUpdated(event)

        #expect(handled == true)
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.pendingRemotePage == nil)
        #expect(viewModel.realtimeStatus == .connected)
        #expect(viewModel.lastRemoteUpdatedAt == event.updatedAt)
        #expect(viewModel.activeCollaborators.count == 2)
        #expect(viewModel.activeCollaborators.first == presenceCollaborator)
        #expect(viewModel.activeCollaborators.last?.id == "user-2")
        #expect(viewModel.activeCollaborators.last?.name == "Alice")
        #expect(viewModel.activeCollaborators.last?.source == .recentEditor)
    }

    @Test func pageUpdatedEventNeedsSnapshotRefreshWithoutCRDTEngine() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Local")
        let event = NativeEditorCollaborationStatelessEvent(
            type: "page.updated",
            updatedAt: Date(timeIntervalSince1970: 20),
            lastUpdatedById: nil,
            lastUpdatedBy: nil
        )

        let handled = viewModel.handleCRDTBackedPageUpdated(event)

        #expect(handled == false)
    }

    @Test func crdtBackedPageUpdatedEventIgnoresStaleMetadata() {
        let engine = StatelessEventCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Local",
            crdtDocumentEngine: engine
        )
        let currentUpdatedAt = Date(timeIntervalSince1970: 30)
        viewModel.markRemoteBaseline(updatedAt: currentUpdatedAt)
        let event = NativeEditorCollaborationStatelessEvent(
            type: "page.updated",
            updatedAt: Date(timeIntervalSince1970: 20),
            lastUpdatedById: "user-2",
            lastUpdatedBy: DocmostPagePerson(id: "user-2", name: "Alice", avatarUrl: nil)
        )

        let handled = viewModel.handleCRDTBackedPageUpdated(event)

        #expect(handled == true)
        #expect(viewModel.lastRemoteUpdatedAt == currentUpdatedAt)
        #expect(viewModel.activeCollaborators.isEmpty)
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func crdtBackedEditorIgnoresRemotePageSnapshots() {
        let engine = StatelessEventCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Local",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Local body"), alignment: .left)
        ])
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        let remotePage = editablePage(
            title: "Remote",
            text: "Remote body",
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        viewModel.handleRemotePageSnapshot(remotePage)

        #expect(viewModel.usesCRDTDocumentEngine == true)
        #expect(viewModel.title == "Local")
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local body"])
        #expect(viewModel.lastRemoteUpdatedAt == Date(timeIntervalSince1970: 10))
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.pendingRemotePage == nil)
        #expect(viewModel.activeCollaborators.isEmpty)
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func crdtBackedRealtimePageUpdatedEventDoesNotReloadSnapshot() async {
        let engine = StatelessEventCRDTDocumentEngine()
        let view = PageReaderView(pageID: "page-1")
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Local",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Local draft"), alignment: .left)
        ])
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        let updatedAt = Date(timeIntervalSince1970: 30)

        await view.handleRealtimeEvent(
            .pageUpdated(NativeEditorRealtimePageUpdatedEvent(
                pageID: "page-1",
                spaceID: "space-1",
                title: "Remote",
                slugID: "remote",
                updatedAt: updatedAt,
                lastUpdatedBy: DocmostPagePerson(id: "user-2", name: "Alice", avatarUrl: nil)
            )),
            editorViewModel: viewModel
        )

        #expect(viewModel.title == "Local")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.pendingRemotePage == nil)
        #expect(viewModel.realtimeStatus == .connected)
        #expect(viewModel.lastRemoteUpdatedAt == updatedAt)
        #expect(viewModel.activeCollaborators.last?.id == "user-2")
        #expect(viewModel.activeCollaborators.last?.source == .recentEditor)
    }

    @Test func crdtBackedRealtimeTitleUpdatePreservesLocalDocumentDraft() async {
        let engine = StatelessEventCRDTDocumentEngine()
        let view = PageReaderView(pageID: "page-1")
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Saved",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Saved body"), alignment: .left)
        ])
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()

        await view.handleRealtimeEvent(
            .pageUpdated(NativeEditorRealtimePageUpdatedEvent(
                pageID: "page-1",
                spaceID: "space-1",
                title: "Remote title",
                slugID: "remote-title",
                updatedAt: nil,
                lastUpdatedBy: DocmostPagePerson(id: "user-2", name: "Alice", avatarUrl: nil)
            )),
            editorViewModel: viewModel
        )

        #expect(viewModel.title == "Remote title")
        #expect(viewModel.lastSavedTitle == "Remote title")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.isDirty == true)
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.pendingRemotePage == nil)
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func crdtBackedRealtimeTitleUpdateDefersWhenLocalTitleIsDirty() async {
        let engine = StatelessEventCRDTDocumentEngine()
        let view = PageReaderView(pageID: "page-1")
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Saved",
            crdtDocumentEngine: engine
        )
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        viewModel.title = "Local title"
        viewModel.handleTitleChanged()

        await view.handleRealtimeEvent(
            .pageUpdated(NativeEditorRealtimePageUpdatedEvent(
                pageID: "page-1",
                spaceID: "space-1",
                title: "Remote title",
                slugID: "remote-title",
                updatedAt: nil,
                lastUpdatedBy: DocmostPagePerson(id: "user-2", name: "Alice", avatarUrl: nil)
            )),
            editorViewModel: viewModel
        )

        #expect(viewModel.title == "Local title")
        #expect(viewModel.lastSavedTitle == "Saved")
        #expect(viewModel.pendingRemoteUpdate?.title == "Remote title")
        #expect(viewModel.pendingRemotePage == nil)
        #expect(viewModel.realtimeStatus == .conflict)

        viewModel.acceptPendingRemoteUpdate()

        #expect(viewModel.title == "Remote title")
        #expect(viewModel.lastSavedTitle == "Remote title")
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.isDirty == false)
        #expect(viewModel.realtimeStatus == .connected)
    }

    private func editablePage(title: String, text: String, updatedAt: Date) -> DocmostEditablePage {
        DocmostEditablePage(
            id: "page-1",
            slugId: "slug-1",
            title: title,
            content: ProseMirrorDocument(content: [
                ProseMirrorNode(type: "paragraph", content: [
                    ProseMirrorNode(type: "text", text: text)
                ])
            ]),
            icon: nil,
            spaceId: "space-1",
            updatedAt: updatedAt,
            permissions: nil,
            lastUpdatedBy: DocmostPagePerson(id: "user-2", name: "Remote Editor", avatarUrl: nil)
        )
    }
}

@MainActor
private final class StatelessEventCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws { }

    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor? {
        nil
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        NativeEditorCRDTSaveResult()
    }
}
