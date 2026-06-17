import SwiftUI

struct OfflineBadgeView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "wifi.slash")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: .capsule)
    }
}
