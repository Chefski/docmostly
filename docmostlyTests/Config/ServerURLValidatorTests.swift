import Foundation
import Testing
@testable import docmostly

struct ServerURLValidatorTests {
    @Test func acceptsHTTPSURLAndRemovesTrailingSlash() throws {
        let url = try ServerURLValidator.normalizedURL(from: "https://docs.example.com/")

        #expect(url.absoluteString == "https://docs.example.com")
    }

    @Test func addsHTTPSWhenSchemeIsMissing() throws {
        let url = try ServerURLValidator.normalizedURL(from: "docs.example.com")

        #expect(url.scheme == "https")
        #expect(url.host == "docs.example.com")
    }

    @Test func rejectsUnsupportedSchemes() {
        #expect(throws: ServerURLValidationError.unsupportedScheme) {
            _ = try ServerURLValidator.normalizedURL(from: "ftp://docs.example.com")
        }
    }
}
