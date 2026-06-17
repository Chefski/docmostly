import Foundation

nonisolated struct DocmostPagePermissions: Decodable, Hashable, Sendable {
    let canEdit: Bool
    let hasRestriction: Bool
}
