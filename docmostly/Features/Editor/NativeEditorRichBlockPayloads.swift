import Foundation

struct NativeEditorTable: Equatable, Hashable, Sendable {
    var rows: [NativeEditorTableRow]

    var columnCount: Int {
        rows.map(\.cells.count).max() ?? 0
    }
}

struct NativeEditorTableRow: Equatable, Hashable, Sendable {
    var cells: [NativeEditorTableCell]
}

struct NativeEditorTableCell: Equatable, Hashable, Sendable {
    var plainText: String
    var isHeader: Bool
    var backgroundColorName: String?
}

struct NativeEditorMediaBlock: Equatable, Hashable, Sendable {
    var source: String?
    var alternativeText: String?
    var attachmentID: String?
    var sizeInBytes: Int?
    var width: String?
    var height: String?
    var aspectRatio: String?
    var alignment: String?
}

struct NativeEditorPDFBlock: Equatable, Hashable, Sendable {
    var source: String?
    var name: String?
    var attachmentID: String?
    var sizeInBytes: Int?
    var width: String?
    var height: String?
}

struct NativeEditorAttachmentBlock: Equatable, Hashable, Sendable {
    var url: String?
    var name: String?
    var mimeType: String?
    var sizeInBytes: Int?
    var attachmentID: String?
}

struct NativeEditorCalloutBlock: Equatable, Hashable, Sendable {
    var style: String
    var icon: String?
    var previewText: String
}

struct NativeEditorDetailsBlock: Equatable, Hashable, Sendable {
    var summary: String
    var previewText: String
    var isOpen: Bool
}

struct NativeEditorColumnsBlock: Equatable, Hashable, Sendable {
    var layout: String
    var widthMode: String
    var columnCount: Int
    var previewText: String
    var columnTexts: [String] = []
}

struct NativeEditorTransclusionSourceBlock: Equatable, Hashable, Sendable {
    var identifier: String?
    var previewText: String
}

struct NativeEditorTransclusionReferenceBlock: Equatable, Hashable, Sendable {
    var sourcePageID: String?
    var transclusionID: String?
}

struct NativeEditorEmbedBlock: Equatable, Hashable, Sendable {
    var source: String?
    var provider: String?
    var alignment: String?
    var width: String?
    var height: String?
}

struct NativeEditorDiagramBlock: Equatable, Hashable, Sendable {
    var source: String?
    var title: String?
    var alternativeText: String?
    var attachmentID: String?
    var sizeInBytes: Int?
    var width: String?
    var height: String?
    var aspectRatio: String?
    var alignment: String?
}

struct NativeEditorMathBlock: Equatable, Hashable, Sendable {
    var text: String
}
