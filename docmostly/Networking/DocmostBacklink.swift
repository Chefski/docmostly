import Foundation

nonisolated enum DocmostBacklinkDirection: String, Decodable, Encodable, Hashable, Identifiable, Sendable {
    case incoming
    case outgoing

    var id: Self { self }

    var title: String {
        switch self {
        case .incoming:
            "Incoming links"
        case .outgoing:
            "Outgoing links"
        }
    }

    var emptyMessage: String {
        switch self {
        case .incoming:
            "No pages link here yet."
        case .outgoing:
            "This page doesn't link to other pages yet."
        }
    }
}

nonisolated struct DocmostBacklinkCounts: Decodable, Equatable, Sendable {
    let incoming: Int
    let outgoing: Int

    static let empty = DocmostBacklinkCounts(incoming: 0, outgoing: 0)
}

nonisolated struct DocmostBacklinkPage: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String?
    let icon: String?
    let spaceId: String
    let space: DocmostPageSpace?
    let updatedAt: Date?
}
