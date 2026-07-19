import SwiftUI

struct NativeEditorCollaborationStatusView: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    var applyPendingRemoteUpdate: (() -> Void)?
    var keepPendingLocalUpdate: (() -> Void)?

    var body: some View {
        if presentation.isVisible {
            HStack(spacing: 8) {
                Label(presentation.title, systemImage: presentation.imageName)
                    .font(.caption)
                    .foregroundStyle(statusStyle)

                if let pendingRemoteUpdate = viewModel.pendingRemoteUpdate {
                    Text(pendingRemoteUpdate.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Button("Apply", systemImage: "arrow.down.doc") {
                        if let applyPendingRemoteUpdate {
                            applyPendingRemoteUpdate()
                        } else {
                            viewModel.acceptPendingRemoteUpdate()
                        }
                    }
                    Button("Keep Mine", systemImage: "xmark") {
                        if let keepPendingLocalUpdate {
                            keepPendingLocalUpdate()
                        } else {
                            viewModel.rejectPendingRemoteUpdate()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.24), in: .rect(cornerRadius: 8))
            .accessibilityElement(children: .combine)
        }
    }

    private var presentation: NativeEditorCollabStatusPresentation {
        NativeEditorCollabStatusPresentation(
            realtimeStatus: viewModel.realtimeStatus,
            canEdit: viewModel.canEdit,
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
