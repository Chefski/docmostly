import SwiftUI

#if os(macOS)
struct SpaceSettingsDialog: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsManagementViewModel()

    let space: DocmostSpace

    var body: some View {
        NavigationStack {
            SpaceSettingsDetailView(
                space: space,
                canManage: canManage,
                showsCloseButton: true
            )
        }
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            viewModel.seed(from: appState)
        }
    }

    private var canManage: Bool {
        viewModel.canManageWorkspace || space.membership?.role == "admin"
    }
}
#endif
