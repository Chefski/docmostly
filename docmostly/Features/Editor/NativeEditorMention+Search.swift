import Foundation

extension NativeEditorMention {
    init(pageSearchResult result: DocmostSearchResult) {
        self.init(
            identifier: NativeEditorMentionNodeID.make(),
            label: result.title.isEmpty ? "Untitled" : result.title,
            entityType: "page",
            entityID: result.id,
            slugID: result.slugId,
            creatorID: result.creatorId
        )
    }

    init(pageSuggestion page: DocmostMentionPageSuggestion, creatorID: String?) {
        self.init(
            identifier: NativeEditorMentionNodeID.make(),
            label: page.title.isEmpty ? "Untitled" : page.title,
            entityType: "page",
            entityID: page.id,
            slugID: page.slugId,
            creatorID: creatorID
        )
    }

    init(
        createdPage page: DocmostPage,
        creatorID: String?,
        identifier: String = NativeEditorMentionNodeID.make()
    ) {
        self.init(
            identifier: identifier,
            label: page.title.isEmpty ? "Untitled" : page.title,
            entityType: "page",
            entityID: page.id,
            slugID: page.slugId,
            creatorID: creatorID
        )
    }

    init(userSuggestion user: DocmostMentionUserSuggestion, creatorID: String?) {
        self.init(
            identifier: NativeEditorMentionNodeID.make(),
            label: user.name,
            entityType: "user",
            entityID: user.id,
            creatorID: creatorID
        )
    }
}
