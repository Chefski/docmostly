import Testing
@testable import docmostly

struct EmojiCatalogTests {
    @Test func parsesGroupedEmojiCatalog() throws {
        let source = """
        # group: Smileys & Emotion
        😀\tgrinning face
        🥰\tsmiling face with hearts
        # group: Travel & Places
        🚀\trocket
        """

        let sections = EmojiCatalog.parse(source)

        #expect(sections.map(\.name) == ["Smileys & Emotion", "Travel & Places"])
        #expect(sections[0].items.map(\.emoji) == ["😀", "🥰"])
        #expect(sections[1].items.first?.name == "rocket")
    }

    @Test @MainActor func filtersEmojiByNameUsingLocalizedSearch() throws {
        let sections = [
            EmojiCatalogSection(
                name: "Smileys & Emotion",
                items: [EmojiCatalogItem(emoji: "😀", name: "grinning face")]
            ),
            EmojiCatalogSection(
                name: "Travel & Places",
                items: [EmojiCatalogItem(emoji: "🚀", name: "rocket")]
            )
        ]
        let viewModel = PageEmojiPickerViewModel(sections: sections)

        viewModel.searchText = "rocket"

        let section = try #require(viewModel.visibleSections.first)
        #expect(viewModel.visibleSections.count == 1)
        #expect(section.items.map(\.emoji) == ["🚀"])
    }

    @Test func bundledCatalogContainsUnicodeEmojiSet() {
        let itemCount = EmojiCatalog.sections.reduce(into: 0) { count, section in
            count += section.items.count
        }

        #expect(EmojiCatalog.sections.count == 9)
        #expect(itemCount == 3_781)
    }
}
