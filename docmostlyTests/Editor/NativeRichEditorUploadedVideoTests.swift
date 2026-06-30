import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorUploadedVideoTests {
    @Test func insertingUploadedVideoPreservesDocmostUploadDimensionsFromSourceFile() throws {
        let sourceURL = try writeTinyVideoFixture()
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
        }

        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/video"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.insertUploadedAttachment(
            uploadedAttachment(fileName: "Launch demo.mp4", mimeType: "video/mp4", fileExt: "mp4"),
            as: .video,
            sourceFileURL: sourceURL
        )

        let updatedBlock = viewModel.document.blocks[0]
        guard case .video(let video) = updatedBlock.kind else {
            Issue.record("Expected video block")
            return
        }

        let expectedAspectRatio = (Double(64) / Double(36)).description
        let node = viewModel.document.proseMirrorDocument.content.first
        #expect(video.width == "64")
        #expect(video.height == "36")
        #expect(video.aspectRatio == expectedAspectRatio)
        #expect(node?.attrs?["width"] == .int(64))
        #expect(node?.attrs?["height"] == .int(36))
        #expect(node?.attrs?["aspectRatio"] == .double(Double(64) / Double(36)))
    }

    private func uploadedAttachment(
        fileName: String,
        mimeType: String,
        fileExt: String
    ) -> DocmostAttachment {
        DocmostAttachment(
            id: "attachment-1",
            fileName: fileName,
            filePath: nil,
            fileSize: 4096,
            fileExt: fileExt,
            mimeType: mimeType,
            type: "file",
            creatorId: "user-1",
            pageId: "page-1",
            spaceId: "space-1",
            workspaceId: "workspace-1",
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil
        )
    }

    private func writeTinyVideoFixture() throws -> URL {
        let chunks = [
            "AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAuBtZGF0AAACrgYF//+q3EXpvebZSLeW",
            "LNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENv",
            "cHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNh",
            "YmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBw",
            "c3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhk",
            "Y3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRz",
            "PTEgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2Vk",
            "PTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRh",
            "cHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBr",
            "ZXlpbnRfbWluPTI1IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1i",
            "dHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQw",
            "IGFxPTE6MS4wMACAAAAAImWIhAAr//7Y5/Msk5d6t+g02kS2qXDqy9r4GQm3R0JYLm8AAAMXbW9vdgAAAGxtdmhk",
            "AAAAAAAAAAAAAAAAAAAD6AAAACgAAQAAAQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAA",
            "AABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAkF0cmFrAAAAXHRraGQAAAADAAAAAAAAAAAAAAAB",
            "AAAAAAAAACgAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAEAAAAAk",
            "AAAAAAAkZWR0cwAAABxlbHN0AAAAAAAAAAEAAAAoAAAAAAABAAAAAAG5bWRpYQAAACBtZGhkAAAAAAAAAAAAAAAA",
            "AAAyAAAAAgBVxAAAAAAALWhkbHIAAAAAAAAAAHZpZGUAAAAAAAAAAAAAAABWaWRlb0hhbmRsZXIAAAABZG1pbmYA",
            "AAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAASRzdGJsAAAA",
            "wHN0c2QAAAAAAAAAAQAAALBhdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAEAAJABIAAAASAAAAAAAAAABFUxh",
            "dmM2Mi4yOC4xMDIgbGlieDI2NAAAAAAAAAAAAAAAGP//AAAANmF2Y0MBZAAK/+EAGWdkAAqs2UR/nwEQAAADABAA",
            "AAMDIPEiWWABAAZo6+PLIsD9+PgAAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAACOMAAAAAAAAAAGHN0dHMA",
            "AAAAAAAAAQAAAAEAAAIAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAABAAAAAQAAABRzdHN6AAAAAAAAAtgAAAABAAAA",
            "FHN0Y28AAAAAAAAAAQAAADAAAABidWR0YQAAAFptZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAA",
            "AAAAAAAAAC1pbHN0AAAAJal0b28AAAAdZGF0YQAAAAEAAAAATGF2ZjYyLjEyLjEwMg=="
        ]
        guard let data = Data(base64Encoded: chunks.joined()) else {
            throw TinyVideoFixtureError.invalidBase64
        }

        let url = URL.temporaryDirectory.appending(path: "docmostly-upload-video-\(UUID().uuidString).mp4")
        try data.write(to: url, options: .atomic)
        return url
    }
}

private enum TinyVideoFixtureError: Error {
    case invalidBase64
}
