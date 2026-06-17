import Foundation
import Testing
@testable import docmostly

struct SessionStoreTests {
    @Test func memoryStoreRestoresSavedSession() async throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let cookie = StoredHTTPCookie(
            name: "authToken",
            value: "secret-token",
            domain: "docs.example.com",
            path: "/",
            expiresAt: Date.now.addingTimeInterval(3600),
            isSecure: true,
            isHTTPOnly: true
        )
        let session = StoredSession(serverBaseURL: baseURL, cookies: [cookie])
        let store = InMemorySessionStore()

        try await store.save(session)

        let restored = try await store.load()
        #expect(restored?.serverBaseURL == baseURL)
        #expect(restored?.cookies.first?.name == "authToken")
        #expect(restored?.cookies.first?.value == "secret-token")
    }

    @Test func memoryStoreClearsSavedSession() async throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let store = InMemorySessionStore()

        try await store.save(StoredSession(serverBaseURL: baseURL, cookies: []))
        try await store.clear()

        let restored = try await store.load()
        #expect(restored == nil)
    }
}
