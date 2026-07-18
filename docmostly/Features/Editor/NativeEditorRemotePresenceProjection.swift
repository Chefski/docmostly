import Foundation

nonisolated struct NativeEditorRemotePresenceScope: Equatable, Hashable, Sendable {
    let containerBlockIndex: Int
    let target: NativeEditorNestedContentTarget
}

nonisolated struct NativeEditorRemotePresenceRoute: Equatable, Hashable, Sendable {
    let scope: [NativeEditorRemotePresenceScope]
    let blockIndex: Int
}

nonisolated struct NativeEditorRemotePresenceSegment: Equatable, Identifiable, Sendable {
    let cursorID: String
    let collaboratorID: String
    let name: String
    let colorName: String
    let characterRange: Range<Int>
    let caretOffset: Int?

    var id: String {
        "\(cursorID):\(characterRange.lowerBound):\(characterRange.upperBound):\(caretOffset ?? -1)"
    }

    var accessibilityDescription: String {
        if characterRange.isEmpty {
            return "\(name) caret"
        }
        return "\(name) selection"
    }
}

nonisolated struct NativeEditorRemotePresenceProjection: Equatable, Sendable {
    fileprivate struct TextBlockRoute: Equatable, Sendable {
        let route: NativeEditorRemotePresenceRoute
        let characterCount: Int
    }

    private let segmentsByRoute: [NativeEditorRemotePresenceRoute: [NativeEditorRemotePresenceSegment]]
    private let revealRouteByCollaboratorID: [String: NativeEditorRemotePresenceRoute]

    init(document: NativeEditorDocument, cursors: [NativeEditorResolvedRemoteCursor]) {
        let routes = Self.textBlockRoutes(in: document)
        var nextSegments: [NativeEditorRemotePresenceRoute: [NativeEditorRemotePresenceSegment]] = [:]
        var nextRevealRoutes: [String: NativeEditorRemotePresenceRoute] = [:]

        for cursor in cursors {
            let orderedStart = min(cursor.anchor, cursor.head)
            let orderedEnd = max(cursor.anchor, cursor.head)

            guard orderedStart.blockIndex <= orderedEnd.blockIndex else { continue }

            for textBlockIndex in orderedStart.blockIndex...orderedEnd.blockIndex {
                guard let routedBlock = routes[textBlockIndex] else { continue }
                let lowerBound = textBlockIndex == orderedStart.blockIndex
                    ? min(max(orderedStart.characterOffset, 0), routedBlock.characterCount)
                    : 0
                let upperBound = textBlockIndex == orderedEnd.blockIndex
                    ? min(max(orderedEnd.characterOffset, 0), routedBlock.characterCount)
                    : routedBlock.characterCount
                let caretOffset = textBlockIndex == cursor.head.blockIndex
                    ? min(max(cursor.head.characterOffset, 0), routedBlock.characterCount)
                    : nil

                guard lowerBound < upperBound || caretOffset != nil else { continue }

                nextSegments[routedBlock.route, default: []].append(
                    NativeEditorRemotePresenceSegment(
                        cursorID: cursor.id,
                        collaboratorID: cursor.collaboratorID,
                        name: cursor.name,
                        colorName: cursor.colorName,
                        characterRange: lowerBound..<upperBound,
                        caretOffset: caretOffset
                    )
                )

                if caretOffset != nil {
                    nextRevealRoutes[cursor.collaboratorID] = routedBlock.route
                }
            }
        }

        segmentsByRoute = nextSegments.mapValues { segments in
            segments.sorted { lhs, rhs in
                if lhs.characterRange.lowerBound != rhs.characterRange.lowerBound {
                    return lhs.characterRange.lowerBound < rhs.characterRange.lowerBound
                }
                return lhs.cursorID < rhs.cursorID
            }
        }
        revealRouteByCollaboratorID = nextRevealRoutes
    }

    func segments(scope: [NativeEditorRemotePresenceScope], blockIndex: Int) -> [NativeEditorRemotePresenceSegment] {
        segmentsByRoute[NativeEditorRemotePresenceRoute(scope: scope, blockIndex: blockIndex)] ?? []
    }

    func rootBlockIndex(for collaboratorID: String) -> Int? {
        guard let route = revealRouteByCollaboratorID[collaboratorID] else { return nil }
        return route.scope.first?.containerBlockIndex ?? route.blockIndex
    }

    private static func textBlockRoutes(in document: NativeEditorDocument) -> [Int: TextBlockRoute] {
        var builder = RouteBuilder()
        builder.mapBody(
            nodes: document.proseMirrorDocument.content,
            scope: []
        )
        return builder.mappedRoutes
    }
}

nonisolated extension NativeEditorRemoteTextPosition: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.blockIndex != rhs.blockIndex {
            return lhs.blockIndex < rhs.blockIndex
        }
        return lhs.characterOffset < rhs.characterOffset
    }
}

