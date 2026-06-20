import Foundation

nonisolated struct DocmostLabelSummary: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}
