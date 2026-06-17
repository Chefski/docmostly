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
                } else if presenceCollaborators.isEmpty == false {
                    Spacer(minLength: 0)
                } else if recentEditors.isEmpty == false {
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
        Text(recentEditors.map(\.name).joined(separator: ", "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var isVisible: Bool {
        switch viewModel.realtimeStatus {
        case .disconnected:
            hasCollaborators || viewModel.pendingRemoteUpdate != nil || viewModel.canEdit == false
        case .connected:
            hasCollaborators || viewModel.pendingRemoteUpdate != nil || viewModel.canEdit == false
        case .connecting, .conflict, .failed, .unsupported:
            true
        }
    }

    private var statusTitle: String {
        if let editingTitle = NativeEditorPresenceStatusText.editingTitle(for: presenceCollaborators) {
            return editingTitle
        }

        if viewModel.canEdit == false {
            return "Read-only"
        }

        switch viewModel.realtimeStatus {
        case .disconnected:
            return "Offline"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Live"
        case .conflict:
            return "Remote update"
        case .failed:
            return "Sync issue"
        case .unsupported:
            return "Limited live sync"
        }
    }

    private var hasCollaborators: Bool {
        viewModel.activeCollaborators.isEmpty == false
    }

    private var presenceCollaborators: [NativeEditorCollaborator] {
        viewModel.activeCollaborators.filter { $0.source == .presence }
    }

    private var recentEditors: [NativeEditorCollaborator] {
        viewModel.activeCollaborators.filter { $0.source == .recentEditor }
    }

    private var statusImage: String {
        if viewModel.canEdit == false {
            "lock"
        } else {
            statusImageForRealtimeStatus
        }
    }

    private var statusImageForRealtimeStatus: String {
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
        guard viewModel.canEdit else { return .secondary }

        return switch viewModel.realtimeStatus {
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
