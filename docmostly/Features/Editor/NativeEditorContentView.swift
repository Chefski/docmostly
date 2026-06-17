import SwiftUI

struct NativeEditorContentView: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    let focusedField: FocusState<NativeEditorFocus?>.Binding

    var body: some View {
        ScrollView {
            NativeEditorBodyView(viewModel: viewModel, focusedField: focusedField)
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
