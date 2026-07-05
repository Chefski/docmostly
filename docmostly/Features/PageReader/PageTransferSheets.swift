import SwiftUI

struct PageExportSheet: View {
    let pageID: String
    @Bindable var viewModel: PageExportViewModel
    let close: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $viewModel.format) {
                        ForEach(DocmostPageExportFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Scope") {
                    Toggle("Include subpages", isOn: $viewModel.includeChildren)
                    Text("Attachments are not included in native export yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ErrorStateView(title: "Export failed", message: errorMessage, retry: nil)
                    }
                }

                Section {
                    GlassEffectContainer(spacing: 12) {
                        DocmostlyGlassPanel(cornerRadius: 16) {
                            Button("Export", systemImage: "square.and.arrow.down") {
                                Task {
                                    await viewModel.export(pageID: pageID, appState: appState)
                                }
                            }
                            .buttonStyle(.glassProminent)
                            .disabled(viewModel.isExporting)
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Export Page")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: close)
                }
                if viewModel.isExporting {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView()
                    }
                }
            }
        }
    }
}

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
