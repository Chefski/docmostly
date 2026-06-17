import SwiftUI

struct NativeEditorSaveErrorView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(DocmostlyTheme.destructive)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DocmostlyTheme.destructive.opacity(0.08), in: .rect(cornerRadius: 8))
    }
}
