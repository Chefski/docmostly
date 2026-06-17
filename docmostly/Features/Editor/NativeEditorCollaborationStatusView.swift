import SwiftUI

struct NativeEditorCollaborationStatusView: View {
    @Bindable var viewModel: NativeRichEditorViewModel

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Label(statusTitle, systemImage: statusImage)
                    .font(.caption)
                    .foregroundStyle(statusStyle)

                if let pendingRemoteUpdate = viewModel.pendingRemoteUpdate {
                    Text(pendingRemoteUpdate.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Button("Apply", systemImage: "arrow.down.doc", action: viewModel.acceptPendingRemoteUpdate)
                    Button("Keep Mine", systemImage: "xmark", action: viewModel.rejectPendingRemoteUpdate)
                } else if viewModel.activeCollaborators.isEmpty == false {
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
        Text(viewModel.activeCollaborators.map(\.name).joined(separator: ", "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var isVisible: Bool {
        switch viewModel.realtimeStatus {
        case .disconnected:
            viewModel.activeCollaborators.isEmpty == false || viewModel.pendingRemoteUpdate != nil
        case .connected:
            viewModel.activeCollaborators.isEmpty == false || viewModel.pendingRemoteUpdate != nil
        case .connecting, .conflict, .failed, .unsupported:
            true
        }
    }

    private var statusTitle: String {
        switch viewModel.realtimeStatus {
        case .disconnected:
            "Offline"
        case .connecting:
            "Connecting"
        case .connected:
            "Live"
        case .conflict:
            "Remote update"
        case .failed:
            "Sync issue"
        case .unsupported:
            "Limited live sync"
        }
    }

    private var statusImage: String {
        switch viewModel.realtimeStatus {
        case .connected:
            "checkmark.circle"
        case .connecting:
            "arrow.triangle.2.circlepath"
        case .conflict:
            "exclamationmark.triangle"
        case .failed:
            "wifi.exclamationmark"
        case .unsupported:
            "point.3.connected.trianglepath.dotted"
        case .disconnected:
            "wifi.slash"
        }
    }

    private var statusStyle: Color {
        switch viewModel.realtimeStatus {
        case .connected:
            .green
        case .conflict:
            .orange
        case .failed:
            .red
        case .connecting, .unsupported, .disconnected:
            .secondary
        }
    }
}
