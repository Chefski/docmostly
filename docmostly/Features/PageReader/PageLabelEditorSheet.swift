import SwiftUI

struct PageLabelEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draftName = ""

    let pageID: String
    let viewModel: PageReaderViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Applied Labels") {
                    if viewModel.labels.isEmpty {
                        Text("No labels")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.labels) { label in
                            HStack {
                                Text(label.name)
                                Spacer()
                                Button("Remove \(label.name)", systemImage: "xmark.circle") {
                                    remove(label)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .foregroundStyle(DocmostlyTheme.destructive)
                                .disabled(viewModel.isUpdatingLabels)
                            }
                        }
                    }
                }

                Section("Add Label") {
                    TextField("Search or create", text: $draftName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    let normalizedName = DocmostLabelNameValidator.normalized(draftName)
                    if normalizedName.isEmpty == false {
                        LabeledContent("Name", value: normalizedName)
                    }

                    if let message = validationMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Add Label", systemImage: "plus", action: addLabel)
                        .disabled(canAddLabel == false || viewModel.isUpdatingLabels)
                }

                if let errorMessage = viewModel.labelEditorErrorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DocmostlyTheme.destructive)
                    }
                }
            }
            .navigationTitle("Labels")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
    }

    private var normalizedDraftName: String {
        DocmostLabelNameValidator.normalized(draftName)
    }

    private var validationMessage: String? {
        guard normalizedDraftName.isEmpty == false else { return nil }
        return DocmostLabelNameValidator.validationMessage(for: normalizedDraftName, existingLabels: viewModel.labels)
    }

    private var canAddLabel: Bool {
        normalizedDraftName.isEmpty == false && validationMessage == nil
    }

    private func addLabel() {
        Task {
            await viewModel.addLabel(named: draftName, pageID: pageID, appState: appState)
            if viewModel.labelEditorErrorMessage == nil {
                draftName = ""
            }
        }
    }

    private func remove(_ label: DocmostLabel) {
        Task {
            await viewModel.removeLabel(label, pageID: pageID, appState: appState)
        }
    }
}
