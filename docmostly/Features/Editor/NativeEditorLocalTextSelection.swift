import Foundation
import SwiftUI

struct NativeEditorLocalTextSelection: Equatable, Sendable {
    let anchor: NativeEditorRemoteTextPosition
    let head: NativeEditorRemoteTextPosition

    var isCollapsed: Bool {
        anchor == head
    }

    init(anchor: NativeEditorRemoteTextPosition, head: NativeEditorRemoteTextPosition) {
        self.anchor = anchor
        self.head = head
    }

    init?(
        blockIndex: Int,
        selection: AttributedTextSelection,
        text: AttributedString
    ) {
        switch selection.indices(in: text) {
        case .ranges(let ranges):
            guard let range = ranges.ranges.first else { return nil }
            anchor = Self.position(blockIndex: blockIndex, index: range.lowerBound, text: text)
            head = Self.position(blockIndex: blockIndex, index: range.upperBound, text: text)
        case .insertionPoint(let index):
            let position = Self.position(blockIndex: blockIndex, index: index, text: text)
            anchor = position
            head = position
        }
    }

    private static func position(
        blockIndex: Int,
        index: AttributedString.Index,
        text: AttributedString
    ) -> NativeEditorRemoteTextPosition {
        let characterOffset = text.characters.distance(from: text.startIndex, to: index)
        let plainText = String(text.characters)
        let stringIndex = plainText.index(plainText.startIndex, offsetBy: characterOffset)
        let utf16Offset = plainText[..<stringIndex].utf16.count
        return NativeEditorRemoteTextPosition(blockIndex: blockIndex, characterOffset: utf16Offset)
    }
}
