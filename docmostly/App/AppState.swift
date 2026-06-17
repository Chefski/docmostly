import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    var phase: AppPhase = .restoring
    var serverURLString: String
    var currentUser: CurrentUserResponse?
    var spaces: [DocmostSpace] = []
    var selectedSpaceID: String?
    var selectedPageID: String?
    var isOffline = false
    var statusMessage: String?

    @ObservationIgnored private let settingsStore: LocalSettingsStore
    @ObservationIgnored private let authService: AuthService
    @ObservationIgnored private var cacheRepository: CacheRepository?
    @ObservationIgnored private var apiClient: DocmostAPIClient?

    init(
        settingsStore: LocalSettingsStore = LocalSettingsStore(),
        authService: AuthService = AuthService()
    ) {
        self.settingsStore = settingsStore
        self.authService = authService
        serverURLString = settingsStore.loadServerURLString()
    }

    func configure(modelContext: ModelContext) {
        if cacheRepository == nil {
            cacheRepository = CacheRepository(context: modelContext)
        }
    }

    func restore() async {
        do {
            guard serverURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                phase = .needsServer
                return
            }

            let serverURL = try ServerURLValidator.normalizedURL(from: serverURLString)
            apiClient = DocmostAPIClient(baseURL: serverURL)
            serverURLString = serverURL.absoluteString

            if let session = try await authService.restoreSession() {
                apiClient = DocmostAPIClient(baseURL: session.serverBaseURL)
                serverURLString = session.serverBaseURL.absoluteString
            }

            guard let apiClient else {
                phase = .needsServer
                return
            }

            currentUser = try await apiClient.send(.currentUser)
            phase = .authenticated
            await loadSpaces()
        } catch {
            currentUser = nil
            phase = serverURLString.isEmpty ? .needsServer : .unauthenticated
            loadCachedSpaces()
        }
    }

    func validateAndSaveServerURL(_ value: String) async throws {
        let url = try ServerURLValidator.normalizedURL(from: value)
        let client = DocmostAPIClient(baseURL: url)
        _ = try await client.send(.workspacePublic, as: PublicWorkspace.self)

        serverURLString = url.absoluteString
        settingsStore.saveServerURLString(serverURLString)
        apiClient = client
        currentUser = nil
        phase = .unauthenticated
        isOffline = false
    }

    func login(email: String, password: String) async throws {
        guard let apiClient else {
            throw ServerURLValidationError.empty
        }

        let response = try await authService.login(
            credentials: AuthCredentials(email: email, password: password),
            client: apiClient
        )
        currentUser = response
        phase = .authenticated
        isOffline = false
        await loadSpaces()
    }

    func logout() async {
        try? await authService.logout(client: apiClient)
        currentUser = nil
        spaces = []
        selectedSpaceID = nil
        selectedPageID = nil
        phase = .unauthenticated
    }

    func loadSpaces() async {
        guard let apiClient else {
            loadCachedSpaces()
            return
        }

        do {
            let response: PaginatedResponse<DocmostSpace> = try await apiClient.send(.spaces())
            spaces = response.items
            selectedSpaceID = selectedSpaceID ?? response.items.first?.id
            isOffline = false
            try cacheRepository?.saveSpaces(response.items)
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            loadCachedSpaces()
        }
    }

    func loadSidebarPages(spaceId: String, pageId: String? = nil) async throws -> [DocmostPage] {
        guard let apiClient else {
            return try loadCachedSidebarPages(spaceId: spaceId, pageId: pageId)
        }

        do {
            let response: PaginatedResponse<DocmostPage> = try await apiClient.send(
                .sidebarPages(spaceId: pageId == nil ? spaceId : nil, pageId: pageId)
            )
            try cacheRepository?.savePageTree(spaceId: spaceId, parentPageId: pageId, pages: response.items)
            isOffline = false
            return response.items
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            return try loadCachedSidebarPages(spaceId: spaceId, pageId: pageId)
        }
    }

    func loadPage(idOrSlugId: String) async throws -> PageLoadResult {
        guard let apiClient else {
            let cached = try requireCachedPage(idOrSlugId: idOrSlugId)
            return PageLoadResult(page: cached.asPage(), html: cached.htmlContent, isFromCache: true)
        }

        do {
            let page: DocmostPage = try await apiClient.send(.pageInfo(pageId: idOrSlugId, format: .html))
            let html = page.content ?? ""
            try cacheRepository?.savePage(page, htmlContent: html)
            isOffline = false
            return PageLoadResult(page: page, html: html, isFromCache: false)
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            let cached = try requireCachedPage(idOrSlugId: idOrSlugId)
            try cacheRepository?.markOpened(cached)
            return PageLoadResult(page: cached.asPage(), html: cached.htmlContent, isFromCache: true)
        }
    }

    func loadEditablePage(idOrSlugId: String) async throws -> DocmostEditablePage {
        guard let apiClient else {
            throw APIError.connectionFailed("Editing requires a network connection.")
        }

        let page: DocmostEditablePage = try await apiClient.send(.pageInfo(pageId: idOrSlugId, format: .json))
        isOffline = false
        return page
    }

    func updatePage(pageId: String, title: String, document: ProseMirrorDocument) async throws -> DocmostEditablePage {
        guard let apiClient else {
            throw APIError.connectionFailed("Editing requires a network connection.")
        }

        let page: DocmostEditablePage = try await apiClient.send(.updatePage(
            pageId: pageId,
            title: title,
            content: document,
            format: .json,
            operation: .replace
        ))
        isOffline = false
        return page
    }

    func search(query: String, spaceId: String?) async throws -> [DocmostSearchResult] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return []
        }

        guard let apiClient else {
            return try searchCachedPages(query: query)
        }

        do {
            let response: SearchResponse = try await apiClient.send(.search(query: query, spaceId: spaceId))
            isOffline = false
            return response.items
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            return try searchCachedPages(query: query)
        }
    }

    func loadComments(pageId: String) async throws -> [DocmostComment] {
        guard let apiClient else { return [] }
        let response: PaginatedResponse<DocmostComment> = try await apiClient.send(.comments(pageId: pageId))
        return response.items
    }

    func addPageComment(pageId: String, text: String) async throws -> DocmostComment {
        guard let apiClient else {
            throw APIError.connectionFailed("Comments require a network connection.")
        }
        let content = CommentPayload.plainText(text).jsonString
        return try await apiClient.send(.createPageComment(pageId: pageId, content: content))
    }

    func attachmentLinks(pageId: String) -> [DocmostAttachmentLink] {
        (try? cacheRepository?.loadAttachmentLinks(pageId: pageId)) ?? []
    }

    func recentCachedPages() -> [CachedPage] {
        (try? cacheRepository?.loadRecentPages()) ?? []
    }

    func clearCache() {
        try? cacheRepository?.clearAll()
        spaces = []
        selectedSpaceID = nil
        selectedPageID = nil
    }

    func storedSessionCookies() async -> [StoredHTTPCookie] {
        (try? await authService.restoreSession()?.cookies) ?? []
    }

    private func loadCachedSpaces() {
        guard let cached = try? cacheRepository?.loadSpaces() else { return }
        spaces = cached
        selectedSpaceID = selectedSpaceID ?? cached.first?.id
    }

    private func loadCachedSidebarPages(spaceId: String, pageId: String?) throws -> [DocmostPage] {
        try cacheRepository?.loadPageTree(spaceId: spaceId, parentPageId: pageId) ?? []
    }

    private func requireCachedPage(idOrSlugId: String) throws -> CachedPage {
        guard let cached = try cacheRepository?.loadPage(idOrSlugId: idOrSlugId) else {
            throw APIError.connectionFailed("This page is not cached for offline reading.")
        }
        return cached
    }

    private func searchCachedPages(query: String) throws -> [DocmostSearchResult] {
        let pages = try cacheRepository?.loadRecentPages(limit: 100) ?? []
        return pages
            .filter { page in
                page.title.localizedStandardContains(query) || page.htmlContent.localizedStandardContains(query)
            }
            .map { page in
                DocmostSearchResult(
                    id: page.id,
                    title: page.title,
                    icon: page.icon,
                    parentPageId: page.parentPageId,
                    slugId: page.slugId,
                    creatorId: nil,
                    createdAt: nil,
                    updatedAt: page.updatedAt,
                    rank: nil,
                    highlight: "Cached page",
                    space: SearchResultSpace(
                        id: page.spaceId,
                        name: page.spaceSlug ?? "Cached",
                        slug: page.spaceSlug,
                        icon: nil
                    )
                )
            }
    }
}
