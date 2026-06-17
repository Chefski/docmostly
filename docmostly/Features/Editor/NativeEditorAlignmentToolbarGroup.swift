import SwiftUI

struct NativeEditorAlignmentToolbarGroup: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    @Binding var isShowingLinkPrompt: Bool

    var body: some View {
        Menu {
            Button("Left", systemImage: "text.alignleft") {
                viewModel.setActiveAlignment(.left)
            }
            Button("Center", systemImage: "text.aligncenter") {
                viewModel.setActiveAlignment(.center)
            }
            Button("Right", systemImage: "text.alignright") {
                viewModel.setActiveAlignment(.right)
            }
        } label: {
            Label("Alignment", systemImage: "text.alignleft")
        }
        .accessibilityLabel("Alignment")

        Button {
            isShowingLinkPrompt = true
        } label: {
            Label("Link", systemImage: "link")
        }
        .keyboardShortcut("k", modifiers: .command)
    }
}
