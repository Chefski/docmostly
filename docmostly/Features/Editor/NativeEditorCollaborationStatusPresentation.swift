import Foundation

struct NativeEditorCollabStatusPresentation {
    let realtimeStatus: NativeEditorRealtimeStatus
    let canEdit: Bool
    let activeCollaborators: [NativeEditorCollaborator]
    let pendingRemoteUpdate: NativeEditorRemoteUpdate?

    var title: String {
        switch realtimeStatus {
        case .connected:
            if let editingTitle = NativeEditorPresenceStatusText.editingTitle(for: presenceCollaborators) {
                return editingTitle
            }
            return canEdit ? "Live" : "Read-only"
        case .connecting:
            return "Reconnecting"
        case .conflict:
            return "Remote update"
        case .authenticationFailed:
            return "Failed auth"
        case .failed:
            return "Sync failed"
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
        case .authenticationFailed:
            "person.crop.circle.badge.exclamationmark"
        case .failed:
            "wifi.exclamationmark"
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
        case .connecting, .conflict, .authenticationFailed, .failed:
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
