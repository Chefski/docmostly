import Foundation

extension NativeEditorMarkdownParser {
    private struct ReferenceDefinition {
        var destination: String
    }

    static func resolvingReferenceStyleLinks(in markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var definitions: [String: ReferenceDefinition] = [:]
        var contentLines: [String] = []
        var fence: (marker: Character, length: Int)?

        for line in lines {
            if let activeFence = fence {
                contentLines.append(line)
                if isReferenceFenceClosingLine(line, matching: activeFence) {
                    fence = nil
                }
                continue
            }

            if let openingFence = referenceFenceOpening(from: line) {
                fence = openingFence
                contentLines.append(line)
            } else if let definition = referenceDefinition(from: line) {
                if definitions[definition.label] == nil {
                    definitions[definition.label] = ReferenceDefinition(destination: definition.destination)
                }
                contentLines.append("")
            } else {
                contentLines.append(line)
            }
        }

        guard definitions.isEmpty == false else { return markdown }
        return resolvingReferenceLinks(in: contentLines, definitions: definitions)
    }

    private static func resolvingReferenceLinks(
        in contentLines: [String],
        definitions: [String: ReferenceDefinition]
    ) -> String {
        var resolvedFence: (marker: Character, length: Int)?
        return contentLines.map { line in
            if let activeFence = resolvedFence {
                if isReferenceFenceClosingLine(line, matching: activeFence) {
                    resolvedFence = nil
                }
                return line
            }
            if let openingFence = referenceFenceOpening(from: line) {
                resolvedFence = openingFence
                return line
            }
            if isReferenceIndentedCodeLine(line) {
                return line
            }
            return replacingReferenceStyleLinks(in: line, definitions: definitions)
        }
        .joined(separator: "\n")
    }

    private static func referenceDefinition(from line: String) -> (label: String, destination: String)? {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3 else { return nil }
        let trimmed = String(line.dropFirst(leadingSpaces))
        guard trimmed.first == "[",
              let closeLabel = closingReferenceBracket(in: trimmed, after: trimmed.startIndex) else {
            return nil
        }

        let colon = trimmed.index(after: closeLabel)
        guard colon < trimmed.endIndex, trimmed[colon] == ":" else { return nil }
        let labelStart = trimmed.index(after: trimmed.startIndex)
        let label = normalizedReferenceLabel(String(trimmed[labelStart..<closeLabel]))
        let destinationStart = trimmed.index(after: colon)
        let destination = trimmed[destinationStart...].trimmingCharacters(in: .whitespaces)
        guard label.isEmpty == false, validReferenceDestination(destination) else { return nil }
        return (label, destination)
    }

    private static func validReferenceDestination(_ destination: String) -> Bool {
        guard destination.isEmpty == false else { return false }
        if destination.first == "<" {
            return destination.contains(">")
        }
        return destination.first?.isWhitespace == false
    }

    private static func replacingReferenceStyleLinks(
        in line: String,
        definitions: [String: ReferenceDefinition]
    ) -> String {
        guard line.contains("[") else { return line }
        var output = ""
        var index = line.startIndex

        while index < line.endIndex {
            if line[index] == "`", let codeRange = markdownCodeSpanRange(in: line, startingAt: index) {
                output += line[codeRange]
                index = codeRange.upperBound
                continue
            }

            let isImage = line[index] == "!" && line.index(after: index) < line.endIndex &&
                line[line.index(after: index)] == "["
            let openLabel = isImage ? line.index(after: index) : index
            let lineSlice = line[...]
            let openingIsEscaped = isEscapedMarkdownCharacter(at: openLabel, in: lineSlice) ||
                (isImage && isEscapedMarkdownCharacter(at: index, in: lineSlice))
            if openingIsEscaped == false,
               line[openLabel] == "[",
               let match = referenceStyleLinkMatch(
                   in: line,
                   openingLabelAt: openLabel,
                   isImage: isImage,
                   definitions: definitions
               ) {
                output += match.replacement
                index = match.endIndex
                continue
            }

            output.append(line[index])
            index = line.index(after: index)
        }

        return output
    }

