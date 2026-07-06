import SwiftUI

struct WorkspaceAccountMenu: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            Button("Settings", systemImage: "gearshape") {
                appState.selectSidebarUtilityDestination(.settings)
            }

            Button("Log Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                Task {
                    await appState.logout()
                }
            }
        } label: {
            Label {
                Text(workspaceName)
            } icon: {
                WorkspaceIconView(
                    logo: appState.currentUser?.workspace.logo,
                    name: workspaceName
                )
            }
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(workspaceName)
    }

    private var workspaceName: String {
        appState.currentUser?.workspace.name ?? "Workspace"
    }
}
