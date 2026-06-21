import Foundation
import Testing
@testable import docmostly

struct SpaceLogoURLTests {
    @Test func buildsDocmostSpaceIconAttachmentURL() throws {
        let url = try #require(
            SpaceLogoURL.url(
                logo: "53cb235f-04f5-4d8a-b75f-dca2156797f9.png",
                serverURLString: "https://docs.example.com"
            )
        )

        #expect(
            url.absoluteString
                == "https://docs.example.com/api/attachments/img/space-icon/53cb235f-04f5-4d8a-b75f-dca2156797f9.png"
        )
    }

    @Test func percentEncodesStoredLogoFileName() throws {
        let url = try #require(
            SpaceLogoURL.url(
                logo: "space icon.png",
                serverURLString: "https://docs.example.com"
            )
        )

        #expect(
            url.absoluteString
                == "https://docs.example.com/api/attachments/img/space-icon/space%20icon.png"
        )
    }

    @Test func returnsAbsoluteLogoURLUnchanged() throws {
        let url = try #require(
            SpaceLogoURL.url(
                logo: "https://cdn.example.com/space.png",
                serverURLString: "https://docs.example.com"
            )
        )

        #expect(url.absoluteString == "https://cdn.example.com/space.png")
    }

    @Test func returnsNilForMissingLogo() {
        #expect(
            SpaceLogoURL.url(
                logo: nil,
                serverURLString: "https://docs.example.com"
            ) == nil
        )
        #expect(
            SpaceLogoURL.url(
                logo: " ",
                serverURLString: "https://docs.example.com"
            ) == nil
        )
    }
}
