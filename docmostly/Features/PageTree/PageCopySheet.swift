import SwiftUI

struct PageCopySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpaceId: String?
    @State private var isSaving = false

    let page: PageTreeNode
    let currentSpaceId: String
    let spaces: [DocmostSpace]
    let copy: (String?) async -> String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedSpaceId = currentSpaceId
                    } label: {
                        HStack {
                            Text("Current space")
                            Spacer()
                            if selectedSpaceId == currentSpaceId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(DocmostlyTheme.primary)
                            }
                        }
                    }

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
            .navigationTitle("Duplicate Page")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Duplicate", systemImage: "doc.on.doc", action: copyPage)
                        .disabled(selectedSpaceId == nil || isSaving)
                }
            }
        }
    }

    private func copyPage() {
        Task {
            isSaving = true
            errorMessage = nil
            let message = await copy(selectedSpaceId)
            isSaving = false
            if let message {
                errorMessage = message
            } else {
                dismiss()
            }
        }
    }
}
