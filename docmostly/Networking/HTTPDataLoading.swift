import Foundation

nonisolated protocol HTTPDataLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse)
}

nonisolated enum DocmostURLSessionFactory {
    static func makeAPIURLSession() -> any HTTPDataLoading {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return DocmostRedirectGuardedSession(configuration: configuration)
    }

    static func isRedirectAllowed(from originalURL: URL, to redirectURL: URL) -> Bool {
        guard
            let originalScheme = originalURL.scheme?.lowercased(),
            let redirectScheme = redirectURL.scheme?.lowercased(),
            let originalHost = originalURL.host?.lowercased(),
            let redirectHost = redirectURL.host?.lowercased()
        else {
            return false
        }

        return originalScheme == redirectScheme &&
            originalHost == redirectHost &&
            normalizedPort(for: originalURL) == normalizedPort(for: redirectURL)
    }

    private static func normalizedPort(for url: URL) -> Int? {
        if let port = url.port {
            return port
        }

        switch url.scheme?.lowercased() {
        case "https":
            return 443
        case "http":
            return 80
        default:
            return nil
        }
    }
}

extension URLSession: HTTPDataLoading {
    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        try await upload(for: request, fromFile: fileURL, delegate: nil)
    }
}

private final class DocmostRedirectGuardedSession:
    NSObject,
    HTTPDataLoading,
    URLSessionTaskDelegate,
    @unchecked Sendable {
    private let session: URLSession

    init(configuration: URLSessionConfiguration) {
        session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        super.init()
        session.configuration.httpCookieStorage = nil
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request, delegate: self)
    }

    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        try await session.upload(for: request, fromFile: fileURL, delegate: self)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard
            let originalURL = task.originalRequest?.url,
            let redirectURL = request.url,
            DocmostURLSessionFactory.isRedirectAllowed(from: originalURL, to: redirectURL)
        else {
            completionHandler(nil)
            return
        }

        completionHandler(request)
    }
}
