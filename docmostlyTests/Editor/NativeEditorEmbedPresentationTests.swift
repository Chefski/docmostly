import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorEmbedPresentationTests {
    @Test func decodesThreeEqualColumnsFromDocmostDocument() throws {
        let document = NativeEditorDocument(proseMirrorDocument: ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "columns",
                attrs: ["layout": .string("three_equal")],
                content: [
                    columnNode("Columns 1"),
                    columnNode("Column 2"),
                    columnNode("Column 3")
                ]
            )
        ]))

        try #require(document.blocks.count == 1)
        guard case .columns(let columns) = document.blocks[0].kind else {
            Issue.record("Expected a native columns block.")
            return
        }

        #expect(columns.layout == "three_equal")
        #expect(columns.columnCount == 3)
        #expect(columns.normalizedColumnTexts == ["Columns 1", "Column 2", "Column 3"])
    }

    @Test func infersSpotifyProviderFromEmbedSource() throws {
        let source = "https://open.spotify.com/embed/track/7FVZXcWUEkFOwMck2L04pr?utm_source=generator"
        let document = NativeEditorDocument(proseMirrorDocument: ProseMirrorDocument(content: [
            ProseMirrorNode(type: "embed", attrs: [
                "src": .string(source),
                "width": .int(800),
                "height": .int(600)
            ])
        ]))

        try #require(document.blocks.count == 1)
        guard case .embed(let embed) = document.blocks[0].kind else {
            Issue.record("Expected a native embed block.")
            return
        }

        #expect(embed.provider == "Spotify")
        #expect(embed.displayProvider == "Spotify")
        #expect(embed.spotifyEmbedURL?.absoluteString == source)
    }

    @Test func canonicalizesStandardSpotifyShareURLToEmbedURL() {
        let embed = NativeEditorEmbedBlock(
            source: "https://open.spotify.com/track/7FVZXcWUEkFOwMck2L04pr?si=650fa2b296164db6",
            provider: nil,
            alignment: nil,
            width: nil,
            height: nil
        )

        #expect(embed.displayProvider == "Spotify")
        #expect(
            embed.spotifyEmbedURL?.absoluteString ==
                "https://open.spotify.com/embed/track/7FVZXcWUEkFOwMck2L04pr?si=650fa2b296164db6"
        )
    }

    @Test func infersYouTubeProviderAndPlayerSourceFromNoCookieEmbed() throws {
        let document = NativeEditorDocument(proseMirrorDocument: ProseMirrorDocument(content: [
            ProseMirrorNode(type: "embed", attrs: [
                "src": .string("https://www.youtube-nocookie.com/embed/DTUDPMmy6IU"),
                "width": .int(800),
                "height": .int(600)
            ])
        ]))

        try #require(document.blocks.count == 1)
        guard case .embed(let embed) = document.blocks[0].kind else {
            Issue.record("Expected a native embed block.")
            return
        }

        #expect(embed.provider == "YouTube")
        #expect(embed.displayProvider == "YouTube")
        #expect(embed.youtubePlayerSource == "https://www.youtube.com/watch?v=DTUDPMmy6IU")
    }

    @Test func preservesYouTubeStartParametersInPlayerSource() {
        #expect(
            NativeEditorEmbedResolver.youtubeWatchSource(
                from: "https://www.youtube.com/watch?v=DTUDPMmy6IU&start=90"
            ) == "https://www.youtube.com/watch?v=DTUDPMmy6IU&start=90"
        )
        #expect(
            NativeEditorEmbedResolver.youtubeWatchSource(
                from: "https://youtu.be/DTUDPMmy6IU?t=1m30s"
            ) == "https://www.youtube.com/watch?v=DTUDPMmy6IU&t=1m30s"
        )
    }

    @Test func genericWebEmbedLinksRejectNonWebSchemes() {
        #expect(NativeEditorWebURLPolicy.webURL(from: "https://docs.example.com/embed") != nil)
        #expect(NativeEditorWebURLPolicy.webURL(from: "http://docs.example.com/embed") != nil)
        #expect(NativeEditorWebURLPolicy.webURL(from: "file:///etc/passwd") == nil)
        #expect(NativeEditorWebURLPolicy.webURL(from: "docmostly://page/1") == nil)
    }

    @Test func documentResourcesStayOnServerOrigin() {
        let serverURLString = "https://docs.example.com"

        #expect(
            NativeEditorWebURLPolicy.documentResourceURL(
                from: "/uploads/diagram.svg",
                serverURLString: serverURLString
            )?.absoluteString == "https://docs.example.com/uploads/diagram.svg"
        )
        #expect(
            NativeEditorWebURLPolicy.documentResourceURL(
                from: "https://docs.example.com/uploads/diagram.svg",
                serverURLString: serverURLString
            )?.absoluteString == "https://docs.example.com/uploads/diagram.svg"
        )
        #expect(
            NativeEditorWebURLPolicy.documentResourceURL(
                from: "https://evil.example.com/uploads/diagram.svg",
                serverURLString: serverURLString
            ) == nil
        )
        #expect(
            NativeEditorWebURLPolicy.documentResourceURL(
                from: "file:///etc/passwd",
                serverURLString: serverURLString
            ) == nil
        )
        #expect(
            NativeEditorWebURLPolicy.documentResourceURL(
                from: "//evil.example.com/uploads/diagram.svg",
                serverURLString: serverURLString
            ) == nil
        )
    }

    private func columnNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "column",
            content: [
                ProseMirrorNode(
                    type: "paragraph",
                    content: [ProseMirrorNode(type: "text", text: text)]
                )
            ]
        )
    }
}
