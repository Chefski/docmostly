import UniformTypeIdentifiers

nonisolated enum DocmostlyPageImportTypes {
    static let markdown = UTType(filenameExtension: "md") ?? .plainText
    static let markdownLong = UTType(filenameExtension: "markdown") ?? .plainText
    static let supported: [UTType] = [markdown, markdownLong, .html]
}
