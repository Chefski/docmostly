import Testing
@testable import docmostly

struct SpaceSettingsDraftTests {
    @Test func computesSpaceSlugLikeDocmostWeb() {
        #expect(SpaceSettingsDraft.computedSlug(from: "Product Team") == "PT")
        #expect(SpaceSettingsDraft.computedSlug(from: "Design!") == "design")
        #expect(SpaceSettingsDraft.computedSlug(from: "R&D Docs") == "RD")
    }

    @Test func tracksManualSlugEdits() {
        var draft = SpaceSettingsDraft()

        draft.setName("Product Team")
        #expect(draft.slug == "PT")

        draft.setSlug("product")
        draft.setName("Product Operations")
        #expect(draft.slug == "product")
    }

    @Test func validatesNameSlugAndDescription() {
        var draft = SpaceSettingsDraft()
        draft.setName("A")
        draft.setSlug("bad-slug")

        #expect(draft.validationMessage == "Space name must be at least 2 characters.")

        draft.setName("Design")
        #expect(draft.validationMessage == "Space slug must be alphanumeric.")

        draft.setSlug("design")
        draft.description = String(repeating: "x", count: 501)
        #expect(draft.validationMessage == "Space description must be 500 characters or fewer.")
    }

    @Test func emitsOnlyChangedSpaceFields() {
        let space = space(
            name: "Design",
            description: "Old docs",
            slug: "design",
            disablePublicSharing: false,
            allowViewerComments: true
        )
        var draft = SpaceSettingsDraft(space: space)
        draft.description = "New docs"
        draft.disablePublicSharing = true

        let update = draft.updateValues(comparedTo: space)

        #expect(update.name == nil)
        #expect(update.description == "New docs")
        #expect(update.slug == nil)
        #expect(update.disablePublicSharing == true)
        #expect(update.allowViewerComments == nil)
    }

    private func space(
        name: String,
        description: String?,
        slug: String,
        disablePublicSharing: Bool,
        allowViewerComments: Bool
    ) -> DocmostSpace {
        DocmostSpace(
            id: "space-1",
            name: name,
            description: description,
            logo: nil,
            slug: slug,
            hostname: nil,
            creatorId: nil,
            createdAt: nil,
            updatedAt: nil,
            memberCount: nil,
            membership: nil,
            settings: DocmostSpaceSettings(
                sharing: DocmostSpaceSharingSettings(disabled: disablePublicSharing),
                comments: DocmostSpaceCommentsSettings(allowViewerComments: allowViewerComments)
            )
        )
    }
}
