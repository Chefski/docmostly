import Foundation

nonisolated struct DocmostAttachmentLink: Identifiable, Hashable, Sendable {
    let id: String
    let fileName: String
    let path: String
    let fileSize: Int?
    let fileExt: String?
    let mimeType: String?
    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: String,
        fileName: String,
        path: String,
        fileSize: Int? = nil,
        fileExt: String? = nil,
        mimeType: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.path = path
        self.fileSize = fileSize
        self.fileExt = fileExt
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(attachment: DocmostAttachment) {
        self.init(
            id: attachment.id,
            fileName: attachment.fileName,
            path: Self.path(id: attachment.id, fileName: attachment.fileName),
            fileSize: attachment.fileSize,
            fileExt: attachment.fileExt,
            mimeType: attachment.mimeType,
            createdAt: attachment.createdAt,
            updatedAt: attachment.updatedAt
        )
    }

    func url(serverURLString: String) -> URL? {
        guard let baseURL = URL(string: serverURLString) else { return nil }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    var displayType: String {
        if let mimeType, mimeType.isEmpty == false {
            return mimeType
        }

        if let fileExt, fileExt.isEmpty == false {
            return fileExt.hasPrefix(".") ? fileExt : ".\(fileExt)"
        }

        return "File"
    }

    var formattedFileSize: String? {
        guard let fileSize else { return nil }
        return ByteCountFormatStyle(style: .file).format(Int64(fileSize))
    }

    static func path(id: String, fileName: String) -> String {
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: docmostFilePathComponentAllowed())
            ?? fileName
        return "/api/files/\(id)/\(encodedFileName)"
    }

    private static nonisolated func docmostFilePathComponentAllowed() -> CharacterSet {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/\\?#")
        return allowed
    }
}
