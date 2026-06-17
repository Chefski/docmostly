import Foundation
import SwiftData

@Model
final class CachedAttachment {
    var id: String = ""
    var fileName: String = ""
    var path: String = ""
    var pageId: String = ""
    var cachedAt: Date = Date.now

    init(link: DocmostAttachmentLink, pageId: String, cachedAt: Date = Date.now) {
        id = link.id
        fileName = link.fileName
        path = link.path
        self.pageId = pageId
        self.cachedAt = cachedAt
    }

    func asLink() -> DocmostAttachmentLink {
        DocmostAttachmentLink(id: id, fileName: fileName, path: path)
    }
}
