import SwiftUI

struct DocmostEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let url: URL

    var body: some View {
        NavigationStack {
            DocmostEditorWebView(url: url, appState: appState)
                .navigationTitle("Edit Page")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done", action: dismiss.callAsFunction)
                    }
                }
        }
    }
}