nonisolated private extension NativeEditorRemotePresenceProjection {
    struct RouteBuilder {
        private var routes: [Int: TextBlockRoute] = [:]
        private var globalTextBlockIndex = 0

        fileprivate var mappedRoutes: [Int: TextBlockRoute] {
            routes
        }

        mutating func mapBody(
            nodes: [ProseMirrorNode],
            scope: [NativeEditorRemotePresenceScope]
        ) {
            var localBlockIndex = 0

            for node in nodes {
                let representedBlockCount = NativeEditorDocument.blocks(from: node).count
                mapTopLevelNode(node, localBlockIndex: localBlockIndex, scope: scope)
                localBlockIndex += representedBlockCount
            }
        }

        private mutating func mapTopLevelNode(
            _ node: ProseMirrorNode,
            localBlockIndex: Int,
            scope: [NativeEditorRemotePresenceScope]
        ) {
            switch node.type {
            case "paragraph", "heading", "codeBlock":
                mapTextBlock(node, route: NativeEditorRemotePresenceRoute(scope: scope, blockIndex: localBlockIndex))
            case "blockquote":
                mapFirstTextBlock(
                    in: node,
                    route: NativeEditorRemotePresenceRoute(scope: scope, blockIndex: localBlockIndex)
                )
            case "bulletList", "orderedList", "taskList":
                var nextListBlockIndex = localBlockIndex
                mapList(node, localBlockIndex: &nextListBlockIndex, scope: scope)
            case "callout":
                mapNestedBody(
                    node.content ?? [],
                    containerBlockIndex: localBlockIndex,
                    target: .callout,
                    scope: scope
                )
            case "details":
                if let detailsContent = node.content?.first(where: { $0.type == "detailsContent" }) {
                    mapNestedBody(
                        detailsContent.content ?? [],
                        containerBlockIndex: localBlockIndex,
                        target: .detailsContent,
                        scope: scope
                    )
                }
            case "columns":
                let columns = (node.content ?? []).filter { $0.type == "column" }
                for (columnIndex, column) in columns.enumerated() {
                    mapNestedBody(
                        column.content ?? [],
                        containerBlockIndex: localBlockIndex,
                        target: .column(index: columnIndex),
                        scope: scope
                    )
                }
            case "transclusionSource":
                mapNestedBody(
                    node.content ?? [],
                    containerBlockIndex: localBlockIndex,
                    target: .transclusionSource,
                    scope: scope
                )
            default:
                countUnmappedTextBlocks(in: node)
            }
        }

        private mutating func mapNestedBody(
            _ nodes: [ProseMirrorNode],
            containerBlockIndex: Int,
            target: NativeEditorNestedContentTarget,
            scope: [NativeEditorRemotePresenceScope]
        ) {
            mapBody(
                nodes: nodes,
                scope: scope + [NativeEditorRemotePresenceScope(
                    containerBlockIndex: containerBlockIndex,
                    target: target
                )]
            )
        }

        private mutating func mapList(
            _ list: ProseMirrorNode,
            localBlockIndex: inout Int,
            scope: [NativeEditorRemotePresenceScope]
        ) {
            for item in list.content ?? [] {
                var mappedPrimaryTextBlock = false

                for child in item.content ?? [] {
                    if child.isListContainer {
                        mapList(child, localBlockIndex: &localBlockIndex, scope: scope)
                    } else if mappedPrimaryTextBlock == false, Self.isTextBlock(child) {
                        mapTextBlock(
                            child,
                            route: NativeEditorRemotePresenceRoute(scope: scope, blockIndex: localBlockIndex)
                        )
                        localBlockIndex += 1
                        mappedPrimaryTextBlock = true
                    } else {
                        countUnmappedTextBlocks(in: child)
                    }
                }
            }
        }

        private mutating func mapFirstTextBlock(
            in node: ProseMirrorNode,
            route: NativeEditorRemotePresenceRoute
        ) {
            var mapped = false
            for textBlock in Self.textBlocks(in: node) {
                if mapped == false {
                    routes[globalTextBlockIndex] = TextBlockRoute(
                        route: route,
                        characterCount: textBlock.plainTextContent.utf16.count
                    )
                    mapped = true
                }
                globalTextBlockIndex += 1
            }
        }

        private mutating func mapTextBlock(
            _ node: ProseMirrorNode,
            route: NativeEditorRemotePresenceRoute
        ) {
            routes[globalTextBlockIndex] = TextBlockRoute(
                route: route,
                characterCount: node.plainTextContent.utf16.count
            )
            globalTextBlockIndex += 1
        }

        private mutating func countUnmappedTextBlocks(in node: ProseMirrorNode) {
            globalTextBlockIndex += Self.textBlocks(in: node).count
        }

        private static func textBlocks(in node: ProseMirrorNode) -> [ProseMirrorNode] {
            if Self.isTextBlock(node) {
                return [node]
            }

            return (node.content ?? []).flatMap(textBlocks(in:))
        }

        private static func isTextBlock(_ node: ProseMirrorNode) -> Bool {
            node.type == "paragraph" || node.type == "heading" || node.type == "codeBlock"
        }
    }
}

nonisolated private extension ProseMirrorNode {
    var plainTextContent: String {
        if type == "text" {
            return text ?? ""
        }
        if type == "hardBreak" {
            return "\n"
        }
        return (content ?? []).map(\.plainTextContent).joined()
    }
}
