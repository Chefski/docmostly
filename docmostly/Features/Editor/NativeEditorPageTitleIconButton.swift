import SwiftUI

struct NativeEditorPageTitleIconButton: View {
    let icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(icon == nil ? "Add page emoji" : "Change page emoji")
            } icon: {
                if let icon, icon.isEmpty == false {
                    Text(icon)
                } else {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                }
            }
            .labelStyle(.iconOnly)
            .font(.largeTitle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == nil ? "Add page emoji" : "Change page emoji")
        .accessibilityHint("Opens the emoji picker")
    }
}
