import Foundation

nonisolated enum NativeEditorCollaborationScope: String, Equatable, Sendable {
    case readWrite = "read-write"
    case readonly
    case unknown

    init(rawScope: String) {
        self = Self(rawValue: rawScope) ?? .unknown
    }

    var allowsLocalDocumentUpdates: Bool {
        self == .readWrite
    }

    var allowsLocalAwarenessUpdates: Bool {
        switch self {
        case .readWrite, .readonly:
            true
        case .unknown:
            false
        }
    }

    var allowsInitialDocumentSync: Bool {
        switch self {
        case .readWrite, .readonly:
            true
        case .unknown:
            false
        }
    }

    func allowsSyncReply(to message: NativeEditorYjsSyncMessage) -> Bool {
        switch message {
        case .stepOne:
            allowsLocalDocumentUpdates
        case .stepTwo, .update:
            true
        }
    }
}
