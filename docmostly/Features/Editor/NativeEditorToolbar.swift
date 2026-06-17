import SwiftUI

struct NativeEditorToolbar: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    @State private var isShowingLinkPrompt = false
    @State private var isShowingSearchReplace = false
    @State private var isShowingStatusPrompt = false
    @State private var isShowingMentionPrompt = false
    @State private var isShowingCommentPrompt = false
    @State private var isShowingMathPrompt = false
    @State private var linkURLString = ""
    @State private var statusText = ""
    @State private var mentionText = ""
    @State private var commentID = ""
    @State private var inlineMathText = ""

    let dismissKeyboard: () -> Void

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
                        isShowingMentionPrompt: $isShowingMentionPrompt,
                        isShowingCommentPrompt: $isShowingCommentPrompt,
                        isShowingMathPrompt: $isShowingMathPrompt
                    )

                    Divider()
                        .frame(height: 28)

                    NativeEditorAlignmentToolbarGroup(
                        viewModel: viewModel,
                        isShowingLinkPrompt: $isShowingLinkPrompt
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
        .alert("Mention", isPresented: $isShowingMentionPrompt) {
            TextField("Label", text: $mentionText)
            Button("Insert") {
                viewModel.insertMention(NativeEditorMention(label: mentionText, entityType: "page"))
                mentionText = ""
            }
            Button("Cancel", role: .cancel) {
                mentionText = ""
            }
        }
        .alert("Inline Comment", isPresented: $isShowingCommentPrompt) {
            TextField("Comment ID", text: $commentID)
                .textInputAutocapitalization(.never)
            Button("Apply") {
                viewModel.applyInlineComment(commentID: commentID)
                commentID = ""
            }
            Button("Cancel", role: .cancel) {
                commentID = ""
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
