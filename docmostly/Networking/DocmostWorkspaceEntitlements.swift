import Foundation

nonisolated struct DocmostWorkspaceEntitlements: Decodable, Equatable, Sendable {
    let cloud: Bool
    let tier: String
    let features: Set<String>

    func contains(_ feature: DocmostWorkspaceFeature) -> Bool {
        features.contains(feature.rawValue)
    }
}
