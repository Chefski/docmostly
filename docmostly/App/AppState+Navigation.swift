import Foundation

extension AppState {
    func selectSidebarDestination(_ destination: SidebarDestination?) {
        let resolvedDestination = destination ?? sidebarReturnDestination
        sidebarReturnDestination = nil
        selectedSidebarDestination = resolvedDestination

        if case .space(let spaceID) = resolvedDestination {
            selectSpace(id: spaceID)
        }
    }

    func selectSidebarUtilityDestination(
        _ destination: SidebarDestination,
        returningTo returnDestination: SidebarDestination? = nil
    ) {
        if case .space(let spaceID) = destination {
            selectSpace(id: spaceID)
            return
        }

        sidebarReturnDestination = returnDestination
        selectedSidebarDestination = destination
        selectedPageID = nil
        selectedCommentID = nil
    }

    func selectSpace(id spaceID: String, clearsPage: Bool = true) {
        sidebarReturnDestination = nil
        selectedSpaceID = spaceID
        selectedSidebarDestination = .space(spaceID)
        rememberSelectedSpace(id: spaceID)

        if clearsPage {
            selectedPageID = nil
            selectedCommentID = nil
        }
    }

    func selectPage(
        id pageID: String,
        spaceID: String? = nil,
        revealSpaceInSidebar: Bool = false,
        commentID: String? = nil
    ) {
        if let spaceID {
            selectedSpaceID = spaceID
            rememberSelectedSpace(id: spaceID)

            if revealSpaceInSidebar {
                selectedSidebarDestination = .space(spaceID)
            }
        }

        selectedPageID = pageID
        selectedCommentID = commentID
    }

    func openPage(_ target: PageOpenTarget) {
        selectPage(
            id: target.slugId,
            spaceID: target.spaceId,
            revealSpaceInSidebar: target.revealSpaceInSidebar,
            commentID: target.commentId
        )
    }

    func clearSelectedPage() {
        selectedPageID = nil
        selectedCommentID = nil
    }

    func clearSelectedPage(ifMatching pageID: String) {
        guard selectedPageID == pageID else { return }
        clearSelectedPage()
    }

    func resetNavigationSelection() {
        sidebarReturnDestination = nil
        selectedSidebarDestination = nil
        selectedSpaceID = nil
        selectedPageID = nil
        selectedCommentID = nil
    }

    func selectDefaultSpaceIfNeeded() {
        if let selectedSpaceID, spaces.contains(where: { $0.id == selectedSpaceID }) {
            if selectedSidebarDestination == nil {
                selectedSidebarDestination = .space(selectedSpaceID)
            }
            return
        }

        let rememberedSpaceID = cacheScope
            .flatMap(settingsStore.loadLastSelectedSpaceID(for:))
            .flatMap { rememberedSpaceID in
                spaces.contains(where: { $0.id == rememberedSpaceID }) ? rememberedSpaceID : nil
            }

        let shouldRevealDefaultSpace = switch selectedSidebarDestination {
        case nil, .space:
            true
        case .favorites, .notifications, .search, .settings:
            false
        }

        selectedSpaceID = nil
        selectedPageID = nil
        selectedCommentID = nil

        guard let defaultSpaceID = rememberedSpaceID ?? spaces.first?.id else {
            if shouldRevealDefaultSpace {
                selectedSidebarDestination = nil
            }
            return
        }

        selectedSpaceID = defaultSpaceID
        rememberSelectedSpace(id: defaultSpaceID)

        if shouldRevealDefaultSpace {
            selectedSidebarDestination = .space(defaultSpaceID)
        }
    }

    private func rememberSelectedSpace(id spaceID: String) {
        guard let cacheScope else { return }
        settingsStore.saveLastSelectedSpaceID(spaceID, for: cacheScope)
    }
}
