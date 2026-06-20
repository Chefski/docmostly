import Foundation

nonisolated struct WorkspaceSettingsDraft: Equatable, Sendable {
    var name: String
    var logo: String
    var disablePublicSharing: Bool
    var restrictApiToAdmins: Bool
    var allowMemberTemplates: Bool
    var aiSearch: Bool
    var generativeAi: Bool
    var mcpEnabled: Bool
    var trashRetentionDays: Int

    init() {
        name = ""
        logo = ""
        disablePublicSharing = false
        restrictApiToAdmins = false
        allowMemberTemplates = true
        aiSearch = false
        generativeAi = false
        mcpEnabled = false
        trashRetentionDays = 30
    }

    init(workspace: DocmostWorkspace) {
        name = workspace.name
        logo = workspace.logo ?? ""
        disablePublicSharing = workspace.disablePublicSharing ?? workspace.settings?.sharing?.disabled ?? false
        restrictApiToAdmins = workspace.restrictApiToAdmins ?? workspace.settings?.api?.restrictToAdmins ?? false
        allowMemberTemplates = workspace.allowMemberTemplates ??
        workspace.settings?.templates?.allowMemberTemplates ??
        true
        aiSearch = workspace.aiSearch ?? workspace.settings?.artificialIntelligence?.search ?? false
        generativeAi = workspace.generativeAi ?? workspace.settings?.artificialIntelligence?.generative ?? false
        mcpEnabled = workspace.mcpEnabled ?? workspace.settings?.artificialIntelligence?.mcp ?? false
        trashRetentionDays = workspace.trashRetentionDays ?? 30
    }

    var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Workspace name is required."
        }
        if trashRetentionDays < 1 {
            return "Trash retention must be at least 1 day."
        }
        return nil
    }

    func hasChanges(comparedTo workspace: DocmostWorkspace) -> Bool {
        update(comparedTo: workspace).hasChanges
    }

    func update(comparedTo workspace: DocmostWorkspace) -> WorkspaceUpdate {
        let original = WorkspaceSettingsDraft(workspace: workspace)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLogo = logo.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkspaceUpdate(
            name: trimmedName == original.name ? nil : trimmedName,
            logo: trimmedLogo == original.logo ? nil : trimmedLogo,
            restrictApiToAdmins: restrictApiToAdmins == original.restrictApiToAdmins ? nil : restrictApiToAdmins,
            aiSearch: aiSearch == original.aiSearch ? nil : aiSearch,
            generativeAi: generativeAi == original.generativeAi ? nil : generativeAi,
            disablePublicSharing: disablePublicSharing == original.disablePublicSharing ? nil : disablePublicSharing,
            mcpEnabled: mcpEnabled == original.mcpEnabled ? nil : mcpEnabled,
            trashRetentionDays: trashRetentionDays == original.trashRetentionDays ? nil : trashRetentionDays,
            allowMemberTemplates: allowMemberTemplates == original.allowMemberTemplates ? nil : allowMemberTemplates
        )
    }
}
