import SwiftUI

struct PageReaderPageActionsMenu: View {
    let pageShareURL: URL?
    let activePanel: PageReaderPanel?
    @Binding var usesFullWidth: Bool
    let isFavoritePage: Bool
    let isTogglingFavorite: Bool
    let isWatchingPage: Bool?
    let isTogglingWatch: Bool
    let canEdit: Bool
    let canMoveToSpace: Bool
    let canImport: Bool
    let showDetails: () -> Void
    let showComments: () -> Void
    let showTableOfContents: () -> Void
    let showAttachments: () -> Void
    let showSharing: () -> Void
    let showPageHistory: () -> Void
    let showPageExport: () -> Void
    let showPageImport: () -> Void
    let copyPageLink: () -> Void
    let copyPageMarkdown: () -> Void
    let toggleFavorite: () -> Void
    let toggleWatch: () -> Void
    let showLabelEditor: () -> Void
    let showMoveToSpace: () -> Void
    let duplicateCurrentPage: () -> Void
    let confirmTrash: () -> Void
    let openCurrentPageInNewWindow: (() -> Void)?

    var body: some View {
        Menu("Page Actions", systemImage: "ellipsis.circle") {
            Section("Panels") {
                Button(detailsTitle, systemImage: "info.circle", action: showDetails)
                Button(commentsTitle, systemImage: "text.bubble", action: showComments)
                Button(tableOfContentsTitle, systemImage: "list.bullet", action: showTableOfContents)
                Button(attachmentsTitle, systemImage: "paperclip", action: showAttachments)
                Button(sharingTitle, systemImage: "person.2.badge.gearshape", action: showSharing)
            }

            Section("Share") {
                if let pageShareURL {
                    ShareLink(item: pageShareURL) {
                        Label("Share Page", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button("Share Page", systemImage: "square.and.arrow.up") {}
                        .disabled(true)
                }

                Button("Copy Link", systemImage: "link", action: copyPageLink)
                Button("Copy as Markdown", systemImage: "doc.plaintext", action: copyPageMarkdown)
            }

            Section("View") {
                Toggle(isOn: $usesFullWidth) {
                    Label("Full Width", systemImage: "arrow.left.and.right")
                }

                Button("Page History", systemImage: "clock.arrow.circlepath", action: showPageHistory)

                if let openCurrentPageInNewWindow {
                    Button("Open in New Window", systemImage: "macwindow", action: openCurrentPageInNewWindow)
                }
            }

            Section("Transfer") {
                Button("Export", systemImage: "square.and.arrow.down", action: showPageExport)
                Button("Import", systemImage: "square.and.arrow.up", action: showPageImport)
                    .disabled(canImport == false)
            }

            Section("Following") {
                Button(favoriteTitle, systemImage: favoriteSystemImage, action: toggleFavorite)
                    .disabled(isTogglingFavorite)

                Button(watchTitle, systemImage: watchSystemImage, action: toggleWatch)
                    .disabled(isTogglingWatch)
            }

            Section("Page") {
                if canEdit {
                    Button("Edit Labels", systemImage: "tag", action: showLabelEditor)
                }

                if canMoveToSpace {
                    Button("Move", systemImage: "arrow.right", action: showMoveToSpace)
                }

                if canEdit {
                    Button("Duplicate", systemImage: "doc.on.doc", action: duplicateCurrentPage)
                    Button("Move to Trash", systemImage: "trash", role: .destructive, action: confirmTrash)
                }
            }
        }
        .accessibilityLabel("Page Actions")
    }

    private var detailsTitle: String {
        activePanel == .details ? "Hide Details" : "Show Details"
    }

    private var commentsTitle: String {
        activePanel == .comments ? "Hide Comments" : "Show Comments"
    }

    private var tableOfContentsTitle: String {
        activePanel == .tableOfContents ? "Hide Table of Contents" : "Show Table of Contents"
    }

    private var attachmentsTitle: String {
        activePanel == .attachments ? "Hide Attachments" : "Show Attachments"
    }

    private var sharingTitle: String {
        activePanel == .sharing ? "Hide Sharing" : "Show Sharing"
    }

    private var favoriteTitle: String {
        isFavoritePage ? "Remove from Favorites" : "Add to Favorites"
    }

    private var favoriteSystemImage: String {
        isFavoritePage ? "star.fill" : "star"
    }

    private var watchTitle: String {
        isWatchingPage == true ? "Stop Watching" : "Watch Page"
    }

    private var watchSystemImage: String {
        isWatchingPage == true ? "eye.slash" : "eye"
    }
}
