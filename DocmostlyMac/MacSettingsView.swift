import SwiftUI

struct MacSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            Form {
                Section("Workspace") {
                    LabeledContent("Server", value: serverValue)

                    if let currentUser = appState.currentUser {
                        LabeledContent("Workspace", value: currentUser.workspace.name)
                        LabeledContent("Signed in as", value: currentUser.user.name)

                        if let email = currentUser.user.email {
                            LabeledContent("Email", value: email)
                        }
                    } else {
                        LabeledContent("Session", value: "Not signed in")
                    }
                }

                Section("Local Data") {
                    Button("Clear Offline Cache", systemImage: "trash", role: .destructive) {
                        Task {
                            await appState.clearCache()
                        }
                    }
                }

                if appState.phase == .authenticated {
                    Section("Account") {
                        Button("Log Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            Task {
                                await appState.logout()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 520, height: 320)
        .scenePadding()
    }

    private var serverValue: String {
        appState.serverURLString.isEmpty ? "Not configured" : appState.serverURLString
    }
}
