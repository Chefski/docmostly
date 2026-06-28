import SwiftUI

struct SpaceAddMemberCandidateRowView: View, Equatable {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                    if let subtitle, subtitle.isEmpty == false {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DocmostlyTheme.primary)
                }
            }
        }
    }

    static func == (lhs: SpaceAddMemberCandidateRowView, rhs: SpaceAddMemberCandidateRowView) -> Bool {
        lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle &&
            lhs.isSelected == rhs.isSelected
    }
}
