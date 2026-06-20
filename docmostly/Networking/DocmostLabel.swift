import Foundation

nonisolated struct DocmostLabel: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let type: LabelType
    let workspaceId: String?
    let createdAt: Date?
    let updatedAt: Date?
}
