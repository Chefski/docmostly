import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorBlockPropertyTests {
    @Test func updatesCalloutDetailsEmbedAndMathNodes() {
        let viewModel = richBlockViewModel()
        let calloutID = viewModel.document.blocks[0].id
        let detailsID = viewModel.document.blocks[1].id
        let embedID = viewModel.document.blocks[2].id
        let mathID = viewModel.document.blocks[3].id
        let drawioID = viewModel.document.blocks[4].id
        let excalidrawID = viewModel.document.blocks[5].id

        viewModel.updateCallout(blockID: calloutID, style: "warning", icon: "alert", text: "Check rollout")
        viewModel.updateDetails(blockID: detailsID, summary: "Checklist", body: "Ship native editor", isOpen: true)
        viewModel.updateEmbed(blockID: embedID, source: "https://example.com/video", provider: "Example")
        viewModel.updateMathBlock(blockID: mathID, text: "E = mc^2")
        viewModel.updateDrawio(
            blockID: drawioID,
            source: "/api/files/drawio/diagram.png",
            title: "Flow",
            alternativeText: "Flow diagram"
        )
        viewModel.updateExcalidraw(
            blockID: excalidrawID,
            source: "/api/files/excalidraw/sketch.png",
            title: "Sketch",
            alternativeText: "Sketch diagram"
        )

        let nodes = viewModel.document.proseMirrorDocument.content
        #expect(nodes[0].type == "callout")
        #expect(nodes[0].attrs?["type"] == .string("warning"))
        #expect(nodes[0].attrs?["icon"] == .string("alert"))
        #expect(nodes[0].content?.first?.content?.first?.text == "Check rollout")

        #expect(nodes[1].type == "details")
        #expect(nodes[1].attrs?["open"] == .bool(true))
        #expect(nodes[1].content?.first?.type == "detailsSummary")
        #expect(nodes[1].content?.first?.content?.first?.text == "Checklist")
        #expect(nodes[1].content?[1].type == "detailsContent")
        #expect(nodes[1].content?[1].content?.first?.content?.first?.text == "Ship native editor")

        #expect(nodes[2].type == "embed")
        #expect(nodes[2].attrs?["src"] == .string("https://example.com/video"))
        #expect(nodes[2].attrs?["provider"] == .string("Example"))

        #expect(nodes[3].type == "mathBlock")
        #expect(nodes[3].attrs?["text"] == .string("E = mc^2"))

        #expect(nodes[4].type == "drawio")
        #expect(nodes[4].attrs?["src"] == .string("/api/files/drawio/diagram.png"))
        #expect(nodes[4].attrs?["title"] == .string("Flow"))
        #expect(nodes[4].attrs?["alt"] == .string("Flow diagram"))

        #expect(nodes[5].type == "excalidraw")
        #expect(nodes[5].attrs?["src"] == .string("/api/files/excalidraw/sketch.png"))
        #expect(nodes[5].attrs?["title"] == .string("Sketch"))
        #expect(nodes[5].attrs?["alt"] == .string("Sketch diagram"))
        #expect(viewModel.isDirty == true)
    }

    private func richBlockViewModel() -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            calloutBlock(),
            detailsBlock(),
            embedBlock(),
            mathBlock(),
            drawioBlock(),
            excalidrawBlock()
        ])
        return viewModel
    }

    private func calloutBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .callout(NativeEditorCalloutBlock(style: "info", icon: nil, previewText: "Note")),
            text: AttributedString("Note"),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "callout")
        )
    }

    private func detailsBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .details(NativeEditorDetailsBlock(summary: "Details", previewText: "Body", isOpen: false)),
            text: AttributedString("Details"),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "details")
        )
    }

    private func embedBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .embed(NativeEditorEmbedBlock(
                source: "https://example.com",
                provider: "Example",
                alignment: "center",
                width: "800",
                height: "600"
            )),
            text: AttributedString("https://example.com"),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "embed")
        )
    }

    private func mathBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .mathBlock(NativeEditorMathBlock(text: "x")),
            text: AttributedString("x"),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "mathBlock")
        )
    }

    private func drawioBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .drawio(NativeEditorDiagramBlock(
                source: nil,
                title: nil,
                alternativeText: nil,
                attachmentID: nil,
                sizeInBytes: nil,
                width: nil,
                height: nil,
                aspectRatio: nil,
                alignment: nil
            )),
            text: AttributedString(""),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "drawio")
        )
    }

    private func excalidrawBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .excalidraw(NativeEditorDiagramBlock(
                source: nil,
                title: nil,
                alternativeText: nil,
                attachmentID: nil,
                sizeInBytes: nil,
                width: nil,
                height: nil,
                aspectRatio: nil,
                alignment: nil
            )),
            text: AttributedString(""),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "excalidraw")
        )
    }
}
