import SwiftUI

struct NativeEditorBlockPrefix: View {
    @Binding var block: NativeEditorBlock

    var body: some View {
        Group {
            switch block.kind {
            case .bulletListItem:
                Text("•")
            case .orderedListItem(let ordinal):
                Text(ordinal.formatted())
            case .taskListItem(let isChecked):
                Button(
                    isChecked ? "Mark Incomplete" : "Mark Complete",
                    systemImage: isChecked ? "checkmark.circle.fill" : "circle"
                ) {
                    block.kind = .taskListItem(isChecked: isChecked == false)
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(isChecked ? DocmostlyTheme.primary : .secondary)
            case .blockquote:
                Image(systemName: "quote.opening")
                    .accessibilityHidden(true)
            case .codeBlock:
                Image(systemName: "curlybraces")
                    .accessibilityHidden(true)
            case .unsupported:
                Image(systemName: "lock")
                    .accessibilityHidden(true)
            default:
                Text("")
            }
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .padding(.top, 10)
    }
}
