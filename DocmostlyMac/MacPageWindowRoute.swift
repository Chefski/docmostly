import Foundation

struct MacPageWindowRoute: Codable, Hashable, Identifiable, Sendable {
    let pageID: String
    let spaceID: String?
    let title: String?

    var id: String {
        [spaceID, pageID].compactMap(\.self).joined(separator: ":")
    }

    var displayTitle: String {
        guard let title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return "Page"
        }

        return title
    }

    @MainActor
    static func selectedPageRoute(from appState: AppState) -> MacPageWindowRoute? {
        guard let selectedPageID = appState.selectedPageID else { return nil }
        guard let selectedSpaceID = appState.selectedSpaceID else { return nil }

        return MacPageWindowRoute(
            pageID: selectedPageID,
            spaceID: selectedSpaceID,
            title: nil
        )
    }
}
