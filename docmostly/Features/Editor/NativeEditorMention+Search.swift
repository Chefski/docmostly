import Foundation

extension NativeEditorMention {
    init(pageSearchResult result: DocmostSearchResult) {
        self.init(
            identifier: result.id,
            label: result.title.isEmpty ? "Untitled" : result.title,
            entityType: "page",
            entityID: result.id,
            slugID: result.slugId,
            creatorID: result.creatorId
        )
    }
}
