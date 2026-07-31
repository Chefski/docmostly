import Foundation
import SwiftUI

nonisolated extension NativeEditorDocument {
    func reconcilingEditorState(from currentDocument: Self) -> Self {
        let matches = Self.crdtProjectionMatches(
            currentBlocks: currentDocument.blocks,
            projectedBlocks: blocks
        )
        let reconciledBlocks = blocks.enumerated().map { projectedIndex, projectedBlock in
            guard let currentIndex = matches[projectedIndex] else {
                return projectedBlock
            }

            return Self.reconciledProjectedBlock(
                projectedBlock,
                currentBlock: currentDocument.blocks[currentIndex]
            )
        }
        return Self(blocks: reconciledBlocks)
    }

    private static func crdtProjectionMatches(
        currentBlocks: [NativeEditorBlock],
        projectedBlocks: [NativeEditorBlock]
    ) -> [Int: Int] {
        var matches: [Int: Int] = [:]
        var matchedCurrentIndices: Set<Int> = []

        let currentIndicesByNodeID = Dictionary(
            grouping: currentBlocks.indices.compactMap { index in
                currentBlocks[index].crdtNodeID.map { ($0, index) }
            },
            by: { $0.0 }
        )
        for projectedIndex in projectedBlocks.indices {
            guard
                let nodeID = projectedBlocks[projectedIndex].crdtNodeID,
                let candidates = currentIndicesByNodeID[nodeID],
                let currentIndex = candidates.lazy.map(\.1).first(where: {
                    matchedCurrentIndices.contains($0) == false
                })
            else {
                continue
            }

            matches[projectedIndex] = currentIndex
            matchedCurrentIndices.insert(currentIndex)
        }

        let currentIndicesByNode = Dictionary(
            grouping: currentBlocks.indices.filter {
                matchedCurrentIndices.contains($0) == false
            },
            by: { currentBlocks[$0].crdtProjectionNode }
        )
        for projectedIndex in projectedBlocks.indices where matches[projectedIndex] == nil {
            let projectedNode = projectedBlocks[projectedIndex].crdtProjectionNode
            guard
                let candidates = currentIndicesByNode[projectedNode],
                let currentIndex = candidates.first(where: {
                    matchedCurrentIndices.contains($0) == false
                })
            else {
                continue
            }

            matches[projectedIndex] = currentIndex
            matchedCurrentIndices.insert(currentIndex)
        }

        let unmatchedProjectedIndices = projectedBlocks.indices.filter { matches[$0] == nil }
        let unmatchedCurrentIndices = currentBlocks.indices.filter {
            matchedCurrentIndices.contains($0) == false
        }
        guard unmatchedProjectedIndices.count == unmatchedCurrentIndices.count else {
            return matches
        }

        for (projectedIndex, currentIndex) in zip(unmatchedProjectedIndices, unmatchedCurrentIndices) {
            guard
                projectedBlocks[projectedIndex].crdtProjectionNode.type ==
                    currentBlocks[currentIndex].crdtProjectionNode.type
            else {
                continue
            }

            matches[projectedIndex] = currentIndex
        }
        return matches
    }

    private static func reconciledProjectedBlock(
        _ projectedBlock: NativeEditorBlock,
        currentBlock: NativeEditorBlock
    ) -> NativeEditorBlock {
        NativeEditorBlock(
            id: currentBlock.id,
            kind: projectedBlock.kind,
            text: projectedBlock.text,
            alignment: projectedBlock.alignment,
            indentLevel: projectedBlock.indentLevel,
            selection: projectedBlock.text.crdtSelection(
                preserving: currentBlock.selection,
                from: currentBlock.text
            ),
            inlineContent: projectedBlock.inlineContent,
            rawNode: projectedBlock.rawNode
        )
    }
}

nonisolated private extension NativeEditorBlock {
    var crdtProjectionNode: ProseMirrorNode {
        NativeEditorDocument.node(from: self)
    }

    var crdtNodeID: String? {
        crdtProjectionNode.firstCRDTNodeID
    }
}

nonisolated private extension ProseMirrorNode {
    var firstCRDTNodeID: String? {
        if let nodeID = attrs?["id"]?.stringValue {
            return nodeID
        }

        for child in content ?? [] {
            if let nodeID = child.firstCRDTNodeID {
                return nodeID
            }
        }
        return nil
    }
}

nonisolated private extension AttributedString {
    func crdtSelection(
        preserving selection: AttributedTextSelection,
        from previousText: AttributedString
    ) -> AttributedTextSelection {
        switch selection.indices(in: previousText) {
        case .insertionPoint(let index):
            let previousOffset = previousText.characters.distance(
                from: previousText.startIndex,
                to: index
            )
            let mappedOffset = crdtMappedOffset(previousOffset, from: previousText)
            let insertionPoint = characters.index(startIndex, offsetBy: mappedOffset)
            return AttributedTextSelection(insertionPoint: insertionPoint)
        case .ranges(let ranges):
            guard let range = ranges.ranges.first else {
                return AttributedTextSelection()
            }

            let previousLowerBound = previousText.characters.distance(
                from: previousText.startIndex,
                to: range.lowerBound
            )
            let previousUpperBound = previousText.characters.distance(
                from: previousText.startIndex,
                to: range.upperBound
            )
            let lowerBound = crdtMappedOffset(previousLowerBound, from: previousText)
            let upperBound = crdtMappedOffset(previousUpperBound, from: previousText)
            let requestedRange = min(lowerBound, upperBound)..<max(lowerBound, upperBound)
            let safeRange = NativeEditorAtomicTextRange.selectionRange(for: requestedRange, in: self)
            let start = characters.index(startIndex, offsetBy: safeRange.lowerBound)
            let end = characters.index(startIndex, offsetBy: safeRange.upperBound)
            if start == end {
                return AttributedTextSelection(insertionPoint: start)
            }
            return AttributedTextSelection(range: start..<end)
        }
    }

    func crdtMappedOffset(_ requestedOffset: Int, from previousText: AttributedString) -> Int {
        let previousCharacters = Array(previousText.characters)
        let projectedCharacters = Array(characters)
        let clampedOffset = min(max(requestedOffset, 0), previousCharacters.count)

        var commonPrefixCount = 0
        while
            commonPrefixCount < previousCharacters.count,
            commonPrefixCount < projectedCharacters.count,
            previousCharacters[commonPrefixCount] == projectedCharacters[commonPrefixCount] {
            commonPrefixCount += 1
        }

        var commonSuffixCount = 0
        while
            commonSuffixCount < previousCharacters.count - commonPrefixCount,
            commonSuffixCount < projectedCharacters.count - commonPrefixCount,
            previousCharacters[previousCharacters.count - commonSuffixCount - 1] ==
                projectedCharacters[projectedCharacters.count - commonSuffixCount - 1] {
            commonSuffixCount += 1
        }

        let previousChangeEnd = previousCharacters.count - commonSuffixCount
        let projectedChangeEnd = projectedCharacters.count - commonSuffixCount
        let mappedOffset: Int
        if clampedOffset <= commonPrefixCount {
            mappedOffset = clampedOffset
        } else if clampedOffset >= previousChangeEnd {
            mappedOffset = clampedOffset + projectedChangeEnd - previousChangeEnd
        } else {
            mappedOffset = commonPrefixCount + min(
                clampedOffset - commonPrefixCount,
                projectedChangeEnd - commonPrefixCount
            )
        }
        return min(max(mappedOffset, 0), projectedCharacters.count)
    }
}
