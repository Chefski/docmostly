import Foundation

nonisolated struct DocmostWorkspace: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let logo: String?
    let hostname: String?
    let description: String?
    let defaultSpaceId: String?
    let customDomain: String?
    let enableInvite: Bool?
    let status: String?
    let enforceSso: Bool?
    let enforceMfa: Bool?
    let emailDomains: [String]?
    let settings: DocmostWorkspaceSettings?
    let memberCount: Int?
    let plan: String?
    let aiSearch: Bool?
    let generativeAi: Bool?
    let disablePublicSharing: Bool?
    let mcpEnabled: Bool?
    let trashRetentionDays: Int?
    let restrictApiToAdmins: Bool?
    let allowMemberTemplates: Bool?
    let isScimEnabled: Bool?
}
