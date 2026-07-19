import Foundation

nonisolated enum OfflinePageUpdateReplayDecision: Equatable, Sendable {
    case alreadySynchronized
    case updateTitleOnly
    case replaceDocument(title: String?)
    case conflict

    static func resolve(
        serverPage: DocmostEditablePage,
        queuedTitle: String,
        queuedDocument: ProseMirrorDocument,
        baseTitle: String?,
        baseDocument: ProseMirrorDocument?
    ) -> Self {
        if serverPage.content == queuedDocument {
            return titleDecision(
                serverTitle: serverPage.title,
                queuedTitle: queuedTitle,
                baseTitle: baseTitle,
                documentsAlreadySynchronized: true
            )
        }

        guard let baseDocument, serverPage.content == baseDocument else {
            return .conflict
        }
        switch titleDecision(
            serverTitle: serverPage.title,
            queuedTitle: queuedTitle,
            baseTitle: baseTitle,
            documentsAlreadySynchronized: false
        ) {
        case .alreadySynchronized:
            return .replaceDocument(title: nil)
        case .updateTitleOnly:
            return .replaceDocument(title: queuedTitle)
        case .replaceDocument:
            return .replaceDocument(title: nil)
        case .conflict:
            return .conflict
        }
    }

    private static func titleDecision(
        serverTitle: String,
        queuedTitle: String,
        baseTitle: String?,
        documentsAlreadySynchronized: Bool
    ) -> Self {
        guard serverTitle != queuedTitle else { return .alreadySynchronized }
        guard let baseTitle else { return .conflict }

        let localTitleChanged = queuedTitle != baseTitle
        let remoteTitleChanged = serverTitle != baseTitle
        if localTitleChanged, remoteTitleChanged {
            return .conflict
        }
        if localTitleChanged {
            return .updateTitleOnly
        }
        return documentsAlreadySynchronized ? .alreadySynchronized : .replaceDocument(title: nil)
    }
}

nonisolated struct OfflinePageUpdateReplayConflict: LocalizedError, Sendable {
    let pageID: String

    var errorDescription: String? {
        "Page \(pageID) changed remotely after this offline draft was captured. The local draft was retained."
    }
}
