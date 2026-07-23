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
        var visitedBundleURLs: Set<URL> = []
        let bundles = [Bundle(for: PageEmojiPickerViewModel.self), Bundle.main] +
            Bundle.allBundles + Bundle.allFrameworks

        for bundle in bundles where visitedBundleURLs.insert(bundle.bundleURL).inserted {
            let sections = loadSections(in: bundle)
            if sections.isEmpty == false {
                return sections
            }

            // Hosted unit tests live in App.app/PlugIns/Tests.xctest. The host app is
            // not guaranteed to appear in Bundle.allBundles, so also inspect the
            // enclosing app bundle that owns the copied production resource.
            if let appBundleURL = enclosingAppBundleURL(for: bundle.bundleURL),
               visitedBundleURLs.insert(appBundleURL).inserted,
               let appBundle = Bundle(url: appBundleURL) {
                let appSections = loadSections(in: appBundle)
                if appSections.isEmpty == false {
                    return appSections
                }
            }
        }

        return []
    }

    static func loadSections(in bundle: Bundle) -> [EmojiCatalogSection] {
        let candidates: [URL?] = [
            bundle.bundleURL.appending(path: "emoji-16.0.txt"),
            bundle.resourceURL?.appending(path: "emoji-16.0.txt"),
            bundle.url(forResource: "emoji-16.0", withExtension: "txt"),
            bundle.url(
                forResource: "emoji-16.0",
                withExtension: "txt",
                subdirectory: "Resources"
            )
        ]

        var visitedURLs: Set<URL> = []
        for url in candidates.compactMap({ $0 }) where visitedURLs.insert(url).inserted {
            if let source = try? String(contentsOf: url, encoding: .utf8) {
                return parse(source)
            }
        }
        return []
    }

    private static func enclosingAppBundleURL(for url: URL) -> URL? {
        var candidate = url
        while candidate.pathExtension != "app", candidate.pathComponents.count > 1 {
            candidate.deleteLastPathComponent()
        }
        return candidate.pathExtension == "app" ? candidate : nil
    }
}
