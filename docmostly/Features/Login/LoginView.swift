import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LoginViewModel()
    @State private var isEditingServer = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    LabeledContent("URL", value: appState.serverURLString)
                    Button("Change Server", systemImage: "server.rack", action: changeServer)
                }

                Section("Account") {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DocmostlyTheme.destructive)
                    }
                }

                Section {
                    Button("Log In", systemImage: "person.crop.circle.badge.checkmark", action: login)
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.canSubmit == false || viewModel.isLoggingIn)
                }
            }
            .navigationTitle("Docmostly")
            .overlay {
                if viewModel.isLoggingIn {
                    LoadingStateView(title: "Logging in")
                }
            }
        }
    }

    private func login() {
        Task {
            await viewModel.login(appState: appState)
        }
    }

    private func changeServer() {
        appState.phase = .needsServer
    }
}
