import SwiftUI

struct NativeEditorBlockSelectionBar: View {
    let delete: () -> Void

    var body: some View {
        HStack {
            Button("Delete Block", systemImage: "trash", role: .destructive, action: delete)
                .buttonStyle(.bordered)
                .controlSize(.small)

            Spacer()
        }
        .padding(.leading, 44)
    }
}
