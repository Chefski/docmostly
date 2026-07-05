import SwiftUI

struct PageBrowserItemIcon: View {
    let icon: String?

    var body: some View {
        Group {
            if let icon, icon.isEmpty == false {
                Text(icon)
                    .font(.title3)
                    .lineLimit(1)
            } else {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: PageBrowserMetrics.iconWidth, height: PageBrowserMetrics.iconWidth)
        .accessibilityHidden(true)
    }
}
