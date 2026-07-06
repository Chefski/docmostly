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
            WorkspaceAccountMenuLabel(
                logo: appState.currentUser?.workspace.logo,
                name: workspaceName
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(workspaceName)
    }

    private var workspaceName: String {
        appState.currentUser?.workspace.name ?? "Workspace"
    }
}

private struct WorkspaceAccountMenuLabel: View {
    let logo: String?
    let name: String

    var body: some View {
        HStack(spacing: 7) {
            WorkspaceIconView(logo: logo, name: name, size: 32)

            Text(name)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .imageScale(.small)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.primary)
    }
}
