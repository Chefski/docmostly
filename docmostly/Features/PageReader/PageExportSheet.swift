import SwiftUI
import UniformTypeIdentifiers

struct PageExportSheet: View {
    let pageID: String
    @Bindable var viewModel: PageExportViewModel
    let exportFailed: (String) -> Void
    let close: () -> Void
    @Environment(AppState.self) private var appState
    @State private var exportedPageDocument: DocmostlyExportDocument?
    @State private var isShowingExportedFileSaver = false
    @State private var exportTask: Task<Void, Never>?

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
                                exportTask = Task { @MainActor in
                                    await viewModel.export(pageID: pageID, appState: appState)
                                    exportTask = nil
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
                        .disabled(viewModel.canDismiss == false || isShowingExportedFileSaver)
                }
                if viewModel.isExporting {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Cancel", role: .cancel) {
                            exportTask?.cancel()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.canDismiss == false || isShowingExportedFileSaver)
        .fileExporter(
            isPresented: $isShowingExportedFileSaver,
            document: exportedPageDocument,
            contentType: exportedPageDocument?.contentType ?? .data,
            defaultFilename: exportedPageDocument?.fileName ?? "docmost-page"
        ) { result in
            if case .failure(let error) = result {
                exportFailed(error.localizedDescription)
            }
        }
        .onChange(of: viewModel.exportedFile) { _, document in
            guard let document else { return }
            exportedPageDocument = document
            isShowingExportedFileSaver = true
        }
        .onDisappear {
            guard viewModel.isExporting else { return }
            exportTask?.cancel()
        }
    }
}
