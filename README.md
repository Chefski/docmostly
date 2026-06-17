# Docmostly

Docmostly is an open source iOS app for [Docmost](https://docmost.com), built as a native mobile companion for Docmost workspaces.

The goal is to make Docmost feel at home on iPhone and iPad: fast browsing, reliable reading, search, recent pages, offline read-only access, settings, comments, attachments, and collaboration features designed with SwiftUI instead of a web wrapper.

Docmostly is an independent open source project and is not affiliated with, sponsored by, or endorsed by Docmost.

## Project Goals

- Provide a polished native iOS experience for Docmost.
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
- Native iOS APIs

The app targets iOS 26.0 or later.

## Status

Docmostly is under active development. The current focus is building a robust native foundation for authentication, workspace navigation, page reading, caching, search, comments, attachments, and collaboration.

## Getting Started

To work on Docmostly locally:

1. Clone the repository.
2. Open `docmostly.xcodeproj` in Xcode.
3. Select the `docmostly` scheme.
4. Run the app on an iOS 26.0 or later simulator or device.
5. Connect the app to a Docmost workspace when prompted.

You will need a running Docmost instance or access to an existing Docmost workspace to use the app.

## Contributing

Contributions are welcome. Please keep changes focused, native to iOS, and aligned with the existing SwiftUI architecture.

Before opening a pull request:

- Prefer correctness and reliability over shortcuts.
- Avoid adding third-party dependencies unless discussed first.
- Keep UI behavior consistent with Apple's Human Interface Guidelines.
- Add or update tests for core application logic when appropriate.

## License

Docmostly is available under the Apache License 2.0. See [LICENSE](LICENSE) for details.
