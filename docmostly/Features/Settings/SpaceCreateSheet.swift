import SwiftUI

struct SpaceCreateSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SpaceSettingsDraft()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Space") {
                    TextField("Name", text: $draft.name)
                        .docmostlyTextInputAutocapitalization(.words)
                        .onChange(of: draft.name) { _, newValue in
                            draft.setName(newValue)
                        }
                    TextField("Slug", text: $draft.slug)
                        .docmostlyTextInputAutocapitalization(.never)
                    TextField("Description", text: $draft.description, axis: .vertical)
                        .lineLimit(2...)
                }

                if let validationMessage = draft.validationMessage, shouldShowValidation {
                    Section {
                        SettingsStatusMessageView(message: validationMessage, isError: true)
                    }
                } else if let errorMessage {
                    Section {
                        SettingsStatusMessageView(message: errorMessage, isError: true)
                    }
                }
            }
            .navigationTitle("New Space")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", systemImage: "plus", action: createSpace)
                        .disabled(draft.canCreate == false || isSaving)
                }
            }
        }
    }

    private func createSpace() {
        Task {
            isSaving = true
            errorMessage = nil
            defer { isSaving = false }

            do {
                _ = try await appState.createSpace(
                    name: draft.createName,
                    description: draft.createDescription,
                    slug: draft.createSlug
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var shouldShowValidation: Bool {
        draft.name.isEmpty == false ||
        draft.slug.isEmpty == false ||
        draft.description.isEmpty == false
    }
}
