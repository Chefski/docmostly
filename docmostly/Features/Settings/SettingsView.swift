import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsManagementViewModel()

    var body: some View {
        List {
            Section {
                NavigationLink(value: SettingsDestination.account) {
                    SettingsSectionRowView(
                        title: "Account",
                        subtitle: appState.currentUser?.user.email ?? "Profile and preferences",
                        systemImage: "person.crop.circle"
                    )
                }
            }

            Section("Workspace") {
                NavigationLink(value: SettingsDestination.workspace) {
                    SettingsSectionRowView(
                        title: "Workspace",
                        subtitle: appState.currentUser?.workspace.name ?? "Name and security",
                        systemImage: "building.2"
                    )
                }
                NavigationLink(value: SettingsDestination.members) {
                    SettingsSectionRowView(
                        title: "Members",
                        subtitle: "People and roles",
                        systemImage: "person.2"
                    )
                }
                NavigationLink(value: SettingsDestination.spaces) {
                    SettingsSectionRowView(
                        title: "Spaces",
                        subtitle: "Space details and access",
                        systemImage: "square.stack.3d.up"
                    )
                }
                NavigationLink(value: SettingsDestination.groups) {
                    SettingsSectionRowView(
                        title: "Groups",
                        subtitle: "Reusable member groups",
                        systemImage: "person.3"
                    )
                }
            }

            Section("Server") {
                LabeledContent("URL", value: appState.serverURLString)
            }

            Section("Offline") {
                Button("Clear Offline Cache", systemImage: "trash", role: .destructive, action: clearCache)
            }

            Section("App") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Theme", value: "System")
            }

            Section {
                Button("Log Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive, action: logout)
            }
        }
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsDestination.self) { destination in
            switch destination {
            case .account:
                AccountSettingsView(viewModel: viewModel)
            case .workspace:
                WorkspaceSettingsView(viewModel: viewModel)
            case .members:
                WorkspaceMembersSettingsView(viewModel: viewModel)
            case .spaces:
                SpacesSettingsView(viewModel: viewModel)
            case .groups:
                GroupsSettingsView(viewModel: viewModel)
            }
        }
        .task {
            viewModel.seed(from: appState)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func clearCache() {
        appState.clearCache()
    }

    private func logout() {
        Task {
            await appState.logout()
        }
    }
}
