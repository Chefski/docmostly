import Foundation

nonisolated struct DocmostLabeledPage: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String?
    let icon: String?
    let spaceId: String
    let createdAt: Date?
    let updatedAt: Date?
    let space: DocmostPageSpace?
    let creator: DocmostPagePerson?
    let labels: [DocmostLabelSummary]
}
