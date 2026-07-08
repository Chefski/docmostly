import SwiftUI

struct SpaceSettingsDetailView: View {
    @State private var viewModel: SpaceSettingsViewModel
    let canManage: Bool
    let showsCloseButton: Bool

    init(space: DocmostSpace, canManage: Bool, showsCloseButton: Bool = false) {
        _viewModel = State(initialValue: SpaceSettingsViewModel(space: space))
        self.canManage = canManage
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        SpaceSettingsDetailFormView(
            viewModel: viewModel,
            canManage: canManage,
            showsCloseButton: showsCloseButton
        )
    }
}
