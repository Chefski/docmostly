import SwiftUI

struct NativeEditorCollaborationStatusView: View {
    @Bindable var viewModel: NativeRichEditorViewModel

    var body: some View {
        if presentation.isVisible {
            HStack(spacing: 8) {
                Label(presentation.title, systemImage: presentation.imageName)
                    .font(.caption)
                    .foregroundStyle(statusStyle)

                if let pendingRemoteUpdate = viewModel.pendingRemoteUpdate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pendingRemoteUpdate.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let lastUpdatedBy = pendingRemoteUpdate.lastUpdatedBy {
                            Text("Edited by \(lastUpdatedBy.name)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Button("Apply", systemImage: "arrow.down.doc", action: viewModel.acceptPendingRemoteUpdate)
                    Button("Keep Mine", systemImage: "xmark", action: viewModel.rejectPendingRemoteUpdate)
                } else if presentation.presenceCollaborators.isEmpty == false {
                    Spacer(minLength: 0)
                } else if presentation.recentEditors.isEmpty == false {
                    collaboratorNames
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.24), in: .rect(cornerRadius: 8))
            .accessibilityElement(children: .combine)
        }
    }

    private var collaboratorNames: some View {
        Text(presentation.recentEditors.map(\.name).joined(separator: ", "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var presentation: NativeEditorCollabStatusPresentation {
        NativeEditorCollabStatusPresentation(
            realtimeStatus: viewModel.realtimeStatus,
            canEdit: viewModel.canEdit,
            activeCollaborators: viewModel.activeCollaborators,
            pendingRemoteUpdate: viewModel.pendingRemoteUpdate
        )
    }

    private var statusStyle: Color {
        guard viewModel.canEdit else { return .secondary }

        return switch viewModel.realtimeStatus {
        case .connected:
            .green
        case .conflict:
            .orange
        case .authenticationFailed, .failed:
            .red
        case .connecting, .disconnected:
            .secondary
        }
    }
}
