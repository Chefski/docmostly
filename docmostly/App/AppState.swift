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
    var selectedSidebarDestination: SidebarDestination?
    var selectedSpaceID: String?
    var selectedPageID: String?
    var isOffline = false
    var statusMessage: String?

    @ObservationIgnored private let settingsStore: LocalSettingsStore
    @ObservationIgnored private let authService: AuthService
    @ObservationIgnored private let cookieJar: SessionCookieJar
    @ObservationIgnored let crdtDocumentEngineFactory: (any NativeEditorCRDTDocumentEngineFactory)?
    @ObservationIgnored private var cacheRepository: CacheRepository?
    @ObservationIgnored private var cacheScope: CacheScope?
    @ObservationIgnored private(set) var apiClient: DocmostAPIClient?

    init(
        settingsStore: LocalSettingsStore? = nil,
        authService: AuthService? = nil,
        cookieJar: SessionCookieJar = SessionCookieJar(),
        crdtDocumentEngineFactory: (any NativeEditorCRDTDocumentEngineFactory)? = nil
    ) {
        self.settingsStore = settingsStore ?? LocalSettingsStore()
        self.cookieJar = cookieJar
        self.authService = authService ?? AuthService(cookieJar: cookieJar)
        self.crdtDocumentEngineFactory = crdtDocumentEngineFactory
        serverURLString = self.settingsStore.loadServerURLString()
    }

    static func production(crdtRuntimeBundle: Bundle = .main) -> AppState {
        AppState(
            crdtDocumentEngineFactory: NativeEditorJSCRDTEngineFactory.bundledIfAvailable(in: crdtRuntimeBundle)
        )
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
            apiClient = DocmostAPIClient(baseURL: serverURL, cookieJar: cookieJar)
            serverURLString = serverURL.absoluteString

            if let session = try await authService.restoreSession() {
                apiClient = DocmostAPIClient(baseURL: session.serverBaseURL, cookieJar: cookieJar)
                serverURLString = session.serverBaseURL.absoluteString
            }

            guard let apiClient else {
                phase = .needsServer
                return
            }

            currentUser = try await apiClient.send(.currentUser)
            updateCacheScope()
            phase = .authenticated
            await loadSpaces()
        } catch {
            currentUser = nil
            cacheScope = nil
            phase = serverURLString.isEmpty ? .needsServer : .unauthenticated
            loadCachedSpaces()
        }
    }

    func validateAndSaveServerURL(_ value: String) async throws {
        let url = try ServerURLValidator.normalizedURL(from: value)
        let client = DocmostAPIClient(baseURL: url, cookieJar: cookieJar)
        _ = try await client.send(.workspacePublic, as: PublicWorkspace.self)

        serverURLString = url.absoluteString
        settingsStore.saveServerURLString(serverURLString)
        apiClient = client
        currentUser = nil
        cacheScope = nil
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
        updateCacheScope()
        phase = .authenticated
        isOffline = false
        await loadSpaces()
    }

    func logout() async {
        try? await authService.logout(client: apiClient)
        currentUser = nil
        cacheScope = nil
        spaces = []
        resetNavigationSelection()
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
            selectDefaultSpaceIfNeeded()
            isOffline = false
            if let cacheScope {
                try cacheRepository?.saveSpaces(response.items, scope: cacheScope)
            }
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else {
                spaces = []
                return
            }
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
            if let cacheScope {
                try cacheRepository?.savePageTree(
                    spaceId: spaceId,
                    parentPageId: pageId,
                    pages: response.items,
                    scope: cacheScope
                )
            }
            isOffline = false
            return response.items
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
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
            if let cacheScope {
                try cacheRepository?.savePage(page, htmlContent: html, scope: cacheScope)
            }
            isOffline = false
            return PageLoadResult(page: page, html: html, isFromCache: false)
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
            let cached = try requireCachedPage(idOrSlugId: idOrSlugId)
            try cacheRepository?.markOpened(cached)
            return PageLoadResult(page: cached.asPage(), html: cached.htmlContent, isFromCache: true)
        }
    }

    func loadEditablePage(idOrSlugId: String) async throws -> DocmostEditablePage {
        guard let apiClient else {
            return try requireCachedEditablePage(idOrSlugId: idOrSlugId)
        }

        do {
            let page: DocmostEditablePage = try await apiClient.send(.pageInfo(pageId: idOrSlugId, format: .json))
            if let cacheScope {
                try cacheRepository?.saveEditablePage(page, scope: cacheScope)
            }
            isOffline = false
            return page
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
            return try requireCachedEditablePage(idOrSlugId: idOrSlugId)
        }
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
            guard canUseOfflineCache(after: error) else { throw error }
            return try searchCachedPages(query: query)
        }
    }

    func attachmentLinks(pageId: String) -> [DocmostAttachmentLink] {
        guard let cacheScope else { return [] }
        return (try? cacheRepository?.loadAttachmentLinks(pageId: pageId, scope: cacheScope)) ?? []
    }

    func recentCachedPages(limit: Int = 20) -> [CachedPage] {
        guard let cacheScope else { return [] }
        return (try? cacheRepository?.loadRecentPages(limit: limit, scope: cacheScope)) ?? []
    }

    func clearCache() {
        try? cacheRepository?.clearAll()
        spaces = []
        resetNavigationSelection()
    }

    func activeSessionCookies(for url: URL) async -> [StoredHTTPCookie] {
        await cookieJar.cookies(for: url)
    }

    func canUseOfflineCache(after error: Error) -> Bool {
        guard let apiError = error as? APIError else {
            return true
        }

        guard case .httpStatus(let status, _) = apiError else {
            return true
        }
        return status != 401 && status != 403
    }

    private func loadCachedSpaces() {
        guard
            let cacheScope,
            let cached = try? cacheRepository?.loadSpaces(scope: cacheScope)
        else {
            return
        }
        spaces = cached
        selectDefaultSpaceIfNeeded()
    }

    private func loadCachedSidebarPages(spaceId: String, pageId: String?) throws -> [DocmostPage] {
        let scope = try requireCacheScope(message: "This page tree is not cached for the active account.")
        return try cacheRepository?.loadPageTree(spaceId: spaceId, parentPageId: pageId, scope: scope) ?? []
    }

    private func requireCachedPage(idOrSlugId: String) throws -> CachedPage {
        let scope = try requireCacheScope(message: "This page is not cached for offline reading.")
        guard let cached = try cacheRepository?.loadPage(idOrSlugId: idOrSlugId, scope: scope) else {
            throw APIError.connectionFailed("This page is not cached for offline reading.")
        }
        return cached
    }

    private func requireCachedEditablePage(idOrSlugId: String) throws -> DocmostEditablePage {
        let scope = try requireCacheScope(message: "This page is not cached for offline native reading.")
        guard let cached = try cacheRepository?.loadEditablePage(idOrSlugId: idOrSlugId, scope: scope) else {
            throw APIError.connectionFailed("This page is not cached for offline native reading.")
        }
        return cached
    }

    private func searchCachedPages(query: String) throws -> [DocmostSearchResult] {
        let scope = try requireCacheScope(message: "Search cache is unavailable until you sign in.")
        let pages = try cacheRepository?.loadRecentPages(limit: 100, scope: scope) ?? []
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

    private func updateCacheScope() {
        guard let currentUser, let apiClient else {
            cacheScope = nil
            return
        }

        cacheScope = CacheScope(serverBaseURL: apiClient.baseURL, userID: currentUser.user.id)
    }

    private func requireCacheScope(message: String) throws -> CacheScope {
        guard let cacheScope else {
            throw APIError.connectionFailed(message)
        }
        return cacheScope
    }
}
