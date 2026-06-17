import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    let retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Try Again", systemImage: "arrow.clockwise", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
