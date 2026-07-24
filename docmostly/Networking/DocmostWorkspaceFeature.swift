import Foundation

nonisolated enum DocmostWorkspaceFeature: String, CaseIterable, Hashable, Sendable {
    case apiKeys = "api:keys"
    case artificialIntelligence = "ai"
    case mcp
    case retention
    case sharingControls = "sharing:controls"
    case templates
}
