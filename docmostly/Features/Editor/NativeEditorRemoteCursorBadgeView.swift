import SwiftUI

struct NativeEditorRemoteCursorBadgeStack: View {
    let cursors: [NativeEditorResolvedRemoteCursor]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(cursors) { cursor in
                NativeEditorRemoteCursorBadge(cursor: cursor)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NativeEditorRemoteCursorBadge: View {
    let cursor: NativeEditorResolvedRemoteCursor

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(cursorColor)
                .frame(width: 2)
                .clipShape(.rect(cornerRadius: 1))
                .accessibilityHidden(true)

            Text(cursor.name)
                .font(.caption2)
                .bold()
                .foregroundStyle(cursorColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(cursorColor.opacity(0.12), in: .capsule)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cursorColor: Color {
        Color(docmostlyHex: cursor.colorName) ?? .secondary
    }

    private var accessibilityLabel: String {
        cursor.isCollapsed ? "\(cursor.name) cursor" : "\(cursor.name) selection"
    }
}
