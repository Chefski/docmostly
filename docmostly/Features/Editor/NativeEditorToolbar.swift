import SwiftUI

struct NativeEditorToolbar: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    @State private var isShowingLinkPrompt = false
    @State private var isShowingSearchReplace = false
    @State private var isShowingStatusPrompt = false
    @State private var isShowingMathPrompt = false
    @State private var linkURLString = ""
    @State private var statusText = ""
    @State private var inlineMathText = ""

    let isUploadingAttachment: Bool
    let importAttachment: (NativeEditorAttachmentImportKind) -> Void
    let applyCommand: ((NativeEditorCommand) -> Void)?
    let showMentionPicker: () -> Void
    let showInlineCommentComposer: () -> Void
    let dismissKeyboard: () -> Void

    init(
        viewModel: NativeRichEditorViewModel,
        isUploadingAttachment: Bool = false,
        importAttachment: @escaping (NativeEditorAttachmentImportKind) -> Void = { _ in },
        applyCommand: ((NativeEditorCommand) -> Void)? = nil,
        showMentionPicker: @escaping () -> Void = {},
        showInlineCommentComposer: @escaping () -> Void = {},
        dismissKeyboard: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.isUploadingAttachment = isUploadingAttachment
        self.importAttachment = importAttachment
        self.applyCommand = applyCommand
        self.showMentionPicker = showMentionPicker
        self.showInlineCommentComposer = showInlineCommentComposer
        self.dismissKeyboard = dismissKeyboard
    }

    var body: some View {
        VStack(spacing: 10) {
            if isShowingSearchReplace {
                NativeEditorToolbarSurface {
                    NativeEditorSearchReplaceBar(viewModel: viewModel)
                }
            }

            ScrollView(.horizontal) {
                toolbarContent
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.bottom, 6)
        .alert("Link", isPresented: $isShowingLinkPrompt) {
            TextField("URL", text: $linkURLString)
                .docmostlyTextInputAutocapitalization(.never)
                .docmostlyKeyboardType(.url)
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
        .alert("Status", isPresented: $isShowingStatusPrompt) {
            TextField("Text", text: $statusText)
            Button("Insert") {
                viewModel.insertStatusBadge(text: statusText, color: "green")
                statusText = ""
            }
            Button("Cancel", role: .cancel) {
                statusText = ""
            }
        }
        .alert("Math", isPresented: $isShowingMathPrompt) {
            TextField("Expression", text: $inlineMathText)
            Button("Insert") {
                viewModel.insertInlineMath(inlineMathText)
                inlineMathText = ""
            }
            Button("Cancel", role: .cancel) {
                inlineMathText = ""
            }
        }
    }

    @ViewBuilder
    private var toolbarContent: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: NativeEditorToolbarMetrics.groupSpacing) {
                toolbarGroups
            }
        } else {
            toolbarGroups
        }
    }

    private var toolbarGroups: some View {
        HStack(spacing: NativeEditorToolbarMetrics.groupSpacing) {
            NativeEditorToolbarSurface {
                NativeEditorHistoryToolbarGroup(viewModel: viewModel)
            }

            NativeEditorToolbarSurface {
                NativeEditorBlockCommandMenu(viewModel: viewModel, applyCommand: applyCommand)
            }

            NativeEditorToolbarSurface {
                NativeEditorQuickFormattingToolbarGroup(
                    viewModel: viewModel,
                    isShowingLinkPrompt: $isShowingLinkPrompt
                )
            }

            NativeEditorToolbarSurface {
                NativeEditorAttachmentToolbarGroup(
                    isUploading: isUploadingAttachment,
                    importAttachment: importAttachment
                )
                NativeEditorPasteToolbarButton(viewModel: viewModel)
                NativeEditorMoreToolbarMenu(
                    viewModel: viewModel,
                    isShowingSearchReplace: $isShowingSearchReplace,
                    isShowingStatusPrompt: $isShowingStatusPrompt,
                    isShowingMathPrompt: $isShowingMathPrompt,
                    showMentionPicker: showMentionPicker,
                    showInlineCommentComposer: showInlineCommentComposer
                )
                Button(action: dismissKeyboard) {
                    Label("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down")
                }
                .nativeEditorToolbarControlFrame()
            }
        }
        .buttonStyle(.plain)
        .controlSize(.regular)
        .labelStyle(.iconOnly)
    }
}
