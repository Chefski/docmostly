import Foundation

extension NativeRichEditorViewModel {
    func applyPageDetails(
        _ page: DocmostEditablePage,
        fallbackLastUpdatedBy: DocmostPagePerson? = nil
    ) {
        creator = page.creator
        lastUpdatedBy = page.lastUpdatedBy ?? fallbackLastUpdatedBy ?? lastUpdatedBy
        createdAt = page.createdAt ?? createdAt
        updatedAt = page.updatedAt ?? updatedAt
    }
}
