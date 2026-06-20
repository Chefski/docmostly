import SwiftUI

struct PageCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let request: PageCreationRequest
    let create: (String) async -> String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    LabeledContent("Location", value: request.destinationName)
                }

                Section("Page") {
                    TextField("Untitled", text: $title)
                        .docmostlyTextInputAutocapitalization(.sentences)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DocmostlyTheme.destructive)
                    }
                }
            }
            .navigationTitle("New Page")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", systemImage: "plus", action: createPage)
                        .disabled(isSaving)
                }
            }
        }
    }

    private func createPage() {
        Task {
            isSaving = true
            errorMessage = nil
            let message = await create(title)
            isSaving = false
            if let message {
                errorMessage = message
            } else {
                dismiss()
            }
        }
    }
}
