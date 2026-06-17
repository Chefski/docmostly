import Foundation
import SwiftUI

extension NativeRichEditorViewModel {
    var searchMatches: [NativeEditorSearchMatch] {
        NativeEditorSearch.findMatches(in: document.blocks, query: searchQuery)
    }

    var searchMatchSummary: String {
        let count = searchMatches.count
        guard count > 0 else { return "0" }
        return "\(min(currentSearchMatchIndex + 1, count)) of \(count)"
    }

    func selectNextSearchMatch() {
        selectSearchMatch(offset: 1)
    }

    func selectPreviousSearchMatch() {
        selectSearchMatch(offset: -1)
    }

    func replaceCurrentSearchMatch() {
        let matches = searchMatches
        guard matches.isEmpty == false else { return }
        let match = matches[min(currentSearchMatchIndex, matches.count - 1)]

        performUndoableEdit {
            replace(match: match, with: replacementText)
        }
    }

    func replaceAllSearchMatches() {
        let matches = searchMatches.reversed()
        guard matches.isEmpty == false else { return }

        performUndoableEdit {
            for match in matches {
                replace(match: match, with: replacementText)
            }
            currentSearchMatchIndex = 0
        }
    }

    private func selectSearchMatch(offset: Int) {
        let matches = searchMatches
        guard matches.isEmpty == false else { return }

        currentSearchMatchIndex = (currentSearchMatchIndex + offset + matches.count) % matches.count
        let match = matches[currentSearchMatchIndex]
        activeBlockID = match.blockID
        selectedBlockID = nil
        visibleBlockControlsID = nil
        isTitleFocused = false
        selectText(for: match)
    }

    private func replace(match: NativeEditorSearchMatch, with replacement: String) {
        guard document.blocks.indices.contains(match.blockIndex) else { return }

        let text = String(document.blocks[match.blockIndex].text.characters)
        let start = text.index(text.startIndex, offsetBy: match.lowerBound)
        let end = text.index(text.startIndex, offsetBy: match.upperBound)
        let updatedText = text.replacingCharacters(in: start..<end, with: replacement)
        document.blocks[match.blockIndex].text = AttributedString(updatedText)
    }

    private func selectText(for match: NativeEditorSearchMatch) {
        for index in document.blocks.indices where index != match.blockIndex {
            document.blocks[index].selection = AttributedTextSelection()
        }

        guard document.blocks.indices.contains(match.blockIndex) else { return }

        let text = document.blocks[match.blockIndex].text
        guard
            let start = text.characters.index(text.startIndex, offsetBy: match.lowerBound, limitedBy: text.endIndex),
            let end = text.characters.index(text.startIndex, offsetBy: match.upperBound, limitedBy: text.endIndex)
        else {
            document.blocks[match.blockIndex].selection = AttributedTextSelection()
            return
        }

        document.blocks[match.blockIndex].selection = AttributedTextSelection(range: start..<end)
    }
}

enum NativeEditorSearch {
    static func findMatches(in blocks: [NativeEditorBlock], query: String) -> [NativeEditorSearchMatch] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.isEmpty == false else { return [] }

        return blocks.enumerated().flatMap { index, block in
            matches(in: block, blockIndex: index, query: normalizedQuery)
        }
    }

    private static func matches(
        in block: NativeEditorBlock,
        blockIndex: Int,
        query: String
    ) -> [NativeEditorSearchMatch] {
        let text = String(block.text.characters)
        guard text.localizedStandardContains(query) else { return [] }

        var matches: [NativeEditorSearchMatch] = []
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            matches.append(match(block: block, blockIndex: blockIndex, text: text, range: range))
            searchRange = range.upperBound..<text.endIndex
        }

        return matches
    }

    private static func match(
        block: NativeEditorBlock,
        blockIndex: Int,
        text: String,
        range: Range<String.Index>
    ) -> NativeEditorSearchMatch {
        NativeEditorSearchMatch(
            blockID: block.id,
            blockIndex: blockIndex,
            lowerBound: text.distance(from: text.startIndex, to: range.lowerBound),
            upperBound: text.distance(from: text.startIndex, to: range.upperBound),
            preview: text
        )
    }
}
