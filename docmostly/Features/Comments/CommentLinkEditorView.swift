import SwiftUI

struct CommentLinkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var href = ""
    @State private var errorMessage: String?

    let draft: CommentComposerState

    var body: some View {
        NavigationStack {
            Form {
                TextField("Link", text: $href, prompt: Text("https://example.com"))
                    .textContentType(.URL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .onSubmit(applyLink)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(DocmostlyTheme.destructive)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: applyLink)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 220)
    }

    private func applyLink() {
        do {
            try draft.applyLink(href)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
