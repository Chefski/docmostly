# Docmostly

Docmostly is an open source Apple-platform app for [Docmost](https://docmost.com), built as a native companion for Docmost workspaces across iPhone, iPad, and Mac.

The goal is to make Docmost feel at home on iPhone, iPad, and macOS: fast browsing, reliable reading, search, recent pages, offline read-only access, settings, comments, attachments, and collaboration features designed with SwiftUI instead of a web wrapper.

Docmostly is an independent open source project and is not affiliated with, sponsored by, or endorsed by Docmost.

## Project Goals

- Provide polished native iOS, iPadOS, and macOS experiences for Docmost.
- Support workspace, space, and nested page browsing.
- Make search and recent documents quick to access.
- Keep cached content available for offline read-only use.
- Respect Docmost's document, comment, attachment, and collaboration model.
- Prioritize performance, reliability, and maintainable Swift code.

## Technology

Docmostly is built with:

- Swift
- SwiftUI
- SwiftData
- Modern Swift concurrency
- Native Apple-platform APIs

The iPhone and iPad app targets iOS 26.0 and iPadOS 26.0 or later. The Mac app targets macOS 26.0 or later.

## Status

Docmostly is under active development. The current focus is building a robust native foundation for authentication, workspace navigation, page reading, caching, search, comments, attachments, and collaboration across iPhone, iPad, and Mac.

## Getting Started

To work on Docmostly locally:

1. Clone the repository.
2. Open `docmostly.xcodeproj` in Xcode.
3. Select the `docmostly` scheme for iPhone or iPad, or the `DocmostlyMac` scheme for macOS.
4. Run the app on an iOS 26.0, iPadOS 26.0, or macOS 26.0 or later simulator, device, or Mac.
5. Connect the app to a Docmost workspace when prompted.

You will need a running Docmost instance or access to an existing Docmost workspace to use the app.

## Contributing

Contributions are welcome. Please keep changes focused, native to each supported Apple platform, and aligned with the existing SwiftUI architecture.

Before opening a pull request:

- Prefer correctness and reliability over shortcuts.
- Avoid adding third-party dependencies unless discussed first.
- Keep UI behavior consistent with Apple's Human Interface Guidelines.
- Add or update tests for core application logic when appropriate.

## License

Docmostly is available under the Apache License 2.0. See [LICENSE](LICENSE) for details.
