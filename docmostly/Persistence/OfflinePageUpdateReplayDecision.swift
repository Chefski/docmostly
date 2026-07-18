import Foundation

nonisolated enum OfflinePageUpdateReplayDecision: Equatable, Sendable {
    case alreadySynchronized
    case updateTitleOnly
    case replaceDocument
    case conflict

    static func resolve(
        serverPage: DocmostEditablePage,
        queuedTitle: String,
        queuedDocument: ProseMirrorDocument,
        baseDocument: ProseMirrorDocument?
    ) -> Self {
        if serverPage.content == queuedDocument {
            return serverPage.title == queuedTitle ? .alreadySynchronized : .updateTitleOnly
        }

        guard let baseDocument, serverPage.content == baseDocument else {
            return .conflict
        }
        return .replaceDocument
    }
}

nonisolated struct OfflinePageUpdateReplayConflict: LocalizedError, Sendable {
    let pageID: String

    var errorDescription: String? {
        "Page \(pageID) changed remotely after this offline draft was captured. The local draft was retained."
    }
}
