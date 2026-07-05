import SwiftUI

struct PageImportSheet: View {
    let spaceID: String?
    let canImport: Bool
    @Bindable var viewModel: PageImportViewModel
    let chooseFiles: () -> Void
    let cancelImport: () -> Void
    let close: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Server Import") {
                    Label("Markdown", systemImage: "doc.plaintext")
                    Label("HTML", systemImage: "curlybraces")
                }

                Section {
                    if viewModel.isImporting {
                        ProgressView("Importing pages")
                        Button("Cancel Import", role: .destructive, action: cancelImport)
                    } else {
                        Button("Choose Files", systemImage: "square.and.arrow.up", action: chooseFiles)
                            .buttonStyle(.glassProminent)
                            .disabled(canImport == false || spaceID == nil || viewModel.canImport == false)
                    }
                } footer: {
                    Text(
                        "Files are uploaded to Docmost and converted by the server. " +
                        "Local Markdown import/export fidelity is unchanged."
                    )
                }

                if viewModel.importedPages.isEmpty == false {
                    Section("Imported") {
                        ForEach(viewModel.importedPages) { page in
                            VStack(alignment: .leading) {
                                Text(page.title)
                                Text(page.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ErrorStateView(title: "Import issue", message: errorMessage, retry: nil)
                    }
                }
            }
            .navigationTitle("Import Pages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: close)
                }
            }
        }
    }
}
