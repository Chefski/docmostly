import SwiftUI

struct NativeEditorUnsupportedBlockView: View {
    let block: NativeEditorBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(block.kind.accessibilityLabel)
                .font(.headline)
            Text("This Docmost block is preserved when saving, but native editing for it is not available yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 8))
    }
}
