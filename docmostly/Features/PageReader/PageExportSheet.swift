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
