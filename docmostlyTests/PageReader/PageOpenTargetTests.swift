import Foundation
import Testing
@testable import docmostly

struct PageOpenTargetTests {
    @Test func pageTargetUsesPageSlugAndSpace() {
        let page = page(id: "page-1", slugId: "roadmap", spaceId: "space-1")

        let target = PageOpenTarget(page: page, revealSpaceInSidebar: true)

        #expect(target.id == "page-1")
        #expect(target.slugId == "roadmap")
        #expect(target.spaceId == "space-1")
        #expect(target.revealSpaceInSidebar)
    }

    @Test func browserItemTargetUsesItemRouteData() {
        let item = PageBrowserItem(
            page: page(id: "page-1", slugId: "roadmap", spaceId: "space-1"),
            fallbackSpaceName: "Product"
        )

        let target = PageOpenTarget(item: item)

        #expect(target.id == "page-1")
        #expect(target.slugId == "roadmap")
        #expect(target.spaceId == "space-1")
        #expect(target.revealSpaceInSidebar == false)
    }

    @Test func searchResultTargetUsesResultSpace() {
        let result = DocmostSearchResult(
            id: "result-1",
            title: "Roadmap",
            icon: nil,
            parentPageId: nil,
            slugId: "roadmap",
            creatorId: nil,
            createdAt: nil,
            updatedAt: nil,
            rank: nil,
            highlight: nil,
            space: SearchResultSpace(id: "space-1", name: "Product", slug: "product", icon: nil)
        )

        let target = PageOpenTarget(searchResult: result)

        #expect(target.id == "result-1")
        #expect(target.slugId == "roadmap")
        #expect(target.spaceId == "space-1")
    }

    @Test func pageFavoriteTargetUsesNestedPageWhenAvailable() {
        let favorite = DocmostFavorite(
            id: "favorite-1",
            userId: "user-1",
            pageId: "page-id-fallback",
            spaceId: nil,
            templateId: nil,
            type: .page,
            workspaceId: "workspace-1",
            createdAt: nil,
            page: DocmostFavoritePage(
                id: "page-1",
                slugId: "roadmap",
                title: "Roadmap",
                icon: nil,
                spaceId: "space-1"
            ),
            space: nil,
            template: nil
        )

        let target = PageOpenTarget(favorite: favorite)

        #expect(target?.id == "page-1")
        #expect(target?.slugId == "roadmap")
        #expect(target?.spaceId == "space-1")
    }

    @Test func nonPageFavoriteDoesNotCreatePageTarget() {
        let favorite = DocmostFavorite(
            id: "favorite-1",
            userId: "user-1",
            pageId: nil,
            spaceId: "space-1",
            templateId: nil,
            type: .space,
            workspaceId: "workspace-1",
            createdAt: nil,
            page: nil,
            space: DocmostFavoriteSpace(id: "space-1", name: "Product", slug: "product", logo: nil),
            template: nil
        )

        #expect(PageOpenTarget(favorite: favorite) == nil)
    }

    @Test func notificationTargetUsesNotificationSpaceContext() {
        let notification = DocmostNotification(
            id: "notification-1",
            userId: "user-1",
            workspaceId: "workspace-1",
            type: .pageUpdated,
            actorId: nil,
            pageId: "page-1",
            spaceId: "space-1",
            commentId: nil,
            data: nil,
            readAt: nil,
            emailedAt: nil,
            archivedAt: nil,
            createdAt: nil,
            actor: nil,
            page: DocmostNotificationPage(id: "page-1", title: "Roadmap", slugId: "roadmap", icon: nil),
            space: DocmostNotificationSpace(id: "space-1", name: "Product", slug: "product"),
            comment: nil
        )

        let target = PageOpenTarget(notification: notification)

        #expect(target?.id == "page-1")
        #expect(target?.slugId == "roadmap")
        #expect(target?.spaceId == "space-1")
    }

    @Test func notificationWithoutPageDoesNotCreatePageTarget() {
        let notification = DocmostNotification(
            id: "notification-1",
            userId: "user-1",
            workspaceId: "workspace-1",
            type: .pageUpdated,
            actorId: nil,
            pageId: nil,
            spaceId: "space-1",
            commentId: nil,
            data: nil,
            readAt: nil,
            emailedAt: nil,
            archivedAt: nil,
            createdAt: nil,
            actor: nil,
            page: nil,
            space: DocmostNotificationSpace(id: "space-1", name: "Product", slug: "product"),
            comment: nil
        )

        #expect(PageOpenTarget(notification: notification) == nil)
    }

    private func page(id: String, slugId: String, spaceId: String) -> DocmostPage {
        DocmostPage(
            id: id,
            slugId: slugId,
            title: "Roadmap",
            content: nil,
            icon: nil,
            coverPhoto: nil,
            parentPageId: nil,
            creatorId: nil,
            spaceId: spaceId,
            workspaceId: "workspace-1",
            isLocked: false,
            lastUpdatedById: nil,
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil,
            position: nil,
            hasChildren: false,
            permissions: nil,
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: DocmostPageSpace(id: spaceId, name: "Product", slug: "product", logo: nil)
        )
    }
}
