import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: LoginField?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)

                        Text("Sign in to Docmostly")
                            .font(.title.bold())

                        Text("Use your Docmost workspace account to continue.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                }

                Section("Workspace") {
                    if viewModel.canShowAccount {
                        LabeledContent {
                            VStack(alignment: .trailing) {
                                Text(LoginServerDisplay.title(for: viewModel.validatedWorkspaceURLString ?? ""))
                                    .lineLimit(1)

                                Text(LoginServerDisplay.subtitle(for: viewModel.validatedWorkspaceURLString ?? ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                            }
                        } label: {
                            Label("Server", systemImage: "server.rack")
                        }

                        if viewModel.savedServerURLStrings.isEmpty {
                            Button(
                                "Use a Different Server",
                                systemImage: "arrow.triangle.2.circlepath",
                                action: editWorkspace
                            )
                        } else {
                            Menu("Switch Server", systemImage: "arrow.triangle.2.circlepath") {
                                savedServerButtons()

                                Divider()

                                Button("Use a Different Server", systemImage: "plus", action: editWorkspace)
                            }
                        }
                    } else {
                        TextField("https://docs.example.com", text: $viewModel.workspaceURL)
                            .docmostlyTextInputAutocapitalization(.never)
                            .docmostlyKeyboardType(.url)
                            .docmostlyTextContentType(.url)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .workspace)
                            .submitLabel(.continue)
                            .disabled(viewModel.isValidatingWorkspace)
                            .onSubmit(validateWorkspace)
                            .onChange(of: viewModel.workspaceURL) {
                                viewModel.clearWorkspaceErrorAndInvalidateAccountIfNeeded()
                            }

                        if let workspaceErrorMessage = viewModel.workspaceErrorMessage {
                            Label(workspaceErrorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(DocmostlyTheme.destructive)
                                .accessibilityIdentifier("workspace-error-message")
                        }

                        Button(action: validateWorkspace) {
                            HStack {
                                if viewModel.isValidatingWorkspace {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.shield")
                                        .foregroundStyle(.white)
                                }

                                Text(viewModel.isValidatingWorkspace ? "Checking Workspace" : "Continue")
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.canValidateWorkspace == false || viewModel.isValidatingWorkspace)

                        if viewModel.savedServerURLStrings.isEmpty == false {
                            Menu("Saved Workspaces", systemImage: "server.rack") {
                                savedServerButtons()
                            }
                        }
                    }
                }

                if viewModel.canShowAccount {
                    Section {
                        TextField("Email", text: $viewModel.email)
                            .docmostlyTextContentType(.username)
                            .docmostlyTextInputAutocapitalization(.never)
                            .docmostlyKeyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .disabled(viewModel.isLoggingIn)
                            .onSubmit {
                                focusedField = .password
                            }
                            .onChange(of: viewModel.email) {
                                viewModel.clearError()
                            }

                        SecureField("Password", text: $viewModel.password)
                            .docmostlyTextContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .disabled(viewModel.isLoggingIn)
                            .onSubmit(login)
                            .onChange(of: viewModel.password) {
                                viewModel.clearError()
                            }

                        if let errorMessage = viewModel.errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(DocmostlyTheme.destructive)
                                .accessibilityIdentifier("login-error-message")
                        }
                    } header: {
                        Text("Account")
                    } footer: {
                        Text("Docmostly stores the authenticated session securely on this device.")
                    }

                    Section {
                        Button(action: login) {
                            if viewModel.isLoggingIn {
                                Label("Signing In", systemImage: "person.crop.circle.badge.checkmark")
                            } else {
                                Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                            }
                        }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(viewModel.canSubmit == false || viewModel.isLoggingIn)

                        if viewModel.isLoggingIn {
                            ProgressView("Signing in")
                        } else if let submitHint = viewModel.submitHint {
                            Text(submitHint)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Server", systemImage: "server.rack", action: editWorkspace)
                        .disabled(viewModel.isLoggingIn || viewModel.isValidatingWorkspace)
                }
            }
            .task {
                viewModel.sync(appState: appState)
            }
        }
    }

    @ViewBuilder
    private func savedServerButtons() -> some View {
        ForEach(viewModel.savedServerURLStrings, id: \.self) { serverURLString in
            Button {
                selectSavedServer(serverURLString)
            } label: {
                Label(LoginServerDisplay.title(for: serverURLString), systemImage: "server.rack")
            }
        }
    }

    private func validateWorkspace() {
        Task {
            await viewModel.validateWorkspace(appState: appState)
            if viewModel.canShowAccount {
                focusedField = .email
            }
        }
    }

    private func selectSavedServer(_ serverURLString: String) {
        Task {
            await viewModel.selectSavedServer(serverURLString, appState: appState)
            if viewModel.canShowAccount {
                focusedField = .email
            }
        }
    }

    private func login() {
        Task {
            await viewModel.login(appState: appState)
        }
    }

    private func editWorkspace() {
        viewModel.editWorkspace()
        focusedField = .workspace
    }
}

private enum LoginField: Hashable {
    case workspace
    case email
    case password
}
