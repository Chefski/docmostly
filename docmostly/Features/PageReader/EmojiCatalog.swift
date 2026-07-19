import Foundation

nonisolated enum EmojiCatalog {
    static let sections: [EmojiCatalogSection] = loadSections()

    static func parse(_ source: String) -> [EmojiCatalogSection] {
        var sections: [EmojiCatalogSection] = []
        var currentName: String?
        var currentItems: [EmojiCatalogItem] = []

        func appendCurrentSection() {
            guard let currentName, currentItems.isEmpty == false else { return }
            sections.append(EmojiCatalogSection(name: currentName, items: currentItems))
        }

        for sourceLine in source.split(whereSeparator: \Character.isNewline) {
            let line = String(sourceLine)
            if line.hasPrefix("# group: ") {
                appendCurrentSection()
                currentName = String(line.dropFirst("# group: ".count))
                currentItems = []
                continue
            }

            let fields = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { continue }
            currentItems.append(EmojiCatalogItem(emoji: String(fields[0]), name: String(fields[1])))
        }

        appendCurrentSection()
        return sections
    }

    private static func loadSections() -> [EmojiCatalogSection] {
        let rootURL = Bundle.main.url(forResource: "emoji-16.0", withExtension: "txt")
        let resourcesURL = Bundle.main.url(
            forResource: "emoji-16.0",
            withExtension: "txt",
            subdirectory: "Resources"
        )
        guard let url = rootURL ?? resourcesURL,
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return parse(source)
    }
}
