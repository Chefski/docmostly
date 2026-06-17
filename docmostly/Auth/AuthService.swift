import Foundation

actor AuthService {
    private let sessionStore: any SessionStore
    private let cookieStorage: HTTPCookieStorage

    init(
        sessionStore: any SessionStore = KeychainSessionStore(),
        cookieStorage: HTTPCookieStorage = .shared
    ) {
        self.sessionStore = sessionStore
        self.cookieStorage = cookieStorage
    }

    func restoreSession() async throws -> StoredSession? {
        let session = try await sessionStore.load()
        if let session {
            CookieBridge.install(session.cookies, into: cookieStorage)
        }
        return session
    }

    func persistSession(for client: DocmostAPIClient) async throws {
        let cookies = CookieBridge.storedCookies(from: cookieStorage, for: client.baseURL)
        try await sessionStore.save(StoredSession(serverBaseURL: client.baseURL, cookies: cookies))
    }

    func login(credentials: AuthCredentials, client: DocmostAPIClient) async throws -> CurrentUserResponse {
        try await client.sendVoid(.login(email: credentials.email, password: credentials.password))
        try await persistSession(for: client)
        return try await client.send(.currentUser)
    }

    func logout(client: DocmostAPIClient?) async throws {
        let session = try await sessionStore.load()

        if let client {
            try? await client.sendVoid(.logout)
        }

        if let session {
            CookieBridge.clear(session.cookies, from: cookieStorage)
        }

        try await sessionStore.clear()
    }
}
