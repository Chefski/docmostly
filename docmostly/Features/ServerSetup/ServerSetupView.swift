import SwiftUI

struct ServerSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ServerSetupViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Docmost server") {
                    TextField("https://docs.example.com", text: $viewModel.serverURL)
                        .docmostlyTextInputAutocapitalization(.never)
                        .docmostlyKeyboardType(.url)
                        .docmostlyTextContentType(.url)
                        .autocorrectionDisabled()

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DocmostlyTheme.destructive)
                    }
                }

                Section {
                    Button("Validate Connection", systemImage: "checkmark.shield", action: validate)
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isValidating)
                }
            }
            .navigationTitle("Docmostly")
            .overlay {
                if viewModel.isValidating {
                    LoadingStateView(title: "Checking server")
                }
            }
        }
    }

    private func validate() {
        Task {
            await viewModel.validate(appState: appState)
        }
    }
}
