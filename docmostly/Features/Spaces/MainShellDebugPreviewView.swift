import SwiftData
import SwiftUI

#if DEBUG
struct MainShellDebugPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState(settingsStore: LocalSettingsStore(userDefaults: .standard))
    @State private var isPrepared = false

    var body: some View {
        MainShellView()
            .environment(appState)
            .task(prepare)
    }

    private func prepare() {
        guard isPrepared == false else { return }
        isPrepared = true

        appState.configure(modelContext: modelContext)
        appState.serverURLString = "https://docs.example.com"
        appState.currentUser = MainShellDebugPreviewFixtures.currentUser
        appState.isOffline = true
        appState.statusMessage = nil

        let cache = CacheRepository(context: modelContext)
        try? cache.clearAll()
        try? cache.saveSpaces(MainShellDebugPreviewFixtures.spaces)
        try? cache.savePageTree(
            spaceId: MainShellDebugPreviewFixtures.productSpaceID,
            parentPageId: nil,
            pages: MainShellDebugPreviewFixtures.productPages
        )
        try? cache.savePageTree(
            spaceId: MainShellDebugPreviewFixtures.engineeringSpaceID,
            parentPageId: nil,
            pages: MainShellDebugPreviewFixtures.engineeringPages
        )

        for page in MainShellDebugPreviewFixtures.cachedPages {
            try? cache.savePage(page, htmlContent: "<p>\(page.title)</p>")
            try? cache.saveEditablePage(MainShellDebugPreviewFixtures.editablePage(from: page))
        }

        appState.spaces = MainShellDebugPreviewFixtures.spaces
        appState.resetNavigationSelection()
        appState.selectDefaultSpaceIfNeeded()
    }
}

private enum MainShellDebugPreviewFixtures {
    static let productSpaceID = "space-product"
    static let engineeringSpaceID = "space-engineering"

    static let currentUser = CurrentUserResponse(
        user: DocmostUser(
            id: "user-1",
            name: "Preview Editor",
            email: "editor@example.com",
            avatarUrl: nil,
            role: "owner",
            workspaceId: "workspace-1",
            locale: nil,
            timezone: nil,
            settings: nil,
            emailVerifiedAt: nil,
            invitedById: nil,
            lastLoginAt: nil,
            lastActiveAt: nil,
            createdAt: nil,
            updatedAt: nil,
            deactivatedAt: nil,
            deletedAt: nil,
            hasGeneratedPassword: nil
        ),
        workspace: DocmostWorkspace(
            id: "workspace-1",
            name: "Docmostly Preview",
            logo: nil,
            hostname: nil,
            description: nil,
            defaultSpaceId: productSpaceID,
            customDomain: nil,
            enableInvite: true,
            status: nil,
            enforceSso: nil,
            enforceMfa: nil,
            emailDomains: nil,
            settings: nil,
            memberCount: 4,
            plan: nil,
            aiSearch: nil,
            generativeAi: nil,
            disablePublicSharing: nil,
            mcpEnabled: nil,
            trashRetentionDays: nil,
            restrictApiToAdmins: nil,
            allowMemberTemplates: nil,
            isScimEnabled: nil
        )
    )

    static let spaces = [
        space(id: productSpaceID, name: "Product", slug: "product"),
        space(id: engineeringSpaceID, name: "Engineering", slug: "engineering"),
        space(id: "space-operations", name: "Operations", slug: "operations")
    ]

    static let productPages = [
        page(
            id: "page-roadmap",
            slugId: "roadmap",
            title: "Roadmap",
            spaceId: productSpaceID,
            position: "a0",
            hasChildren: true
        ),
        page(
            id: "page-release-notes",
            slugId: "release-notes",
            title: "Release notes",
            spaceId: productSpaceID,
            position: "a1"
        ),
        page(
            id: "page-customer-research",
            slugId: "customer-research",
            title: "Customer research",
            spaceId: productSpaceID,
            position: "a2"
        )
    ]

    static let engineeringPages = [
        page(
            id: "page-architecture",
            slugId: "architecture",
            title: "Architecture",
            spaceId: engineeringSpaceID,
            position: "a0"
        ),
        page(
            id: "page-api-contracts",
            slugId: "api-contracts",
            title: "API contracts",
            spaceId: engineeringSpaceID,
            position: "a1"
        )
    ]

    static var cachedPages: [DocmostPage] {
        productPages + engineeringPages
    }

    private static func space(id: String, name: String, slug: String) -> DocmostSpace {
        DocmostSpace(
            id: id,
            name: name,
            description: nil,
            logo: nil,
            slug: slug,
            hostname: nil,
            creatorId: "user-1",
            createdAt: nil,
            updatedAt: nil,
            memberCount: 4,
            membership: nil,
            settings: nil
        )
    }

    private static func page(
        id: String,
        slugId: String,
        title: String,
        spaceId: String,
        position: String,
        hasChildren: Bool = false
    ) -> DocmostPage {
        DocmostPage(
            id: id,
            slugId: slugId,
            title: title,
            content: nil,
            icon: nil,
            coverPhoto: nil,
            parentPageId: nil,
            creatorId: "user-1",
            spaceId: spaceId,
            workspaceId: "workspace-1",
            isLocked: false,
            lastUpdatedById: "user-1",
            createdAt: nil,
            updatedAt: Date.now,
            deletedAt: nil,
            position: position,
            hasChildren: hasChildren,
            permissions: DocmostPagePermissions(canEdit: true, hasRestriction: false),
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: DocmostPageSpace(id: spaceId, name: nil, slug: spaceId, logo: nil)
        )
    }

    static func editablePage(from page: DocmostPage) -> DocmostEditablePage {
        DocmostEditablePage(
            id: page.id,
            slugId: page.slugId,
            title: page.title,
            content: document(title: page.title),
            icon: page.icon,
            spaceId: page.spaceId,
            updatedAt: page.updatedAt,
            permissions: page.permissions,
            lastUpdatedBy: nil
        )
    }

    private static func document(title: String) -> ProseMirrorDocument {
        ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "paragraph",
                content: [
                    ProseMirrorNode(type: "text", text: "\(title) native preview content")
                ]
            )
        ])
    }
}
#endif
