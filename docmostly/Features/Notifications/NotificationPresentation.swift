import Foundation

extension NotificationListType {
    static let displayCases: [NotificationListType] = [.all, .direct, .updates]

    var title: String {
        switch self {
        case .all:
            "All"
        case .direct:
            "Direct"
        case .updates:
            "Updates"
        }
    }
}

extension DocmostNotification {
    var title: String {
        let actorName = actor?.name ?? "Someone"

        return switch type {
        case .commentUserMention:
            "\(actorName) mentioned you in a comment"
        case .commentCreated:
            "\(actorName) commented"
        case .commentResolved:
            "\(actorName) resolved a comment"
        case .pageUserMention:
            "\(actorName) mentioned you on a page"
        case .pagePermissionGranted:
            "\(actorName) shared a page with you"
        case .pageUpdated:
            "\(actorName) updated a page"
        case .pageVerificationExpiring:
            "Page verification is expiring"
        case .pageVerificationExpired:
            "Page verification expired"
        case .pageVerified:
            "\(actorName) verified a page"
        case .pageApprovalRequested:
            "\(actorName) requested approval"
        case .pageApprovalRejected:
            "\(actorName) rejected approval"
        case .unknown:
            "Notification"
        }
    }

    var subtitle: String {
        if let pageTitle = page?.title, pageTitle.isEmpty == false {
            return pageTitle
        }

        if let spaceName = space?.name, spaceName.isEmpty == false {
            return spaceName
        }

        return type.rawValue
    }
}
