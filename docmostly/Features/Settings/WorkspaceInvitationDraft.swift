import Foundation

nonisolated struct WorkspaceInvitationDraft: Equatable, Sendable {
    var emailsText = ""
    var role = "member"
    var selectedGroupIds: Set<String> = []

    var emails: [String] {
        emailsText
            .components(separatedBy: CharacterSet(charactersIn: ", \n\t"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    var groupIds: [String] {
        selectedGroupIds.sorted()
    }

    var validationMessage: String? {
        if emails.isEmpty {
            return "Enter at least one email address."
        }
        if emails.count > 50 {
            return "You can invite up to 50 people at once."
        }
        if emails.allSatisfy(Self.isValidEmail) == false {
            return "Every invitation needs a valid email address."
        }
        if role != "admin" && role != "member" {
            return "Invitations can assign admin or member roles."
        }
        if selectedGroupIds.count > 25 {
            return "You can add invited people to up to 25 groups."
        }
        return nil
    }

    var canSend: Bool {
        validationMessage == nil
    }

    mutating func toggleGroup(id: String) {
        if selectedGroupIds.contains(id) {
            selectedGroupIds.remove(id)
        } else {
            selectedGroupIds.insert(id)
        }
    }

    private static func isValidEmail(_ email: String) -> Bool {
        email.range(
            of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#,
            options: .regularExpression
        ) != nil
    }
}
