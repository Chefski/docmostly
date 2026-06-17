import SwiftUI

struct CommentsSectionView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PageReaderViewModel
    let pageID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)

            if appState.isOffline {
                Text("Comments are unavailable offline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Add a page comment", text: $viewModel.draftComment, axis: .vertical)
                    .lineLimit(3...)
                    .textFieldStyle(.roundedBorder)

                Button("Add Comment", systemImage: "text.bubble", action: postComment)
                    .buttonStyle(.borderedProminent)
                    .disabled(canPostComment == false)

                if let errorMessage = viewModel.commentErrorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(DocmostlyTheme.destructive)
                }
            }

            ForEach(viewModel.comments) { comment in
                CommentRowView(comment: comment)
            }
        }
    }

    private func postComment() {
        Task {
            await viewModel.postComment(pageID: pageID, appState: appState)
        }
    }

    private var canPostComment: Bool {
        viewModel.draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && viewModel.isPostingComment == false
    }
}
