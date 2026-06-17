import Foundation

nonisolated struct DocmostEditablePage: Decodable, Identifiable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let content: ProseMirrorDocument?
    let icon: String?
    let spaceId: String
    let updatedAt: Date?
    let permissions: DocmostPagePermissions?
}
