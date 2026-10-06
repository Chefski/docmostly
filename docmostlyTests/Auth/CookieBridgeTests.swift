import Testing
@testable import docmostly

struct CookieBridgeTests {
    @Test func cookieDomainMatchesServerHostAndSubdomains() {
        #expect(CookieBridge.cookieDomain("docs.example.com", matchesHost: "docs.example.com"))
        #expect(CookieBridge.cookieDomain(".docs.example.com", matchesHost: "docs.example.com"))
        #expect(CookieBridge.cookieDomain(".example.com", matchesHost: "docs.example.com"))
        #expect(CookieBridge.cookieDomain("Docs.Example.com", matchesHost: "docs.example.com"))
    }

    @Test func cookieDomainIgnoresUnrelatedHosts() {
        #expect(CookieBridge.cookieDomain("other.example.com", matchesHost: "docs.example.com") == false)
        #expect(CookieBridge.cookieDomain("ample.com", matchesHost: "docs.example.com") == false)
        #expect(CookieBridge.cookieDomain("docs.example.com", matchesHost: "example.com") == false)
        #expect(CookieBridge.cookieDomain("", matchesHost: "docs.example.com") == false)
        #expect(CookieBridge.cookieDomain(".", matchesHost: "docs.example.com") == false)
    }
}
