import Foundation

nonisolated enum DocmostNotificationType: Hashable, Sendable {
    case commentUserMention
    case commentCreated
    case commentResolved
    case pageUserMention
    case pagePermissionGranted
    case pageUpdated
    case pageVerificationExpiring
    case pageVerificationExpired
    case pageVerified
    case pageApprovalRequested
    case pageApprovalRejected
    case unknown(String)

    var rawValue: String {
        switch self {
        case .commentUserMention:
            "comment.user_mention"
        case .commentCreated:
            "comment.created"
        case .commentResolved:
            "comment.resolved"
        case .pageUserMention:
            "page.user_mention"
        case .pagePermissionGranted:
            "page.permission_granted"
        case .pageUpdated:
            "page.updated"
        case .pageVerificationExpiring:
            "page.verification_expiring"
        case .pageVerificationExpired:
            "page.verification_expired"
        case .pageVerified:
            "page.verified"
        case .pageApprovalRequested:
            "page.approval_requested"
        case .pageApprovalRejected:
            "page.approval_rejected"
        case .unknown(let rawValue):
            rawValue
        }
    }
}

extension DocmostNotificationType: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.commentUserMention.rawValue:
            self = .commentUserMention
        case Self.commentCreated.rawValue:
            self = .commentCreated
        case Self.commentResolved.rawValue:
            self = .commentResolved
        case Self.pageUserMention.rawValue:
            self = .pageUserMention
        case Self.pagePermissionGranted.rawValue:
            self = .pagePermissionGranted
        case Self.pageUpdated.rawValue:
            self = .pageUpdated
        case Self.pageVerificationExpiring.rawValue:
            self = .pageVerificationExpiring
        case Self.pageVerificationExpired.rawValue:
            self = .pageVerificationExpired
        case Self.pageVerified.rawValue:
            self = .pageVerified
        case Self.pageApprovalRequested.rawValue:
            self = .pageApprovalRequested
        case Self.pageApprovalRejected.rawValue:
            self = .pageApprovalRejected
        default:
            self = .unknown(rawValue)
        }
    }
}
