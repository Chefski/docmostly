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
    let showMentionPicker: () -> Void
    let showInlineCommentComposer: () -> Void
    let dismissKeyboard: () -> Void

    init(
        viewModel: NativeRichEditorViewModel,
        isUploadingAttachment: Bool = false,
        importAttachment: @escaping (NativeEditorAttachmentImportKind) -> Void = { _ in },
        showMentionPicker: @escaping () -> Void = {},
        showInlineCommentComposer: @escaping () -> Void = {},
        dismissKeyboard: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.isUploadingAttachment = isUploadingAttachment
        self.importAttachment = importAttachment
        self.showMentionPicker = showMentionPicker
        self.showInlineCommentComposer = showInlineCommentComposer
        self.dismissKeyboard = dismissKeyboard
    }

    var body: some View {
        VStack(spacing: 8) {
            if isShowingSearchReplace {
                NativeEditorSearchReplaceBar(viewModel: viewModel)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    NativeEditorHistoryToolbarGroup(viewModel: viewModel)

                    Divider()
                        .frame(height: 28)

                    NativeEditorBlockCommandToolbarGroup(viewModel: viewModel)

                    Divider()
                        .frame(height: 28)

                    NativeEditorFormattingToolbarGroup(
                        viewModel: viewModel,
                        isShowingStatusPrompt: $isShowingStatusPrompt,
                        isShowingMathPrompt: $isShowingMathPrompt,
                        showMentionPicker: showMentionPicker,
                        showInlineCommentComposer: showInlineCommentComposer
                    )

                    Divider()
                        .frame(height: 28)

                    NativeEditorAlignmentToolbarGroup(
                        viewModel: viewModel,
                        isShowingLinkPrompt: $isShowingLinkPrompt
                    )

                    Divider()
                        .frame(height: 28)

                    NativeEditorAttachmentToolbarGroup(
                        isUploading: isUploadingAttachment,
                        importAttachment: importAttachment
                    )

                    Divider()
                        .frame(height: 28)

                    NativeEditorClipboardToolbarGroup(
                        viewModel: viewModel,
                        isShowingSearchReplace: $isShowingSearchReplace
                    )

                    Divider()
                        .frame(height: 28)

                    NativeEditorBlockActionsToolbarGroup(
                        viewModel: viewModel,
                        dismissKeyboard: dismissKeyboard
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .labelStyle(.iconOnly)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
        .padding(.horizontal, 10)
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
}
