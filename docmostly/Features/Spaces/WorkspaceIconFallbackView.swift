import SwiftUI

struct WorkspaceIconFallbackView: View {
    let initial: String

    var body: some View {
        ZStack {
            DocmostlyTheme.primary.opacity(0.12)
            Text(initial)
                .font(.caption)
                .bold()
                .foregroundStyle(DocmostlyTheme.primary)
        }
    }
}
