import SwiftUI

nonisolated struct PageOpenTarget: Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let spaceId: String?
    let revealSpaceInSidebar: Bool
    let commentId: String?

    init(
        id: String,
        slugId: String,
        spaceId: String?,
        revealSpaceInSidebar: Bool = false,
        commentId: String? = nil
    ) {
        self.id = id
        self.slugId = slugId
        self.spaceId = spaceId
        self.revealSpaceInSidebar = revealSpaceInSidebar
        self.commentId = commentId
    }

    init(page: DocmostPage, revealSpaceInSidebar: Bool = false) {
        self.init(
            id: page.id,
            slugId: page.slugId,
            spaceId: page.spaceId,
            revealSpaceInSidebar: revealSpaceInSidebar
        )
    }

    init(item: PageBrowserItem, revealSpaceInSidebar: Bool = false) {
        self.init(
            id: item.id,
            slugId: item.slugId,
            spaceId: item.spaceId,
            revealSpaceInSidebar: revealSpaceInSidebar
        )
    }

    init(searchResult: DocmostSearchResult, revealSpaceInSidebar: Bool = false) {
        self.init(
            id: searchResult.id,
            slugId: searchResult.slugId,
            spaceId: searchResult.space.id,
            revealSpaceInSidebar: revealSpaceInSidebar
        )
    }

    init?(favorite: DocmostFavorite, revealSpaceInSidebar: Bool = false) {
        guard favorite.type == .page else { return nil }

        if let page = favorite.page {
            self.init(
                id: page.id,
                slugId: page.slugId,
                spaceId: page.spaceId,
                revealSpaceInSidebar: revealSpaceInSidebar
            )
            return
        }

        guard let pageID = favorite.pageId else { return nil }
        self.init(
            id: pageID,
            slugId: pageID,
            spaceId: favorite.spaceId,
            revealSpaceInSidebar: revealSpaceInSidebar
        )
    }

    init?(notification: DocmostNotification, revealSpaceInSidebar: Bool = false) {
        guard let page = notification.page else { return nil }

        self.init(
            id: page.id,
            slugId: page.slugId,
            spaceId: notification.spaceId ?? notification.space?.id,
            revealSpaceInSidebar: revealSpaceInSidebar,
            commentId: notification.commentId
        )
    }
}

struct PageOpenLink<Label: View>: View {
    @Environment(AppState.self) private var appState
    @Environment(\.pageOpenPresentation) private var pageOpenPresentation

    let target: PageOpenTarget
    let label: () -> Label

    init(target: PageOpenTarget, @ViewBuilder label: @escaping () -> Label) {
        self.target = target
        self.label = label
    }

    var body: some View {
        #if os(macOS)
        Button {
            appState.openPage(target)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        #else
        if pageOpenPresentation == .stack {
            NavigationLink(value: target) {
                label()
            }
            .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            Button {
                appState.openPage(target)
            } label: {
                label()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
        #endif
    }

    private var accessibilityIdentifier: String {
        "PageOpenLink.\(target.slugId)"
    }
}

struct PageOpenDestinationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.pageOpenPresentation) private var pageOpenPresentation

    let target: PageOpenTarget

    var body: some View {
        PageReaderView(pageID: target.slugId, initialCommentID: target.commentId)
            .task(id: target.id) {
                appState.openPage(target)
            }
            .onDisappear {
                guard pageOpenPresentation.shouldClearSelectedPageOnReaderDisappear else { return }
                appState.clearSelectedPage(ifMatching: target.slugId)
            }
    }
}

extension View {
    @ViewBuilder
    func pageOpenDestination() -> some View {
        #if os(iOS)
        navigationDestination(for: PageOpenTarget.self) { target in
            PageOpenDestinationView(target: target)
        }
        #else
        self
        #endif
    }
}
