import SwiftUI

struct NativeEditorCollaboratorSurface: View {
    let collaborators: [NativeEditorCollaborator]
    let reveal: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(collaborators) { collaborator in
                if let reveal {
                    Button {
                        reveal(collaborator.id)
                    } label: {
                        NativeEditorCollaboratorLabel(collaborator: collaborator)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jump to \(collaborator.name)'s caret")
                    .help("Jump to \(collaborator.name)")
                } else {
                    NativeEditorCollaboratorLabel(collaborator: collaborator)
                        .accessibilityLabel("\(collaborator.name) is editing")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct NativeEditorCollaboratorLabel: View {
    let collaborator: NativeEditorCollaborator

    var body: some View {
        HStack(spacing: 4) {
            Text(initials)
                .font(.caption2)
                .bold()
                .foregroundStyle(collaboratorForeground)
                .frame(width: 24, height: 24)
                .background(collaboratorColor, in: .circle)
                .overlay {
                    Circle()
                        .stroke(.primary.opacity(0.35), lineWidth: 1)
                }

            Text(collaborator.name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.trailing, 6)
        .contentShape(.capsule)
    }

    private var collaboratorColor: Color {
        Color(docmostlyHex: collaborator.colorName) ?? .secondary
    }

    private var collaboratorForeground: Color {
        var hex = collaborator.colorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let rawValue = Int(hex, radix: 16) else { return .primary }

        let red = Double((rawValue >> 16) & 0xff) / 255
        let green = Double((rawValue >> 8) & 0xff) / 255
        let blue = Double(rawValue & 0xff) / 255
        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        return luminance > 0.55 ? .black : .white
    }

    private var initials: String {
        let words = collaborator.name.split(whereSeparator: \.isWhitespace)
        let characters = words.prefix(2).compactMap(\.first)
        return characters.isEmpty ? "?" : String(characters).uppercased()
    }
}
