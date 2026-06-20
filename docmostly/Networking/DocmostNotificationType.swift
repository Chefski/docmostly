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

    private static let knownTypesByRawValue: [String: Self] = [
        Self.commentUserMention.rawValue: .commentUserMention,
        Self.commentCreated.rawValue: .commentCreated,
        Self.commentResolved.rawValue: .commentResolved,
        Self.pageUserMention.rawValue: .pageUserMention,
        Self.pagePermissionGranted.rawValue: .pagePermissionGranted,
        Self.pageUpdated.rawValue: .pageUpdated,
        Self.pageVerificationExpiring.rawValue: .pageVerificationExpiring,
        Self.pageVerificationExpired.rawValue: .pageVerificationExpired,
        Self.pageVerified.rawValue: .pageVerified,
        Self.pageApprovalRequested.rawValue: .pageApprovalRequested,
        Self.pageApprovalRejected.rawValue: .pageApprovalRejected
    ]

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

        self = Self.knownTypesByRawValue[rawValue] ?? .unknown(rawValue)
    }
}
