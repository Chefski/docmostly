import Foundation

nonisolated enum ContentFormat: String, Sendable {
    case json
    case markdown
    case html
}

nonisolated enum ContentOperation: String, Sendable {
    case append
    case prepend
    case replace
}

nonisolated enum Endpoint: Sendable {
    case workspacePublic
    case login(email: String, password: String)
    case logout
    case currentUser
    case spaces(query: String? = nil, cursor: String? = nil, limit: Int = 100)
    case spaceInfo(spaceId: String)
    case sidebarPages(spaceId: String? = nil, pageId: String? = nil, cursor: String? = nil, limit: Int = 100)
    case pageInfo(pageId: String, format: ContentFormat = .html)
    case recentPages(spaceId: String? = nil, cursor: String? = nil, limit: Int = 20)
    case search(query: String, spaceId: String? = nil, limit: Int = 20)
    case updatePage(
        pageId: String,
        title: String? = nil,
        content: ProseMirrorDocument? = nil,
        format: ContentFormat = .json,
        operation: ContentOperation = .replace
    )
    case comments(pageId: String, cursor: String? = nil, limit: Int = 100)
    case createPageComment(pageId: String, content: String)
    case attachmentInfo(attachmentId: String)

    func urlRequest(baseURL: URL) throws -> URLRequest {
        let url = baseURL
            .appending(path: AppConfig.apiPathPrefix)
            .appending(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = true
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try bodyData()
        if request.httpBody != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private var path: String {
        switch self {
        case .workspacePublic:
            "workspace/public"
        case .login:
            "auth/login"
        case .logout:
            "auth/logout"
        case .currentUser:
            "users/me"
        case .spaces:
            "spaces"
        case .spaceInfo:
            "spaces/info"
        case .sidebarPages:
            "pages/sidebar-pages"
        case .pageInfo:
            "pages/info"
        case .recentPages:
            "pages/recent"
        case .search:
            "search"
        case .updatePage:
            "pages/update"
        case .comments:
            "comments"
        case .createPageComment:
            "comments/create"
        case .attachmentInfo:
            "files/info"
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func bodyData() throws -> Data? {
        switch self {
        case .workspacePublic, .logout, .currentUser:
            return nil
        case .login(let email, let password):
            return try encode(LoginRequest(email: email, password: password))
        case .spaces(let query, let cursor, let limit):
            return try encode(PaginationRequest(query: query, cursor: cursor, limit: limit))
        case .spaceInfo(let spaceId):
            return try encode(SpaceInfoRequest(spaceId: spaceId))
        case .sidebarPages(let spaceId, let pageId, let cursor, let limit):
            return try encode(SidebarPagesRequest(spaceId: spaceId, pageId: pageId, cursor: cursor, limit: limit))
        case .pageInfo(let pageId, let format):
            return try encode(PageInfoRequest(pageId: pageId, format: format.rawValue))
        case .recentPages(let spaceId, let cursor, let limit):
            return try encode(RecentPagesRequest(spaceId: spaceId, cursor: cursor, limit: limit))
        case .search(let query, let spaceId, let limit):
            return try encode(SearchRequest(query: query, spaceId: spaceId, limit: limit))
        case .updatePage(let pageId, let title, let content, let format, let operation):
            let hasContent: Bool
            if case .some = content {
                hasContent = true
            } else {
                hasContent = false
            }
            return try encode(UpdatePageRequest(
                pageId: pageId,
                title: title,
                content: content,
                operation: hasContent ? operation.rawValue : nil,
                format: hasContent ? format.rawValue : nil
            ))
        case .comments(let pageId, let cursor, let limit):
            return try encode(CommentsRequest(pageId: pageId, cursor: cursor, limit: limit))
        case .createPageComment(let pageId, let content):
            return try encode(CreateCommentRequest(pageId: pageId, content: content, type: "page"))
        case .attachmentInfo(let attachmentId):
            return try encode(AttachmentInfoRequest(attachmentId: attachmentId))
        }
    }
    // swiftlint:enable cyclomatic_complexity

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(value)
    }
}

nonisolated private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

nonisolated private struct PaginationRequest: Encodable {
    let query: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct SpaceInfoRequest: Encodable {
    let spaceId: String
}

nonisolated private struct SidebarPagesRequest: Encodable {
    let spaceId: String?
    let pageId: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct PageInfoRequest: Encodable {
    let pageId: String
    let format: String
}

nonisolated private struct RecentPagesRequest: Encodable {
    let spaceId: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct SearchRequest: Encodable {
    let query: String
    let spaceId: String?
    let limit: Int
}

nonisolated private struct UpdatePageRequest: Encodable {
    let pageId: String
    let title: String?
    let content: ProseMirrorDocument?
    let operation: String?
    let format: String?
}

nonisolated private struct CommentsRequest: Encodable {
    let pageId: String
    let cursor: String?
    let limit: Int
}

nonisolated private struct CreateCommentRequest: Encodable {
    let pageId: String
    let content: String
    let type: String
}

nonisolated private struct AttachmentInfoRequest: Encodable {
    let attachmentId: String
}
