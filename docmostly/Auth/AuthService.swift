import Foundation

actor AuthService {
    private let sessionStore: any SessionStore
    private let cookieJar: SessionCookieJar

    init(
        sessionStore: any SessionStore = KeychainSessionStore(),
        cookieJar: SessionCookieJar = SessionCookieJar()
    ) {
        self.sessionStore = sessionStore
        self.cookieJar = cookieJar
    }

    func restoreSession() async throws -> StoredSession? {
        let session = try await sessionStore.load()
        if let session {
            await cookieJar.replaceAll(session.cookies)
        } else {
            await cookieJar.clear()
        }
        return session
    }

    func persistSession(for client: DocmostAPIClient, currentUser: CurrentUserResponse?) async throws {
        let cookies = await cookieJar.allCookies()
        try await sessionStore.save(StoredSession(
            serverBaseURL: client.baseURL,
            cookies: cookies,
            currentUser: currentUser
        ))
    }

    func login(credentials: AuthCredentials, client: DocmostAPIClient) async throws -> CurrentUserResponse {
        try await client.sendVoid(.login(email: credentials.email, password: credentials.password))
        let currentUser: CurrentUserResponse = try await client.send(.currentUser)
        try await persistSession(for: client, currentUser: currentUser)
        return currentUser
    }

    func logout(client: DocmostAPIClient?) async throws {
        if let client {
            try? await client.sendVoid(.logout)
        }

        await cookieJar.clear()
        try await sessionStore.clear()
    }
}
