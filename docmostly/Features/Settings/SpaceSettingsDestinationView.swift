import SwiftUI

struct SpaceSettingsDestinationView: View {
    @Environment(AppState.self) private var appState

    let spaceID: String
    let showsCloseButton: Bool

    init(spaceID: String, showsCloseButton: Bool = false) {
        self.spaceID = spaceID
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        Group {
            if let space {
                SpaceSettingsDetailView(
                    space: space,
                    canManage: canManage(space),
                    showsCloseButton: showsCloseButton
                )
                .id(space.id)
            } else {
                ContentUnavailableView("Space unavailable", systemImage: "square.stack.3d.up")
            }
        }
    }

    private var space: DocmostSpace? {
        appState.spaces.first { $0.id == spaceID }
    }

    private func canManage(_ space: DocmostSpace) -> Bool {
        SpaceManagementAuthorization.canManageSpace(
            workspaceRole: appState.currentUser?.user.role,
            membershipRole: space.membership?.role
        )
    }
}
