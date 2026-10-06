import Foundation

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

    func restore() async {
        var restoredSession: StoredSession?
        do {
            guard serverURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                phase = .needsServer
                return
            }

            let serverURL = try ServerURLValidator.normalizedURL(from: serverURLString)
            apiClient = DocmostAPIClient(baseURL: serverURL, cookieJar: cookieJar)
            serverURLString = serverURL.absoluteString

            // A session that was rejected or logged out is never adopted again, even when offline.
            if settingsStore.loadSessionInvalidated() {
                await purgeInvalidatedSession()
                currentUser = nil
                cacheScope = nil
                phase = .unauthenticated
                return
            }

            restoredSession = try await authService.restoreSession()
            if let restoredSession {
                apiClient = DocmostAPIClient(baseURL: restoredSession.serverBaseURL, cookieJar: cookieJar)
                serverURLString = restoredSession.serverBaseURL.absoluteString
            }

            guard let apiClient else {
                phase = .needsServer
                return
            }

            let user: CurrentUserResponse = try await apiClient.send(.currentUser)
            // Refresh the stored user and any rotated cookies; a failure here must not block sign-in.
            // This finishes before `.authenticated` so a logout cannot interleave with the save.
            try? await authService.persistSession(for: apiClient, currentUser: user)
            if settingsStore.loadSessionInvalidated() {
                await purgeInvalidatedSession()
                currentUser = nil
                cacheScope = nil
                phase = .unauthenticated
                return
            }
            currentUser = user
            updateCacheScope()
            phase = .authenticated
            await loadSpaces()
        } catch {
            // A stored session that only failed to reach the server stays signed in on the offline cache.
            if Self.isConnectivityFailure(error),
               let cachedUser = restoredSession?.currentUser {
                currentUser = cachedUser
                updateCacheScope()
                phase = .authenticated
                isOffline = true
                // The server was just unreachable, so read the cache instead of repeating the failed request.
                await loadCachedSpaces()
                return
            }

            if canUseOfflineCache(after: error) == false {
                // The server rejected the session (401/403), so it must not be re-adopted on a later offline launch.
                settingsStore.saveSessionInvalidated(true)
                await purgeInvalidatedSession()
            }
            currentUser = nil
            cacheScope = nil
            phase = serverURLString.isEmpty ? .needsServer : .unauthenticated
        }
    }

    /// Whether `error` means the server could not be reached, as opposed to it answering badly or rejecting us.
    static func isConnectivityFailure(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed:
                return true
            default:
                return false
            }
        }
        if let apiError = error as? APIError, case .connectionFailed = apiError {
            return true
        }
        return false
    }

    /// Best-effort removal of the persisted session; the invalidation marker is only dropped once the clear succeeded.
    private func purgeInvalidatedSession() async {
        do {
            try await authService.logout(client: nil)
            settingsStore.saveSessionInvalidated(false)
        } catch {
            // The marker stays set so the next launch retries the clear instead of restoring the session.
        }
    }
}
