import SwiftUI

struct SpaceIconView: View {
    let space: DocmostSpace

    var body: some View {
        ZStack {
            DocmostlyTheme.primary.opacity(0.12)
                .clipShape(.rect(cornerRadius: 6))
            Text(initial)
                .font(.caption)
                .bold()
                .foregroundStyle(DocmostlyTheme.primary)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    private var initial: String {
        String(space.name.prefix(1)).uppercased()
    }
}
