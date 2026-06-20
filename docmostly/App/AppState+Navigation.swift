import Foundation

extension AppState {
    func selectSidebarDestination(_ destination: SidebarDestination?) {
        selectedSidebarDestination = destination

        if case .space(let spaceID) = destination {
            selectSpace(id: spaceID)
        }
    }

    func selectSidebarUtilityDestination(_ destination: SidebarDestination) {
        if case .space(let spaceID) = destination {
            selectSpace(id: spaceID)
            return
        }

        selectedSidebarDestination = destination
        selectedPageID = nil
    }

    func selectSpace(id spaceID: String, clearsPage: Bool = true) {
        selectedSpaceID = spaceID
        selectedSidebarDestination = .space(spaceID)

        if clearsPage {
            selectedPageID = nil
        }
    }

    func selectPage(id pageID: String, spaceID: String? = nil, revealSpaceInSidebar: Bool = false) {
        if let spaceID {
            selectedSpaceID = spaceID

            if revealSpaceInSidebar {
                selectedSidebarDestination = .space(spaceID)
            }
        }

        selectedPageID = pageID
    }

    func clearSelectedPage() {
        selectedPageID = nil
    }

    func resetNavigationSelection() {
        selectedSidebarDestination = nil
        selectedSpaceID = nil
        selectedPageID = nil
    }

    func selectDefaultSpaceIfNeeded() {
        if let selectedSpaceID, spaces.contains(where: { $0.id == selectedSpaceID }) {
            if selectedSidebarDestination == nil {
                selectedSidebarDestination = .space(selectedSpaceID)
            }
            return
        }

        let shouldRevealDefaultSpace = switch selectedSidebarDestination {
        case nil, .space:
            true
        case .favorites, .notifications, .search, .settings:
            false
        }

        selectedSpaceID = nil
        selectedPageID = nil

        guard let firstSpaceID = spaces.first?.id else {
            if shouldRevealDefaultSpace {
                selectedSidebarDestination = nil
            }
            return
        }

        selectedSpaceID = firstSpaceID

        if shouldRevealDefaultSpace {
            selectedSidebarDestination = .space(firstSpaceID)
        }
    }
}
