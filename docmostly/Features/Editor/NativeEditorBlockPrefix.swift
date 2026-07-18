import SwiftUI

struct NativeEditorBlockPrefix: View {
    @Binding var block: NativeEditorBlock
    var allowsTaskToggle = true

    var body: some View {
        Group {
            switch block.kind {
            case .bulletListItem:
                Text("•")
            case .orderedListItem(let ordinal):
                Text("\(ordinal.formatted()).")
                    .monospacedDigit()
            case .taskListItem(let isChecked):
                taskListPrefix(isChecked: isChecked)
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

    @ViewBuilder
    private func taskListPrefix(isChecked: Bool) -> some View {
        let title = isChecked ? "Mark Incomplete" : "Mark Complete"
        let systemImage = isChecked ? "checkmark.circle.fill" : "circle"

        if allowsTaskToggle {
            Button(title, systemImage: systemImage) {
                block.kind = .taskListItem(isChecked: isChecked == false)
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(isChecked ? DocmostlyTheme.primary : .secondary)
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(.interaction, .rect)
        } else {
            Image(systemName: systemImage)
                .foregroundStyle(isChecked ? DocmostlyTheme.primary : .secondary)
                .accessibilityLabel(isChecked ? "Complete task" : "Incomplete task")
        }
    }
}
