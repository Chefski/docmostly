import SwiftUI

struct AttachmentLinksView: View {
    let links: [DocmostAttachmentLink]
    let serverURLString: String

    var body: some View {
        if links.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text("Attachments")
                    .font(.headline)

                ForEach(links) { link in
                    if let url = link.url(serverURLString: serverURLString) {
                        Link(destination: url) {
                            Label(link.fileName, systemImage: "paperclip")
                        }
                    }
                }
            }
        }
    }
}
