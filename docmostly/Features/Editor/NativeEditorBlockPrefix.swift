import SwiftUI

struct NativeEditorBlockPrefix: View {
    @Binding var block: NativeEditorBlock

    var body: some View {
        Group {
            switch block.kind {
            case .bulletListItem:
                Text("•")
            case .orderedListItem(let ordinal):
                Text("\(ordinal.formatted()).")
                    .monospacedDigit()
            case .taskListItem(let isChecked):
                Button(
                    isChecked ? "Mark Incomplete" : "Mark Complete",
                    systemImage: isChecked ? "checkmark.circle.fill" : "circle"
                ) {
                    block.kind = .taskListItem(isChecked: isChecked == false)
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(isChecked ? DocmostlyTheme.primary : .secondary)
                .buttonStyle(.plain)
            case .unsupported:
                Image(systemName: "lock")
                    .accessibilityHidden(true)
            default:
                Text("")
            }
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .frame(width: 28, alignment: .center)
    }
}
