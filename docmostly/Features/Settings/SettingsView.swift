import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Account") {
                if let currentUser = appState.currentUser {
                    LabeledContent("Name", value: currentUser.user.name)
                    LabeledContent("Email", value: currentUser.user.email ?? "Unavailable")
                    LabeledContent("Workspace", value: currentUser.workspace.name)
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
