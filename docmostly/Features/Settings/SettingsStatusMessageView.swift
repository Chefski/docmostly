import SwiftUI

struct SettingsStatusMessageView: View {
    let message: String
    let isError: Bool

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(isError ? DocmostlyTheme.destructive : .secondary)
    }
}
