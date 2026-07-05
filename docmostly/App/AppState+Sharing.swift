import Foundation

extension AppState {
    func loadAttachmentDetails(
        pageId: String,
        fallbackLinks: [DocmostAttachmentLink]
    ) async -> [DocmostAttachmentLink] {
        guard fallbackLinks.isEmpty == false else { return [] }
        guard let apiClient else { return fallbackLinks }

        var enrichedLinks: [DocmostAttachmentLink] = []
        var didLoadMetadata = false
        for link in fallbackLinks {
            do {
                let attachment: DocmostAttachment = try await apiClient.send(.attachmentInfo(attachmentId: link.id))
                enrichedLinks.append(DocmostAttachmentLink(attachment: attachment))
                didLoadMetadata = true
            } catch {
                enrichedLinks.append(link)
            }
        }

        if didLoadMetadata {
            isOffline = false
        }
        if let cacheScope {
            scheduleCacheWrite(.saveAttachmentLinks(pageId: pageId, links: enrichedLinks, scope: cacheScope))
        }
        return enrichedLinks
    }

    func loadPageShare(pageId: String) async throws -> DocmostPageShare? {
        guard let apiClient else {
            throw APIError.connectionFailed("Public sharing requires a network connection.")
        }

        do {
            let share: DocmostPageShare? = try await apiClient.send(
                .shareForPage(pageId: pageId),
                as: DocmostPageShare?.self
            )
            isOffline = false
            return share
        } catch APIError.httpStatus(let status, _) where status == 404 {
            isOffline = false
            return nil
        } catch {
            throw error
        }
    }

    func createPageShare(pageId: String) async throws -> DocmostPageShare {
        guard let apiClient else {
            throw APIError.connectionFailed("Creating public shares requires a network connection.")
        }

        let share: DocmostPageShare = try await apiClient.send(.createShare(pageId: pageId))
        isOffline = false
        return share
    }

    func updatePageShare(
        shareId: String,
        includeSubPages: Bool? = nil,
        searchIndexing: Bool? = nil
    ) async throws -> DocmostPageShare {
        guard let apiClient else {
            throw APIError.connectionFailed("Updating public shares requires a network connection.")
        }

        let share: DocmostPageShare = try await apiClient.send(.updateShare(
            shareId: shareId,
            includeSubPages: includeSubPages,
            searchIndexing: searchIndexing
        ))
        isOffline = false
        return share
    }

    func deletePageShare(shareId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Deleting public shares requires a network connection.")
        }

        try await apiClient.sendVoid(.deleteShare(shareId: shareId))
        isOffline = false
    }

    func loadPageRestrictionInfo(pageId: String) async throws -> DocmostPageRestrictionInfo? {
        guard let apiClient else {
            throw APIError.connectionFailed("Page restrictions require a network connection.")
        }

        do {
            let info: DocmostPageRestrictionInfo = try await apiClient.send(.pageRestrictionInfo(pageId: pageId))
            isOffline = false
            return info
        } catch APIError.httpStatus(let status, _) where status == 404 {
            isOffline = false
            return nil
        }
    }

    func loadPagePermissionMembers(pageId: String) async throws -> [DocmostPagePermissionMember] {
        guard let apiClient else {
            throw APIError.connectionFailed("Page permissions require a network connection.")
        }

        let response: PaginatedResponse<DocmostPagePermissionMember> = try await apiClient.send(
            .pagePermissions(pageId: pageId)
        )
        isOffline = false
        return response.items
    }
}
