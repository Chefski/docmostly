import Foundation

nonisolated struct DocmostWorkspaceSettings: Decodable, Hashable, Sendable {
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

nonisolated struct DocmostWorkspaceAISettings: Decodable, Hashable, Sendable {
    let search: Bool?
    let generative: Bool?
    let mcp: Bool?
    let chat: Bool?
}

nonisolated struct DocmostWorkspaceSharingSettings: Decodable, Hashable, Sendable {
    let disabled: Bool?
}

nonisolated struct DocmostWorkspaceAPISettings: Decodable, Hashable, Sendable {
    let restrictToAdmins: Bool?
}

nonisolated struct DocmostWorkspaceTemplateSettings: Decodable, Hashable, Sendable {
    let allowMemberTemplates: Bool?
}
