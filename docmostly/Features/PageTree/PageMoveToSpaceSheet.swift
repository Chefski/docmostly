import SwiftUI

struct PageMoveToSpaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpaceId: String?
    @State private var isSaving = false

    let page: PageTreeNode
    let currentSpaceId: String
    let spaces: [DocmostSpace]
    let move: (String) async -> String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(spaces.filter { $0.id != currentSpaceId }) { space in
                        Button {
                            selectedSpaceId = space.id
                        } label: {
                            HStack {
                                SpaceIconView(space: space)
                                Text(space.name)
                                Spacer()
                                if selectedSpaceId == space.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(DocmostlyTheme.primary)
                                }
                            }
                        }
                    }
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
                        .disabled(selectedSpaceId == nil || isSaving)
                }
            }
        }
    }

    private func movePage() {
        guard let selectedSpaceId else { return }

        Task {
            isSaving = true
            errorMessage = nil
            let message = await move(selectedSpaceId)
            isSaving = false
            if let message {
                errorMessage = message
            } else {
                dismiss()
            }
        }
    }
}
