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
}

nonisolated struct NativeEditorMediaBlock: Equatable, Hashable, Sendable {
    var source: String?
    var alternativeText: String?
    var attachmentID: String?
    var sizeInBytes: Int?
    var width: String?
    var height: String?
    var aspectRatio: String?
    var alignment: String?
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

nonisolated struct NativeEditorAttachmentBlock: Equatable, Hashable, Sendable {
    var url: String?
    var name: String?
    var mimeType: String?
    var sizeInBytes: Int?
    var attachmentID: String?
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

nonisolated struct NativeEditorMathBlock: Equatable, Hashable, Sendable {
    var text: String
}