    private static func referenceStyleLinkMatch(
        in line: String,
        openingLabelAt openLabel: String.Index,
        isImage: Bool,
        definitions: [String: ReferenceDefinition]
    ) -> (replacement: String, endIndex: String.Index)? {
        guard let closeLabel = closingReferenceBracket(in: line, after: openLabel) else { return nil }
        let labelStart = line.index(after: openLabel)
        let visibleLabel = String(line[labelStart..<closeLabel])
        let afterLabel = line.index(after: closeLabel)
        if afterLabel < line.endIndex, line[afterLabel] == "(" {
            return nil
        }

        let referenceLabel: String
        let endIndex: String.Index
        if afterLabel < line.endIndex, line[afterLabel] == "[" {
            guard let closeReference = closingReferenceBracket(in: line, after: afterLabel) else { return nil }
            let referenceStart = line.index(after: afterLabel)
            let explicitLabel = String(line[referenceStart..<closeReference])
            referenceLabel = explicitLabel.isEmpty ? visibleLabel : explicitLabel
            endIndex = line.index(after: closeReference)
        } else {
            referenceLabel = visibleLabel
            endIndex = afterLabel
        }

        guard let definition = definitions[normalizedReferenceLabel(referenceLabel)] else { return nil }
        let marker = isImage ? "!" : ""
        return ("\(marker)[\(visibleLabel)](\(definition.destination))", endIndex)
    }

    private static func closingReferenceBracket(
        in text: String,
        after openBracket: String.Index
    ) -> String.Index? {
        var index = text.index(after: openBracket)
        var isEscaped = false
        while index < text.endIndex {
            let character = text[index]
            if character == "]", isEscaped == false {
                return index
            }
            if character == "\\" {
                isEscaped.toggle()
            } else {
                isEscaped = false
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func normalizedReferenceLabel(_ label: String) -> String {
        unescapedMarkdownPlainText(label)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func isReferenceIndentedCodeLine(_ line: String) -> Bool {
        let leadingSpaces = line.prefix { $0 == " " }.count
        let startsWithTab = line.first == "\t"
        guard leadingSpaces >= 4 || startsWithTab else { return false }
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        return isReferenceListItem(trimmedLine) == false
    }

    private static func isReferenceListItem(_ line: String) -> Bool {
        guard let kind = inputRule(from: line)?.kind else { return false }
        switch kind {
        case .bulletListItem, .orderedListItem, .taskListItem:
            true
        default:
            false
        }
    }

    private static func markdownCodeSpanRange(
        in text: String,
        startingAt openingStart: String.Index
    ) -> Range<String.Index>? {
        var openingEnd = openingStart
        while openingEnd < text.endIndex, text[openingEnd] == "`" {
            openingEnd = text.index(after: openingEnd)
        }
        let delimiter = String(text[openingStart..<openingEnd])
        guard let closingRange = text[openingEnd...].range(of: delimiter) else { return nil }
        return openingStart..<closingRange.upperBound
    }

    private static func referenceFenceOpening(from line: String) -> (marker: Character, length: Int)? {
        let line = line.trimmingCharacters(in: .whitespaces)
        guard let marker = line.first, marker == "`" || marker == "~" else { return nil }
        let length = line.prefix { $0 == marker }.count
        return length >= 3 ? (marker, length) : nil
    }

    private static func isReferenceFenceClosingLine(
        _ line: String,
        matching fence: (marker: Character, length: Int)
    ) -> Bool {
        let line = line.trimmingCharacters(in: .whitespaces)
        let markerCount = line.prefix { $0 == fence.marker }.count
        guard markerCount >= fence.length else { return false }
        return line.dropFirst(markerCount).allSatisfy(\.isWhitespace)
    }
}
