import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMediaMarkdownExportTests {
    @Test func markdownExportUsesFilenameLabelsForUnlabeledFileBlocks() {
        let blocks = [
            NativeEditorBlock(
                kind: .video(NativeEditorMediaBlock(
                    source: "/api/files/video-1/Launch%20demo.mp4",
                    alternativeText: nil,
                    title: nil,
                    attachmentID: nil,
                    sizeInBytes: nil,
                    width: nil,
                    height: nil,
                    aspectRatio: nil,
                    alignment: nil
                )),
                text: AttributedString(""),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .audio(NativeEditorMediaBlock(
                    source: #"folder name\Briefing.m4a"#,
                    alternativeText: nil,
                    title: nil,
                    attachmentID: nil,
                    sizeInBytes: nil,
                    width: nil,
                    height: nil,
                    aspectRatio: nil,
                    alignment: nil
                )),
                text: AttributedString(""),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .pdf(NativeEditorPDFBlock(
                    source: "/api/files/pdf-1/Spec.pdf?download=1",
                    name: nil,
                    attachmentID: nil,
                    sizeInBytes: nil,
                    width: nil,
                    height: nil
                )),
                text: AttributedString(""),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .attachment(NativeEditorAttachmentBlock(
                    url: "/api/files/file-1/Archive.zip#download",
                    name: nil,
                    mimeType: nil,
                    sizeInBytes: nil,
                    attachmentID: nil
                )),
                text: AttributedString(""),
                alignment: .left
            )
        ]

        #expect(NativeEditorMarkdownParser.markdown(from: blocks) == #"""
        [Launch%20demo.mp4](/api/files/video-1/Launch%20demo.mp4)
        [Briefing.m4a](folder name\Briefing.m4a)
        [Spec.pdf](/api/files/pdf-1/Spec.pdf?download=1)
        [Archive.zip](/api/files/file-1/Archive.zip#download)
        """#)
    }
}
