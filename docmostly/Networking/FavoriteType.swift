import Foundation

nonisolated enum FavoriteType: String, Codable, CaseIterable, Sendable {
    case page
    case space
    case template
}
