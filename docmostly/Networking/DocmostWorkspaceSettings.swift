import Foundation

nonisolated struct DocmostWorkspaceSettings: Codable, Hashable, Sendable {
    let artificialIntelligence: DocmostWorkspaceAISettings?
    let sharing: DocmostWorkspaceSharingSettings?
    let api: DocmostWorkspaceAPISettings?
    let templates: DocmostWorkspaceTemplateSettings?

    private enum CodingKeys: String, CodingKey {
        case artificialIntelligence = "ai"
        case sharing
        case api
        case templates
    }
}

nonisolated struct DocmostWorkspaceAISettings: Codable, Hashable, Sendable {
    let search: Bool?
    let generative: Bool?
    let mcp: Bool?
    let chat: Bool?
}

nonisolated struct DocmostWorkspaceSharingSettings: Codable, Hashable, Sendable {
    let disabled: Bool?
}

nonisolated struct DocmostWorkspaceAPISettings: Codable, Hashable, Sendable {
    let restrictToAdmins: Bool?
}

nonisolated struct DocmostWorkspaceTemplateSettings: Codable, Hashable, Sendable {
    let allowMemberTemplates: Bool?
}
