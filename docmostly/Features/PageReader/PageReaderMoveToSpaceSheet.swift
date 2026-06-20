import SwiftUI

struct PageReaderMoveToSpaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpaceID: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    let pageTitle: String
    let currentSpaceID: String
    let spaces: [DocmostSpace]
    let move: (String) async -> String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(spaces.filter { $0.id != currentSpaceID }) { space in
                        Button {
                            selectedSpaceID = space.id
                        } label: {
                            HStack {
                                SpaceIconView(space: space)
                                Text(space.name)
                                Spacer()
                                if selectedSpaceID == space.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(DocmostlyTheme.primary)
                                }
                            }
                        }
                    }
                } header: {
                    Text(pageTitle.isEmpty ? "Move page" : pageTitle)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DocmostlyTheme.destructive)
                    }
                }
            }
            .navigationTitle("Move Page")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move", systemImage: "folder", action: movePage)
                        .disabled(selectedSpaceID == nil || isSaving)
                }
            }
        }
    }

    private func movePage() {
        guard let selectedSpaceID else { return }

        Task {
            isSaving = true
            errorMessage = nil
            let message = await move(selectedSpaceID)
            isSaving = false

            if let message {
                errorMessage = message
            } else {
                dismiss()
            }
        }
    }
}
