import Foundation
import Observation
import SwiftData

@MainActor
@Observable
// swiftlint:disable:next type_body_length
final class AppState {
    var phase: AppPhase = .restoring
    var serverURLString: String
    var currentUser: CurrentUserResponse?
    var spaces: [DocmostSpace] = []
    var selectedSidebarDestination: SidebarDestination?
    var selectedSpaceID: String?
    var selectedPageID: String?
    var savedServerURLStrings: [String]
    var isOffline = false
    var statusMessage: String?
    var pendingOfflineMutationCount = 0

    @ObservationIgnored private let settingsStore: LocalSettingsStore
    @ObservationIgnored private let authService: AuthService
    @ObservationIgnored private let cookieJar: SessionCookieJar
    @ObservationIgnored let crdtDocumentEngineFactory: (any NativeEditorCRDTDocumentEngineFactory)?
    @ObservationIgnored var cacheRepository: CacheRepository?
    @ObservationIgnored private var cacheReader: CacheReadRepository?
    @ObservationIgnored var cacheWriter: CacheWriteRepository?
    @ObservationIgnored var offlineQueue: OfflineMutationQueue?
    @ObservationIgnored var offlineQueueRepository: OfflineMutationQueueRepository?
    @ObservationIgnored var cacheScope: CacheScope?
    @ObservationIgnored private(set) var apiClient: DocmostAPIClient?
    @ObservationIgnored private var restoreTask: Task<Void, Never>?
    @ObservationIgnored private var spacesLoadTask: Task<Void, Never>?
    @ObservationIgnored private var pendingCacheWrites: [CacheWriteOperation] = []
    @ObservationIgnored private var cacheWriteTask: Task<Void, Never>?
    @ObservationIgnored var offlineReplayTask: Task<Void, Never>?
    @ObservationIgnored var pageCommentsByID: [String: [DocmostComment]] = [:]
    @ObservationIgnored var pageLabelsByID: [String: [DocmostLabel]] = [:]
    @ObservationIgnored var favoriteIDsByType: [FavoriteType: Set<String>] = [:]
    @ObservationIgnored var pageWatchStatusByID: [String: Bool] = [:]
    @ObservationIgnored var spaceWatchStatusByID: [String: Bool] = [:]

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
        savedServerURLStrings = self.settingsStore.loadSavedServerURLStrings()
    }

    static func production(crdtRuntimeBundle: Bundle = .main) -> AppState {
        AppState(
            crdtDocumentEngineFactory: NativeEditorJSCRDTEngineFactory.lazyBundled(in: crdtRuntimeBundle)
        )
    }

    func configure(modelContext: ModelContext, modelContainer: ModelContainer? = nil) {
        if cacheRepository == nil {
            cacheRepository = CacheRepository(context: modelContext)
        }
        if cacheReader == nil, let modelContainer {
            cacheReader = CacheReadRepository(modelContainer: modelContainer)
        }
        if cacheWriter == nil, let modelContainer {
            cacheWriter = CacheWriteRepository(modelContainer: modelContainer)
        }
        if offlineQueue == nil {
            offlineQueue = OfflineMutationQueue(context: modelContext)
        }
        if offlineQueueRepository == nil, let modelContainer {
            offlineQueueRepository = OfflineMutationQueueRepository(modelContainer: modelContainer)
        }
    }

    #if DEBUG
    func configurePreviewCacheScope(_ scope: CacheScope) {
        cacheScope = scope
    }
    #endif

    func scheduleCacheWrite(_ operation: CacheWriteOperation) {
        pendingCacheWrites.append(operation)
        cacheWriteTask?.cancel()
        cacheWriteTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: .milliseconds(750))
            } catch {
                return
            }

            await self.flushScheduledCacheWrites()
        }
    }

    private func flushScheduledCacheWrites() async {
        let operations = pendingCacheWrites
        pendingCacheWrites.removeAll(keepingCapacity: true)
        cacheWriteTask = nil

        guard let cacheWriter else {
            flushScheduledCacheWritesOnMainActor(operations)
            return
        }

        do {
            try await cacheWriter.perform(operations)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func flushScheduledCacheWritesOnMainActor(_ operations: [CacheWriteOperation]) {
        guard let cacheRepository else { return }

        for operation in operations {
            do {
                try operation.perform(using: cacheRepository)
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func cancelScheduledCacheWrites() {
        cacheWriteTask?.cancel()
        cacheWriteTask = nil
        pendingCacheWrites.removeAll(keepingCapacity: true)
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
            await loadCachedSpaces()
        }
    }

    func validateAndSaveServerURL(_ value: String) async throws {
        let url = try ServerURLValidator.normalizedURL(from: value)
        let client = DocmostAPIClient(baseURL: url, cookieJar: cookieJar)
        _ = try await client.send(.workspacePublic, as: PublicWorkspace.self)

        serverURLString = url.absoluteString
        settingsStore.saveServerURLString(serverURLString)
        savedServerURLStrings = settingsStore.loadSavedServerURLStrings()
        cancelScheduledCacheWrites()
        cancelOfflineReplay()
        apiClient = client
        currentUser = nil
        cacheScope = nil
        pendingOfflineMutationCount = 0
        clearOfflineProjections()
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
        cancelScheduledCacheWrites()
        cancelOfflineReplay()
        currentUser = nil
        cacheScope = nil
        pendingOfflineMutationCount = 0
        clearOfflineProjections()
        spaces = []
        resetNavigationSelection()
        phase = .unauthenticated
    }

    func loadSpaces() async {
        if let spacesLoadTask {
            await spacesLoadTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoadSpaces()
        }
        spacesLoadTask = task
        await task.value
        spacesLoadTask = nil
    }

    private func performLoadSpaces() async {
        guard let apiClient else {
            await loadCachedSpaces()
            return
        }

        do {
            let response: PaginatedResponse<DocmostSpace> = try await apiClient.send(.spaces())
            spaces = response.items
            selectDefaultSpaceIfNeeded()
            isOffline = false
            if let cacheScope {
                scheduleCacheWrite(.saveSpaces(response.items, cacheScope))
            }
            await refreshOfflineMutationCount()
            scheduleOfflineQueueReconciliation()
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else {
                spaces = []
                return
            }
            await loadCachedSpaces()
        }
    }

    func loadSidebarPages(spaceId: String, pageId: String? = nil) async throws -> [DocmostPage] {
        guard let apiClient else {
            return try await loadCachedSidebarPages(spaceId: spaceId, pageId: pageId)
        }

        do {
            let response: PaginatedResponse<DocmostPage> = try await apiClient.send(
                .sidebarPages(spaceId: pageId == nil ? spaceId : nil, pageId: pageId)
            )
            isOffline = false
            if let cacheScope {
                scheduleCacheWrite(.savePageTree(
                    spaceId: spaceId,
                    parentPageId: pageId,
                    pages: response.items,
                    scope: cacheScope
                ))
            }
            return response.items
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
            return try await loadCachedSidebarPages(spaceId: spaceId, pageId: pageId)
        }
    }

    func loadPage(idOrSlugId: String) async throws -> PageLoadResult {
        guard let apiClient else {
            let cached = try await requireCachedPage(idOrSlugId: idOrSlugId)
            return PageLoadResult(page: cached.page, html: cached.htmlContent, isFromCache: true)
        }

        do {
            let page: DocmostPage = try await apiClient.send(.pageInfo(pageId: idOrSlugId, format: .html))
            let html = page.content ?? ""
            isOffline = false
            if let cacheScope {
                scheduleCacheWrite(.savePage(page, htmlContent: html, scope: cacheScope))
            }
            return PageLoadResult(page: page, html: html, isFromCache: false)
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
            let cached = try await requireCachedPage(idOrSlugId: idOrSlugId)
            if let cacheScope {
                scheduleCacheWrite(.markOpened(idOrSlugId: idOrSlugId, scope: cacheScope))
            }
            return PageLoadResult(page: cached.page, html: cached.htmlContent, isFromCache: true)
        }
    }

    func loadEditablePage(idOrSlugId: String) async throws -> DocmostEditablePage {
        guard let apiClient else {
            return try await requireCachedEditablePage(idOrSlugId: idOrSlugId)
        }

        do {
            let page: DocmostEditablePage = try await apiClient.send(.pageInfo(pageId: idOrSlugId, format: .json))
            isOffline = false
            if let cacheScope {
                scheduleCacheWrite(.saveEditablePage(page, scope: cacheScope))
            }
            return page
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
            return try await requireCachedEditablePage(idOrSlugId: idOrSlugId)
        }
    }

    func updatePage(pageId: String, title: String, document: ProseMirrorDocument) async throws -> DocmostEditablePage {
        guard let apiClient else {
            return try await queuePageUpdate(pageId: pageId, title: title, document: document)
        }

        do {
            let page: DocmostEditablePage = try await apiClient.send(.updatePage(
                pageId: pageId,
                title: title,
                content: document,
                format: .json,
                operation: .replace
            ))
            isOffline = false
            if let cacheScope {
                scheduleCacheWrite(.saveEditablePage(page, scope: cacheScope))
            }
            do {
                try await clearPendingPageUpdate(pageId: pageId, title: title, document: document)
                scheduleOfflineQueueReconciliation()
            } catch {
                statusMessage = error.localizedDescription
            }
            return page
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queuePageUpdate(pageId: pageId, title: title, document: document)
        }
    }

    func search(query: String, spaceId: String?) async throws -> [DocmostSearchResult] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return []
        }

        guard let apiClient else {
            return try await searchCachedPages(query: query)
        }

        do {
            let response: SearchResponse = try await apiClient.send(.search(query: query, spaceId: spaceId))
            isOffline = false
            return response.items
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
            return try await searchCachedPages(query: query)
        }
    }

    func searchMentionSuggestions(
        query: String,
        spaceId: String?,
        limit: Int = 10
    ) async throws -> DocmostMentionSuggestionResponse {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return DocmostMentionSuggestionResponse()
        }

        guard let apiClient else {
            return try await cachedMentionSuggestions(query: query)
        }

        do {
            let response: DocmostMentionSuggestionResponse = try await apiClient.send(.searchSuggestions(
                query: query,
                includeUsers: true,
                includePages: true,
                spaceId: spaceId,
                limit: limit
            ))
            isOffline = false
            return response
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
            return try await cachedMentionSuggestions(query: query)
        }
    }

    func attachmentLinks(pageId: String) async -> [DocmostAttachmentLink] {
        guard let cacheScope else { return [] }
        if let cacheReader {
            return (try? await cacheReader.loadAttachmentLinks(pageId: pageId, scope: cacheScope)) ?? []
        }
        return (try? cacheRepository?.loadAttachmentLinks(pageId: pageId, scope: cacheScope)) ?? []
    }

    func recentCachedPages(limit: Int = 20) async -> [DocmostPage] {
        guard let cacheScope else { return [] }
        if let cacheReader {
            return (try? await cacheReader.loadRecentPageValues(limit: limit, scope: cacheScope)) ?? []
        }
        return (try? cacheRepository?.loadRecentPageValues(limit: limit, scope: cacheScope)) ?? []
    }

    func clearCache() async {
        cancelScheduledCacheWrites()
        if let cacheWriter {
            try? await cacheWriter.perform([.clearAll])
        } else {
            try? cacheRepository?.clearAll()
        }
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

    private func loadCachedSpaces() async {
        guard let cacheScope else { return }

        let cached: [DocmostSpace]?
        if let cacheReader {
            cached = try? await cacheReader.loadSpaces(scope: cacheScope)
        } else {
            cached = try? cacheRepository?.loadSpaces(scope: cacheScope)
        }

        guard let cached else { return }
        spaces = cached
        selectDefaultSpaceIfNeeded()
    }

    private func loadCachedSidebarPages(spaceId: String, pageId: String?) async throws -> [DocmostPage] {
        let scope = try requireCacheScope(message: "This page tree is not cached for the active account.")
        if let cacheReader {
            return try await cacheReader.loadPageTree(spaceId: spaceId, parentPageId: pageId, scope: scope)
        }
        return try cacheRepository?.loadPageTree(spaceId: spaceId, parentPageId: pageId, scope: scope) ?? []
    }

    private func requireCachedPage(idOrSlugId: String) async throws -> CachedPageSnapshot {
        let scope = try requireCacheScope(message: "This page is not cached for offline reading.")
        let cached: CachedPageSnapshot?
        if let cacheReader {
            cached = try await cacheReader.loadPageSnapshot(idOrSlugId: idOrSlugId, scope: scope)
        } else {
            cached = try cacheRepository?.loadPageSnapshot(idOrSlugId: idOrSlugId, scope: scope)
        }
        guard let cached else {
            throw APIError.connectionFailed("This page is not cached for offline reading.")
        }
        return cached
    }

    private func requireCachedEditablePage(idOrSlugId: String) async throws -> DocmostEditablePage {
        let scope = try requireCacheScope(message: "This page is not cached for offline native reading.")
        let cached: DocmostEditablePage?
        if let cacheReader {
            cached = try await cacheReader.loadEditablePage(idOrSlugId: idOrSlugId, scope: scope)
        } else {
            cached = try cacheRepository?.loadEditablePage(idOrSlugId: idOrSlugId, scope: scope)
        }
        guard let cached else {
            throw APIError.connectionFailed("This page is not cached for offline native reading.")
        }
        return cached
    }

    private func searchCachedPages(query: String) async throws -> [DocmostSearchResult] {
        let scope = try requireCacheScope(message: "Search cache is unavailable until you sign in.")
        if let cacheReader {
            return try await cacheReader.searchCachedPages(query: query, limit: 100, scope: scope)
        }
        return try cacheRepository?.searchCachedPages(query: query, limit: 100, scope: scope) ?? []
    }

    private func cachedMentionSuggestions(query: String) async throws -> DocmostMentionSuggestionResponse {
        let pages = try await searchCachedPages(query: query).map(DocmostMentionPageSuggestion.init(searchResult:))
        return DocmostMentionSuggestionResponse(pages: pages)
    }

    private func updateCacheScope() {
        guard let currentUser, let apiClient else {
            cacheScope = nil
            return
        }

        cacheScope = CacheScope(serverBaseURL: apiClient.baseURL, userID: currentUser.user.id)
        Task { [weak self] in
            await self?.refreshOfflineMutationCount()
        }
    }

    func requireCacheScope(message: String) throws -> CacheScope {
        guard let cacheScope else {
            throw APIError.connectionFailed(message)
        }
        return cacheScope
    }
}

extension AppState {
    func restoreIfNeeded() async {
        if let restoreTask {
            await restoreTask.value
            return
        }

        guard phase == .restoring else { return }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.restore()
        }
        restoreTask = task
        await task.value
        restoreTask = nil
    }
}
