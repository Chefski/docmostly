import SwiftUI

struct AttachmentLinksView: View {
    let links: [DocmostAttachmentLink]
    let serverURLString: String
    var showsEmptyState = false

    var body: some View {
        Group {
            if links.isEmpty {
                if showsEmptyState {
                    ContentUnavailableView(
                        "No Attachments",
                        systemImage: "paperclip",
                        description: Text("Embedded files on this page will appear here.")
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                Text("Attachments")
                    .font(.headline)

                    ForEach(links) { link in
                        AttachmentLinkRow(link: link, serverURLString: serverURLString)
                    }
                }
            }
        }
    }
}

private struct AttachmentLinkRow: View {
    let link: DocmostAttachmentLink
    let serverURLString: String

    var body: some View {
        if let url = link.url(serverURLString: serverURLString) {
            DocmostlyGlassPanel(cornerRadius: 14, isInteractive: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: iconName)
                            .imageScale(.large)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(link.fileName)
                                .font(.subheadline)
                                .bold()
                                .lineLimit(2)

                            Text(metadataText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }

                    HStack {
                        Link(destination: url) {
                            Label("Open", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)

                        Link(destination: url) {
                            Label("Download", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(12)
            }
        }
    }

    private var iconName: String {
        guard let mimeType = link.mimeType else { return "doc" }
        if mimeType.hasPrefix("image/") { return "photo" }
        if mimeType.hasPrefix("video/") { return "play.rectangle" }
        if mimeType.hasPrefix("audio/") { return "waveform" }
        if mimeType == "application/pdf" { return "doc.richtext" }
        return "doc"
    }

    private var metadataText: String {
        [
            link.displayType,
            link.formattedFileSize,
            link.updatedAt.map { "Updated \($0.formatted(date: .abbreviated, time: .shortened))" }
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }
}
