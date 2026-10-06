import Foundation
import Testing
@testable import docmostly

@MainActor
struct AppStateSessionInvalidationTests {
    private let suiteName = "Docmostly.AppStateSessionInvalidationTests.\(UUID().uuidString)"

    @Test func failedLogoutClearKeepsSessionInvalidatedAcrossRestore() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = FailingClearSessionStore(session: try storedSession(), clearShouldFail: true)
        let appState = makeAppState(store: store, userDefaults: userDefaults)

        await appState.logout()

        #expect(appState.logoutErrorMessage != nil)
        #expect(appState.settingsStore.loadSessionInvalidated())

        // The Keychain still holds the session, but a later offline launch must not adopt it.
        let relaunched = makeAppState(store: store, userDefaults: userDefaults)
        await relaunched.restore()

        #expect(relaunched.phase == .unauthenticated)
        #expect(relaunched.currentUser == nil)
        #expect(relaunched.settingsStore.loadSessionInvalidated())
    }

    @Test func restorePurgesInvalidatedSessionAndClearsMarker() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = FailingClearSessionStore(session: try storedSession(), clearShouldFail: false)
        let appState = makeAppState(store: store, userDefaults: userDefaults)
        appState.settingsStore.saveSessionInvalidated(true)

        await appState.restore()

        let remainingSession = try await store.load()
        #expect(remainingSession == nil)
        #expect(appState.phase == .unauthenticated)
        #expect(appState.apiClient != nil)
        #expect(appState.settingsStore.loadSessionInvalidated() == false)
    }

    @Test func restoreKeepsMarkerWhenPurgeFails() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = FailingClearSessionStore(session: try storedSession(), clearShouldFail: true)
        let appState = makeAppState(store: store, userDefaults: userDefaults)
        appState.settingsStore.saveSessionInvalidated(true)

        await appState.restore()

        #expect(appState.phase == .unauthenticated)
        #expect(appState.settingsStore.loadSessionInvalidated())

        // Once the Keychain recovers, the next launch removes the session and drops the marker.
        store.setClearShouldFail(false)
        await appState.restore()

        let remainingSession = try await store.load()
        #expect(remainingSession == nil)
        #expect(appState.settingsStore.loadSessionInvalidated() == false)
    }

    @Test func successfulLogoutClearsMarker() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = FailingClearSessionStore(session: try storedSession(), clearShouldFail: false)
        let appState = makeAppState(store: store, userDefaults: userDefaults)

        await appState.logout()

        #expect(appState.logoutErrorMessage == nil)
        #expect(appState.settingsStore.loadSessionInvalidated() == false)
        #expect(appState.phase == .unauthenticated)
    }

    @Test func onlyGenuineConnectivityFailuresAllowTheOfflineFallback() {
        let connectivityErrors: [Error] = [
            URLError(.notConnectedToInternet), URLError(.networkConnectionLost), URLError(.timedOut),
            URLError(.cannotFindHost), URLError(.cannotConnectToHost), URLError(.dnsLookupFailed),
            URLError(.internationalRoamingOff), URLError(.dataNotAllowed),
            APIError.connectionFailed("offline")
        ]
        for error in connectivityErrors {
            #expect(AppState.isConnectivityFailure(error))
        }

        let otherErrors: [Error] = [
            URLError(.cancelled), URLError(.badServerResponse), URLError(.serverCertificateUntrusted),
            APIError.httpStatus(500, nil), APIError.httpStatus(401, nil), APIError.invalidResponse,
            APIError.decodingFailed("bad"), APIError.missingData, APIError.responseTooLarge,
            ServerURLValidationError.empty
        ]
        for error in otherErrors {
            #expect(AppState.isConnectivityFailure(error) == false)
        }
    }

    private func makeAppState(store: FailingClearSessionStore, userDefaults: UserDefaults) -> AppState {
        let settingsStore = LocalSettingsStore(userDefaults: userDefaults)
        settingsStore.saveServerURLString("https://docs.example.com")
        let cookieJar = SessionCookieJar()
        return AppState(
            settingsStore: settingsStore,
            authService: AuthService(sessionStore: store, cookieJar: cookieJar),
            cookieJar: cookieJar
        )
    }

    private func storedSession() throws -> StoredSession {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let cookie = StoredHTTPCookie(
            name: "authToken",
            value: "stale-token",
            domain: "docs.example.com",
            path: "/",
            expiresAt: nil,
            isSecure: true,
            isHTTPOnly: true
        )
        return StoredSession(serverBaseURL: baseURL, cookies: [cookie])
    }
}
