import Foundation

nonisolated struct MacSidebarSelectionState {
    let destination: SidebarDestination?
    let selectedPageID: String?

    func isOverviewSelected(spaceID: String) -> Bool {
        destination == .space(spaceID) && selectedPageID == nil
    }

    func isUtilitySelected(_ utility: SidebarDestination) -> Bool {
        switch utility {
        case .favorites, .notifications, .search, .settings:
            destination == utility
        case .space:
            false
        }
    }

    func isPageSelected(slugID: String, spaceID: String) -> Bool {
        destination == .space(spaceID) && selectedPageID == slugID
    }
}
