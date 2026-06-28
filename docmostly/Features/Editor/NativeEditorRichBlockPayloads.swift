import Foundation

nonisolated struct NativeEditorTable: Equatable, Hashable, Sendable {
    static let maximumRowCount = 200
    static let maximumColumnCount = 50

    var rows: [NativeEditorTableRow]

    var columnCount: Int {
        rows.map(\.cells.count).max() ?? 0
    }

    func columnWidth(at columnIndex: Int) -> Int? {
        for row in rows where row.cells.indices.contains(columnIndex) {
            if let width = row.cells[columnIndex].columnWidth {
                return width
            }
        }

        return nil
    }
}

nonisolated struct NativeEditorTableRow: Equatable, Hashable, Sendable {
    var cells: [NativeEditorTableCell]
}

nonisolated struct NativeEditorTableCell: Equatable, Hashable, Sendable {
    var plainText: String
    var isHeader: Bool
    var backgroundColorName: String?
    var columnWidth: Int?
    var columnSpan: Int = 1
    var rowSpan: Int = 1
    var columnWidths: [Int] = []
}

nonisolated struct NativeEditorMediaBlock: Equatable, Hashable, Sendable {
    var source: String?
    var alternativeText: String?
    var title: String?
    var attachmentID: String?
    var sizeInBytes: Int?
    var width: String?
    var height: String?
    var aspectRatio: String?
    var alignment: String?
}

nonisolated extension NativeEditorMediaBlock {
    static let placeholder = NativeEditorMediaBlock(
        source: nil,
        alternativeText: nil,
        title: nil,
        attachmentID: nil,
        sizeInBytes: nil,
        width: nil,
        height: nil,
        aspectRatio: nil,
        alignment: nil
    )
}

nonisolated struct NativeEditorMediaBlockUpdate: Equatable, Hashable, Sendable {
    var source: String
    var alternativeText: String
    var width: String
    var height: String
    var alignment: String
}

nonisolated struct NativeEditorPDFBlock: Equatable, Hashable, Sendable {
    var source: String?
    var name: String?
    var attachmentID: String?
    var sizeInBytes: Int?
    var width: String?
    var height: String?
}

nonisolated extension NativeEditorPDFBlock {
    static let placeholder = NativeEditorPDFBlock(
        source: nil,
        name: nil,
        attachmentID: nil,
        sizeInBytes: nil,
        width: nil,
        height: nil
    )
}

nonisolated struct NativeEditorAttachmentBlock: Equatable, Hashable, Sendable {
    var url: String?
    var name: String?
    var mimeType: String?
    var sizeInBytes: Int?
    var attachmentID: String?
}

nonisolated extension NativeEditorAttachmentBlock {
    static let placeholder = NativeEditorAttachmentBlock(
        url: nil,
        name: nil,
        mimeType: nil,
        sizeInBytes: nil,
        attachmentID: nil
    )
}

nonisolated struct NativeEditorCalloutBlock: Equatable, Hashable, Sendable {
    var style: String
    var icon: String?
    var previewText: String
}

nonisolated struct NativeEditorDetailsBlock: Equatable, Hashable, Sendable {
    var summary: String
    var previewText: String
    var isOpen: Bool
}

nonisolated struct NativeEditorColumnsBlock: Equatable, Hashable, Sendable {
    var layout: String
    var widthMode: String
    var columnCount: Int
    var previewText: String
    var columnTexts: [String] = []
}

nonisolated struct NativeEditorTransclusionSourceBlock: Equatable, Hashable, Sendable {
    var identifier: String?
    var previewText: String
}

nonisolated struct NativeEditorTransclusionReferenceBlock: Equatable, Hashable, Sendable {
    var sourcePageID: String?
    var transclusionID: String?
}

nonisolated struct NativeEditorBaseBlock: Equatable, Hashable, Sendable {
    var pageID: String?
    var pendingKey: String?
    var previewText: String
}

nonisolated struct NativeEditorEmbedBlock: Equatable, Hashable, Sendable {
    var source: String?
    var provider: String?
    var alignment: String?
    var width: String?
    var height: String?
}

nonisolated struct NativeEditorDiagramBlock: Equatable, Hashable, Sendable {
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

nonisolated extension NativeEditorDiagramBlock {
    static let placeholder = NativeEditorDiagramBlock(
        source: nil,
        title: nil,
        alternativeText: nil,
        attachmentID: nil,
        sizeInBytes: nil,
        width: nil,
        height: nil,
        aspectRatio: nil,
        alignment: nil
    )
}

nonisolated struct NativeEditorMathBlock: Equatable, Hashable, Sendable {
    var text: String
}
