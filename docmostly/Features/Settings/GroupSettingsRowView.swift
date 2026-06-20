import SwiftUI

struct GroupSettingsRowView: View {
    let group: DocmostGroup
    let canManage: Bool
    let delete: (DocmostGroup) -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.3")
                .foregroundStyle(DocmostlyTheme.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(group.name)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if canManage, group.isDefault != true {
                Menu("Group Actions", systemImage: "ellipsis.circle") {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(group)
                    }
                }
                .labelStyle(.iconOnly)
            }
        }
    }

    private var detail: String {
        let memberText = "\(group.memberCount ?? 0) members"
        guard let description = group.description, description.isEmpty == false else {
            return memberText
        }
        return "\(description) - \(memberText)"
    }
}
