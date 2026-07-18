import SwiftUI

struct NativeEditorTransclusionSourceBlockView: View {
    let blockID: UUID
    let source: NativeEditorTransclusionSourceBlock
    let content: [ProseMirrorNode]
    let actions: NativeEditorRichBlockEditingActions?
    let pageID: String
    let spaceID: String?
    let serverURLString: String?
    var presenceProjection: NativeEditorRemotePresenceProjection?
    var presenceScope: [NativeEditorRemotePresenceScope] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Editing original synced block", systemImage: "arrow.trianglehead.2.clockwise")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let actions {
                NativeEditorTransclusionSourceEditor(blockID: blockID, source: source, actions: actions)
                NativeEditorNestedDocumentView(
                    blockID: blockID,
                    target: .transclusionSource,
                    content: content,
                    serverURLString: serverURLString,
                    presenceProjection: presenceProjection,
                    presenceScope: presenceScope
                ) { updatedContent in
                    actions.updateNestedContent(blockID, .transclusionSource, updatedContent)
                }
            } else {
                NativeEditorNestedDocumentPreview(
                    content: content,
                    pageID: pageID,
                    spaceID: spaceID,
                    serverURLString: serverURLString
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.07), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.blue.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Synced block source")
    }
}

struct NativeEditorSyncedReferenceView: View {
    @Environment(AppState.self) private var appState
    @State private var phase = Phase.idle
    @State private var refreshGeneration = 0

    let reference: NativeEditorTransclusionReferenceBlock
    let pageID: String
    let spaceID: String?
    let serverURLString: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Synced block reference", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button("Refresh synced block", systemImage: "arrow.clockwise") {
                    refreshGeneration += 1
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Refresh synced block")
                .disabled(canLoad == false || phase == .loading)
            }

            referenceContent
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.12), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        }
        .task(id: taskID) {
            await load()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Read-only synced block reference")
    }

    @ViewBuilder
    private var referenceContent: some View {
        switch phase {
        case .idle, .loading:
            ProgressView("Loading synced block")
        case .resolved(let document):
            NativeEditorNestedDocumentPreview(
                content: document.content,
                pageID: pageID,
                spaceID: spaceID,
                serverURLString: serverURLString
            )
        case .notFound:
            Label("The original synced block no longer exists", systemImage: "questionmark.square.dashed")
                .foregroundStyle(.secondary)
        case .noAccess:
            Label("You do not have access to this synced block", systemImage: "eye.slash")
                .foregroundStyle(.secondary)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Label("Failed to load this synced block", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(DocmostlyTheme.destructive)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canLoad: Bool {
        reference.sourcePageID?.isEmpty == false && reference.transclusionID?.isEmpty == false
    }

    private var taskID: String {
        "\(reference.sourcePageID ?? "missing")::\(reference.transclusionID ?? "missing")::\(refreshGeneration)"
    }

    private func load() async {
        guard let sourcePageID = reference.sourcePageID,
              let transclusionID = reference.transclusionID,
              sourcePageID.isEmpty == false,
              transclusionID.isEmpty == false else {
            phase = .notFound
            return
        }

        phase = .loading
        do {
            switch try await appState.loadTransclusion(
                sourcePageId: sourcePageID,
                transclusionId: transclusionID
            ) {
            case .resolved(_, let content, _):
                phase = .resolved(content)
            case .notFound:
                phase = .notFound
            case .noAccess:
                phase = .noAccess
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

private extension NativeEditorSyncedReferenceView {
    enum Phase: Equatable {
        case idle
        case loading
        case resolved(ProseMirrorDocument)
        case notFound
        case noAccess
        case failed(String)
    }
}
