import SwiftUI

struct GroupCreateSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsManagementViewModel
    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Group") {
                    TextField("Name", text: $name)
                        .docmostlyTextInputAutocapitalization(.words)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...)
                }

                if let message = viewModel.errorMessage {
                    Section {
                        SettingsStatusMessageView(message: message, isError: true)
                    }
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", systemImage: "plus", action: createGroup)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func createGroup() {
        Task {
            isSaving = true
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            let success = await viewModel.createGroup(
                name: name,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                appState: appState
            )
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}
