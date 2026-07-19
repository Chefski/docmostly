import SwiftUI

struct NativeEditorBylineView: View {
    let authorName: String

    var body: some View {
        DocmostlyGlassPanel(shape: .capsule) {
            Text("By \(authorName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
    }
}
