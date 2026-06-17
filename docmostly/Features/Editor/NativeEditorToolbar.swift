import SwiftUI

struct NativeEditorToolbar: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    @State private var isShowingLinkPrompt = false
    @State private var linkURLString = ""

    let dismissKeyboard: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(NativeEditorCommand.allCases) { command in
                    Button {
                        viewModel.applySlashCommand(command)
                    } label: {
                        Label(command.title, systemImage: command.systemImage)
                    }
                    .accessibilityLabel(command.title)
                }

                Divider()
                    .frame(height: 28)

                Button {
                    viewModel.toggleInlineMark(.bold)
                } label: {
                    Label("Bold", systemImage: "bold")
                }

                Button {
                    viewModel.toggleInlineMark(.italic)
                } label: {
                    Label("Italic", systemImage: "italic")
                }

                Button {
                    viewModel.toggleInlineMark(.underline)
                } label: {
                    Label("Underline", systemImage: "underline")
                }

                Button {
                    viewModel.toggleInlineMark(.strikethrough)
                } label: {
                    Label("Strikethrough", systemImage: "strikethrough")
                }

                Button {
                    viewModel.toggleInlineMark(.code)
                } label: {
                    Label("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Button {
                    viewModel.toggleInlineMark(.subscript)
                } label: {
                    Label("Subscript", systemImage: "textformat.subscript")
                }

                Button {
                    viewModel.toggleInlineMark(.superscript)
                } label: {
                    Label("Superscript", systemImage: "textformat.superscript")
                }

                Divider()
                    .frame(height: 28)

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

                Divider()
                    .frame(height: 28)

                Button(action: viewModel.appendBlock) {
                    Label("Add Block", systemImage: "plus")
                }

                Button(action: dismissKeyboard) {
                    Label("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .labelStyle(.iconOnly)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .alert("Link", isPresented: $isShowingLinkPrompt) {
            TextField("URL", text: $linkURLString)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Button("Apply") {
                viewModel.applyLink(linkURLString)
                linkURLString = ""
            }
            Button("Remove", role: .destructive) {
                viewModel.removeLink()
                linkURLString = ""
            }
            Button("Cancel", role: .cancel) {
                linkURLString = ""
            }
        }
    }
}
