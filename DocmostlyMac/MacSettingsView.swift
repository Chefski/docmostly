import AppKit
import Observation
import SwiftUI

enum MacSettingsTab: String, CaseIterable, Identifiable {
    case workspace
    case account
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .workspace:
            "Workspace"
        case .account:
            "Account"
        case .about:
            "About"
        }
    }

    var systemImage: String {
        switch self {
        case .workspace:
            "building.2"
        case .account:
            "person.crop.circle"
        case .about:
            "info.circle"
        }
    }
}

@MainActor
@Observable
final class MacSettingsNavigation {
    static let shared = MacSettingsNavigation()

    var selectedTab: MacSettingsTab? = .workspace

    private init() {}
}

struct MacSettingsView: View {
    @State private var navigation = MacSettingsNavigation.shared
    @State private var navigationHistory: [MacSettingsTab] = [.workspace]
    @State private var historyIndex = 0

    private var activeTab: MacSettingsTab {
        navigation.selectedTab ?? .workspace
    }

    var body: some View {
        @Bindable var navigation = navigation

        NavigationSplitView(columnVisibility: .constant(.all)) {
            MacSettingsSidebarView(selectedTab: $navigation.selectedTab)
                .frame(width: 210)
                .navigationSplitViewColumnWidth(
                    min: 210,
                    ideal: 210,
                    max: 210
                )
                .toolbar(removing: .sidebarToggle)
        } detail: {
            MacSettingsDetailView(tab: activeTab)
        }
        .navigationTitle("Settings")
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 680, minHeight: 520)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button("Back", systemImage: "chevron.left", action: goBack)
                    .labelStyle(.iconOnly)
                    .disabled(canGoBack == false)

                Button("Forward", systemImage: "chevron.right", action: goForward)
                    .labelStyle(.iconOnly)
                    .disabled(canGoForward == false)
            }
        }
        .onChange(of: navigation.selectedTab) { _, _ in
            recordNavigation()
        }
    }

    private var canGoBack: Bool {
        historyIndex > 0
    }

    private var canGoForward: Bool {
        historyIndex < navigationHistory.count - 1
    }

    private func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        navigation.selectedTab = navigationHistory[historyIndex]
    }

    private func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        navigation.selectedTab = navigationHistory[historyIndex]
    }

    private func recordNavigation() {
        let tab = activeTab
        if navigationHistory.indices.contains(historyIndex), navigationHistory[historyIndex] == tab {
            return
        }

        if historyIndex < navigationHistory.count - 1 {
            navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
        }

        navigationHistory.append(tab)
        historyIndex = navigationHistory.count - 1
    }
}

private struct MacSettingsSidebarView: View {
    @Binding var selectedTab: MacSettingsTab?

    var body: some View {
        List(selection: $selectedTab) {
            ForEach(MacSettingsTab.allCases) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }

            MacSettingsVersionFooter()
        }
        .listStyle(.sidebar)
        .scrollEdgeEffectStyleSoftIfAvailable()
        .navigationTitle("Settings")
    }
}

private struct MacSettingsVersionFooter: View {
    var body: some View {
        Text(MacAppVersion.displayString)
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 6, trailing: 0))
    }
}

private struct MacSettingsDetailView: View {
    let tab: MacSettingsTab

    var body: some View {
        Group {
            switch tab {
            case .workspace:
                MacWorkspaceSettingsPane()
            case .account:
                MacAccountSettingsPane()
            case .about:
                MacAboutSettingsPane()
            }
        }
        .navigationTitle(tab.title)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MacWorkspaceSettingsPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Workspace") {
                LabeledContent("Server", value: serverValue)

                if let currentUser = appState.currentUser {
                    LabeledContent("Workspace", value: currentUser.workspace.name)
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
        }
        .macSettingsFormStyle()
    }

    private var serverValue: String {
        appState.serverURLString.isEmpty ? "Not configured" : appState.serverURLString
    }
}

private struct MacAccountSettingsPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Account") {
                if let currentUser = appState.currentUser {
                    LabeledContent("Name", value: currentUser.user.name)

                    if let email = currentUser.user.email {
                        LabeledContent("Email", value: email)
                    }
                } else {
                    LabeledContent("Session", value: "Not signed in")
                }
            }

            if appState.phase == .authenticated {
                Section {
                    Button("Log Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task {
                            await appState.logout()
                        }
                    }
                }
            }
        }
        .macSettingsFormStyle()
    }
}

private struct MacAboutSettingsPane: View {
    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Docmostly")
                            .font(.largeTitle.bold())

                        Text(MacAppVersion.displayString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Native Docmost client for Apple platforms.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Project") {
                if let docmostURL = URL(string: "https://docmost.com") {
                    Link("Docmost", destination: docmostURL)
                }
            }
        }
        .macSettingsFormStyle()
    }
}

private enum MacAppVersion {
    static let displayString: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "Version \(version) (\(build))"
    }()
}

private extension View {
    func macSettingsFormStyle() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
    }

    @ViewBuilder
    func scrollEdgeEffectStyleSoftIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
