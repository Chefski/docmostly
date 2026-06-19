import Foundation

struct NativeEditorCollabStatusPresentation {
    let realtimeStatus: NativeEditorRealtimeStatus
    let canEdit: Bool
    let activeCollaborators: [NativeEditorCollaborator]
    let pendingRemoteUpdate: NativeEditorRemoteUpdate?

    var title: String {
        if let editingTitle = NativeEditorPresenceStatusText.editingTitle(for: presenceCollaborators) {
            return editingTitle
        }

        switch realtimeStatus {
        case .connecting:
            return "Connecting"
        case .conflict:
            return "Remote update"
        case .failed:
            return "Sync issue"
        case .unsupported:
            return "Limited live sync"
        case .connected:
            return canEdit ? "Live" : "Read-only"
        case .disconnected:
            return canEdit ? "Offline" : "Read-only"
        }
    }

    var imageName: String {
        switch realtimeStatus {
        case .connected:
            canEdit ? "checkmark.circle" : "lock"
        case .connecting:
            "arrow.triangle.2.circlepath"
        case .conflict:
            "exclamationmark.triangle"
        case .failed:
            "wifi.exclamationmark"
        case .unsupported:
            "point.3.connected.trianglepath.dotted"
        case .disconnected:
            canEdit ? "wifi.slash" : "lock"
        }
    }

    var isVisible: Bool {
        switch realtimeStatus {
        case .disconnected:
            hasCollaborators || pendingRemoteUpdate != nil || canEdit == false
        case .connected:
            hasCollaborators || pendingRemoteUpdate != nil || canEdit == false
        case .connecting, .conflict, .failed, .unsupported:
            true
        }
    }

    var presenceCollaborators: [NativeEditorCollaborator] {
        activeCollaborators.filter { $0.source == .presence }
    }

    var recentEditors: [NativeEditorCollaborator] {
        activeCollaborators.filter { $0.source == .recentEditor }
    }

    private var hasCollaborators: Bool {
        activeCollaborators.isEmpty == false
    }
}
