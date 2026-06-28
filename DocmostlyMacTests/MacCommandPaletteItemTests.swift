import Testing
@testable import DocmostlyMac

struct MacCommandPaletteItemTests {
    @Test func commandMatchingUsesLocalizedStandardContainmentAcrossTitleSubtitleAndKeywords() {
        let item = MacCommandPaletteItem(
            title: "New Page",
            subtitle: "Create in Engineering",
            systemImage: "doc.badge.plus",
            keywords: ["quick create"]
        ) {}

        #expect(item.matches("engineer"))
        #expect(item.matches("quick"))
        #expect(item.matches("missing") == false)
    }

    @Test func emptyPaletteQueryIncludesEveryCommand() {
        let item = MacCommandPaletteItem(
            title: "Search Workspace",
            subtitle: nil,
            systemImage: "magnifyingglass"
        ) {}

        #expect(item.matches("  "))
    }
}
