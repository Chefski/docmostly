import SwiftUI

struct NotificationPaginationView: View {
    let isLoading: Bool
    let errorMessage: String?
    let loadNextPage: () -> Void

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading more")
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
                Button("Try Again", systemImage: "arrow.clockwise", action: loadNextPage)
            } else {
                ProgressView()
                    .accessibilityLabel("Loading more notifications")
                    .task {
                        loadNextPage()
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
