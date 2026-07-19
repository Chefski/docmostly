import Foundation

struct NativeEditorCollabStatusPresentation {
    let realtimeStatus: NativeEditorRealtimeStatus
    let canEdit: Bool
    let pendingRemoteUpdate: NativeEditorRemoteUpdate?

    var title: String {
        switch realtimeStatus {
        case .connected:
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
            pendingRemoteUpdate != nil || canEdit == false
        case .connected:
            pendingRemoteUpdate != nil || canEdit == false
        case .connecting:
            false
        case .conflict, .authenticationFailed, .failed:
            true
        }
    }
}
