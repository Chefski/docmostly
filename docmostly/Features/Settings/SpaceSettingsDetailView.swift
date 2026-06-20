import SwiftUI

struct SpaceSettingsDetailView: View {
    @State private var viewModel: SpaceSettingsViewModel
    let canManage: Bool

    init(space: DocmostSpace, canManage: Bool) {
        _viewModel = State(initialValue: SpaceSettingsViewModel(space: space))
        self.canManage = canManage
    }

    var body: some View {
        SpaceSettingsDetailFormView(viewModel: viewModel, canManage: canManage)
    }
}
