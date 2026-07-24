import Foundation
import Observation

@MainActor
@Observable
final class PageEmojiPickerViewModel {
    var searchText = "" {
        didSet {
            updateVisibleSections()
        }
    }
    private(set) var visibleSections: [EmojiCatalogSection]
    private(set) var isSaving = false
    var errorMessage: String?

    private let allSections: [EmojiCatalogSection]

    init(sections: [EmojiCatalogSection] = EmojiCatalog.sections) {
        allSections = sections
        visibleSections = sections
    }

    func beginSaving() -> Bool {
        guard isSaving == false else { return false }
        isSaving = true
        errorMessage = nil
        return true
    }

    func finishSaving(error: (any Error)? = nil) {
        isSaving = false
        errorMessage = error?.localizedDescription
    }

    private func updateVisibleSections() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            visibleSections = allSections
            return
        }

        visibleSections = allSections.compactMap { section in
            let items = if section.name.localizedStandardContains(query) {
                section.items
            } else {
                section.items.filter { item in
                    item.emoji == query || item.name.localizedStandardContains(query)
                }
            }
            return items.isEmpty ? nil : EmojiCatalogSection(name: section.name, items: items)
        }
    }
}
