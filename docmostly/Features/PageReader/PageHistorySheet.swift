import SwiftUI

struct PageHistorySheet: View {
    let pageID: String
    let spaceID: String?
    let canRestore: Bool
    @Bindable var viewModel: PageHistoryViewModel
    let restore: () async -> Bool
    let close: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            historyList
                .navigationTitle("Page History")
        } detail: {
            historyDetail
                .navigationTitle(viewModel.selectedVersion?.title ?? "Version")
        }
        .task(id: pageID) {
            await viewModel.loadInitial(pageID: pageID, appState: appState)
        }
        .confirmationDialog(
            "Restore this version?",
            isPresented: restoreConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Restore Version", role: .destructive) {
                Task {
                    if await restore() {
                        close()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelRestoreConfirmation()
            }
        } message: {
            Text("Any unsaved edits that are not in page history may be lost.")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done", action: close)
            }
        }
    }

    private var historyList: some View {
        List(selection: selectedVersionBinding) {
            if viewModel.versions.isEmpty && viewModel.isLoadingList {
                ProgressView("Loading versions")
            } else if viewModel.versions.isEmpty {
                ContentUnavailableView(
                    "No page history saved yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Docmost has not created saved versions for this page.")
                )
            } else {
                ForEach(viewModel.versions) { version in
                    PageHistoryVersionRow(version: version)
                        .tag(version.id)
                        .task {
                            guard version.id == viewModel.versions.last?.id else { return }
                            await viewModel.loadNextPage(pageID: pageID, appState: appState)
                        }
                }

                if viewModel.isLoadingList {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private var historyDetail: some View {
        if viewModel.isLoadingSelection {
            LoadingStateView(title: "Loading version")
        } else if let errorMessage = viewModel.errorMessage {
            ErrorStateView(title: "History unavailable", message: errorMessage) {
                Task {
                    await viewModel.loadInitial(pageID: pageID, appState: appState)
                }
            }
        } else if let selectedVersion = viewModel.selectedVersion {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHistoryVersionHeader(
                        version: selectedVersion,
                        canRestore: canRestore && viewModel.canRequestRestoreConfirmation,
                        isRestoring: viewModel.isRestoring,
                        restore: viewModel.requestRestoreConfirmation
                    )

                    if let restoreErrorMessage = viewModel.restoreErrorMessage {
                        ErrorStateView(title: "Restore failed", message: restoreErrorMessage, retry: nil)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.selectedDocument.blocks, id: \.id) { block in
                            NativeEditorRichBlockPreviewView(block: block, pageID: pageID, spaceID: spaceID)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxWidth: 900, alignment: .leading)
            }
        } else {
            ContentUnavailableView(
                "Select a version",
                systemImage: "clock",
                description: Text("Choose a saved version to preview its content.")
            )
        }
    }

    private var selectedVersionBinding: Binding<String?> {
        Binding {
            viewModel.selectedVersion?.id
        } set: { versionID in
            guard let versionID else { return }
            Task {
                await viewModel.selectVersion(versionID, appState: appState)
            }
        }
    }

    private var restoreConfirmationBinding: Binding<Bool> {
        Binding {
            viewModel.pendingRestoreVersion != nil
        } set: { isPresented in
            if isPresented == false {
                viewModel.cancelRestoreConfirmation()
            }
        }
    }
}

private struct PageHistoryVersionRow: View {
    let version: DocmostPageHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(version.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "Saved version")
                    .font(.headline)
                Spacer()
                Text(version.versionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(version.lastUpdatedBy?.name ?? "Unknown editor")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

private struct PageHistoryVersionHeader: View {
    let version: DocmostPageHistory
    let canRestore: Bool
    let isRestoring: Bool
    let restore: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            DocmostlyGlassPanel(cornerRadius: 16) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(version.title.isEmpty ? "Untitled" : version.title)
                            .font(.title3)
                            .bold()
                            .lineLimit(2)

                        Text(versionSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Restore", systemImage: "arrow.counterclockwise", action: restore)
                        .buttonStyle(.glassProminent)
                        .disabled(canRestore == false || isRestoring)
                }
                .padding()
            }
        }
    }

    private var versionSubtitle: String {
        let editor = version.lastUpdatedBy?.name ?? "Unknown editor"
        guard let createdAt = version.createdAt else {
            return "\(version.versionLabel) by \(editor)"
        }

        let savedAt = createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(version.versionLabel) by \(editor) on \(savedAt)"
    }
}

private extension DocmostPageHistory {
    var versionLabel: String {
        guard let version else { return "Saved version" }
        return "v\(version.formatted(.number))"
    }
}
