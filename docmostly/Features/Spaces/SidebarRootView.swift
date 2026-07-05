import SwiftUI

struct SidebarRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: sidebarSelection) {
            Section {
                NavigationLink(value: SidebarDestination.favorites) {
                    Label("Favorites", systemImage: "star")
                }
                NavigationLink(value: SidebarDestination.notifications) {
                    Label("Notifications", systemImage: "bell")
                }
                NavigationLink(value: SidebarDestination.search) {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }

            Section("Spaces") {
                ForEach(appState.spaces) { space in
                    NavigationLink(value: SidebarDestination.space(space.id)) {
                        SpaceRowView(space: space)
                    }
                }

                if appState.spaces.isEmpty {
                    Text(appState.isOffline ? "No cached spaces" : "No spaces")
                        .foregroundStyle(.secondary)
                }
            }

            if appState.isOffline {
                OfflineBadgeView(text: "Offline")
                    .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("Docmostly")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                WorkspaceAccountMenu()
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        .refreshable {
            await appState.loadSpaces()
        }
    }

    private var sidebarSelection: Binding<SidebarDestination?> {
        Binding {
            appState.selectedSidebarDestination
        } set: { destination in
            appState.selectSidebarDestination(destination)
        }
    }
}

private struct WorkspaceAccountMenu: View {
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

private struct WorkspaceIconView: View {
    @Environment(AppState.self) private var appState

    let logo: String?
    let name: String

    var body: some View {
        Group {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        WorkspaceIconFallbackView(initial: initial)
                    @unknown default:
                        WorkspaceIconFallbackView(initial: initial)
                    }
                }
            } else {
                WorkspaceIconFallbackView(initial: initial)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    private var logoURL: URL? {
        SpaceLogoURL.url(logo: logo, serverURLString: appState.serverURLString)
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }
}

private struct WorkspaceIconFallbackView: View {
    let initial: String

    var body: some View {
        ZStack {
            DocmostlyTheme.primary.opacity(0.12)
            Text(initial)
                .font(.caption)
                .bold()
                .foregroundStyle(DocmostlyTheme.primary)
        }
    }
}
