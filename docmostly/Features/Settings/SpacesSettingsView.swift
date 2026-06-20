import SwiftUI

struct SpacesSettingsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: SettingsManagementViewModel
    @State private var searchText = ""
    @State private var isShowingCreateSpace = false

    var body: some View {
        List {
            ForEach(filteredSpaces) { space in
                NavigationLink {
                    SpaceSettingsDetailView(space: space, canManage: canManage(space))
                } label: {
                    SpaceRowView(space: space)
                }
            }

            if filteredSpaces.isEmpty {
                ContentUnavailableView.search
            }
        }
        .navigationTitle("Spaces")
        .searchable(text: $searchText, prompt: "Search spaces")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Space", systemImage: "plus", action: showCreateSpace)
                    .disabled(viewModel.canManageWorkspace == false)
            }
        }
        .sheet(isPresented: $isShowingCreateSpace) {
            SpaceCreateSheet()
        }
        .task {
            viewModel.seed(from: appState)
            await appState.loadSpaces()
        }
    }

    private var filteredSpaces: [DocmostSpace] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return appState.spaces }
        return appState.spaces.filter { space in
            space.name.localizedStandardContains(trimmed) ||
            space.slug.localizedStandardContains(trimmed) ||
            (space.description?.localizedStandardContains(trimmed) ?? false)
        }
    }

    private func showCreateSpace() {
        isShowingCreateSpace = true
    }

    private func canManage(_ space: DocmostSpace) -> Bool {
        viewModel.canManageWorkspace || space.membership?.role == "admin"
    }
}
