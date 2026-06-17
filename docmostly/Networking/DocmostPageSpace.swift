import Foundation

nonisolated struct DocmostPageSpace: Decodable, Identifiable, Hashable, Sendable {
    let id: String?
    let name: String?
    let slug: String?
}
