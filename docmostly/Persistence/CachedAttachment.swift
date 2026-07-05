import Foundation
import SwiftData

@Model
final class CachedAttachment {
    var cacheServerBaseURL: String = ""
    var cacheUserID: String = ""
    var id: String = ""
    var fileName: String = ""
    var path: String = ""
    var fileSize: Int?
    var fileExt: String?
    var mimeType: String?
    var createdAt: Date?
    var updatedAt: Date?
    var pageId: String = ""
    var cachedAt: Date = Date.now

    init(link: DocmostAttachmentLink, pageId: String, scope: CacheScope, cachedAt: Date = Date.now) {
        cacheServerBaseURL = scope.serverBaseURL
        cacheUserID = scope.userID
        id = link.id
        fileName = link.fileName
        path = link.path
        fileSize = link.fileSize
        fileExt = link.fileExt
        mimeType = link.mimeType
        createdAt = link.createdAt
        updatedAt = link.updatedAt
        self.pageId = pageId
        self.cachedAt = cachedAt
    }

    func update(link: DocmostAttachmentLink, cachedAt: Date = Date.now) {
        id = link.id
        fileName = link.fileName
        path = link.path
        fileSize = link.fileSize
        fileExt = link.fileExt
        mimeType = link.mimeType
        createdAt = link.createdAt
        updatedAt = link.updatedAt
        self.cachedAt = cachedAt
    }

    func matches(link: DocmostAttachmentLink) -> Bool {
        id == link.id &&
            fileName == link.fileName &&
            path == link.path &&
            fileSize == link.fileSize &&
            fileExt == link.fileExt &&
            mimeType == link.mimeType &&
            createdAt == link.createdAt &&
            updatedAt == link.updatedAt
    }

    func asLink() -> DocmostAttachmentLink {
        DocmostAttachmentLink(
            id: id,
            fileName: fileName,
            path: path,
            fileSize: fileSize,
            fileExt: fileExt,
            mimeType: mimeType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
