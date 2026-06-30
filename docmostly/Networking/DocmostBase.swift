import Foundation

nonisolated enum DocmostBaseTemplate: String, Codable, Sendable {
    case kanban
}

nonisolated struct DocmostBase: Decodable, Identifiable, Sendable {
    let id: String
}
