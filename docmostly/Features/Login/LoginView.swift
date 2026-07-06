import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: LoginField?

    var body: some View {
        NavigationStack {
            loginContent
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
    private var loginContent: some View {
        #if os(macOS)
        MacLoginView(
            viewModel: viewModel,
            focusedField: $focusedField,
            validateWorkspace: validateWorkspace,
            selectSavedServer: selectSavedServer,
            login: login,
            editWorkspace: editWorkspace
        )
        #else
        mobileLoginForm
        #endif
    }

    private var mobileLoginForm: some View {
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

#if os(macOS)
private struct MacLoginView: View {
    @Bindable var viewModel: LoginViewModel
    var focusedField: FocusState<LoginField?>.Binding
    let validateWorkspace: () -> Void
    let selectSavedServer: (String) -> Void
    let login: () -> Void
    let editWorkspace: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()

            HStack(spacing: 56) {
                MacLoginIntroPanel()

                MacLoginCard(
                    viewModel: viewModel,
                    focusedField: focusedField,
                    validateWorkspace: validateWorkspace,
                    selectSavedServer: selectSavedServer,
                    login: login,
                    editWorkspace: editWorkspace
                )
            }
            .frame(maxWidth: 960)
            .padding(.horizontal, 48)
            .padding(.vertical, 44)
        }
    }
}

private struct MacLoginIntroPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 42))
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Docmostly")
                        .font(.largeTitle.bold())

                    Text("A native workspace for reading, editing, and organizing Docmost pages on your Mac.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                MacLoginFeatureRow(systemImage: "server.rack", title: "Connect your workspace")
                MacLoginFeatureRow(systemImage: "lock.shield", title: "Keep your session in Keychain")
                MacLoginFeatureRow(systemImage: "sidebar.leading", title: "Open into a desktop-native sidebar")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 360, maxHeight: 440, alignment: .leading)
    }
}

private struct MacLoginFeatureRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}

private struct MacLoginCard: View {
    @Bindable var viewModel: LoginViewModel
    var focusedField: FocusState<LoginField?>.Binding
    let validateWorkspace: () -> Void
    let selectSavedServer: (String) -> Void
    let login: () -> Void
    let editWorkspace: () -> Void

    var body: some View {
        GlassEffectContainer {
            DocmostlyGlassPanel(cornerRadius: 28, isInteractive: true) {
                VStack(alignment: .leading, spacing: 24) {
                    MacLoginCardHeader()

                    MacLoginWorkspaceSection(
                        viewModel: viewModel,
                        focusedField: focusedField,
                        validateWorkspace: validateWorkspace,
                        selectSavedServer: selectSavedServer,
                        editWorkspace: editWorkspace
                    )

                    if viewModel.canShowAccount {
                        Divider()

                        MacLoginAccountSection(
                            viewModel: viewModel,
                            focusedField: focusedField,
                            login: login
                        )
                    }
                }
                .padding(28)
                .frame(width: 430, alignment: .leading)
            }
        }
    }
}

private struct MacLoginCardHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sign in")
                .font(.title.bold())

            Text("Use your Docmost workspace account to continue.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct MacLoginWorkspaceSection: View {
    @Bindable var viewModel: LoginViewModel
    var focusedField: FocusState<LoginField?>.Binding
    let validateWorkspace: () -> Void
    let selectSavedServer: (String) -> Void
    let editWorkspace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workspace", systemImage: "server.rack")
                .font(.headline)

            if viewModel.canShowAccount {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(LoginServerDisplay.title(for: viewModel.validatedWorkspaceURLString ?? ""))
                                .lineLimit(1)

                            Text(LoginServerDisplay.subtitle(for: viewModel.validatedWorkspaceURLString ?? ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    } label: {
                        Label("Server", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    HStack {
                        if viewModel.savedServerURLStrings.isEmpty {
                            Button(
                                "Use a Different Server",
                                systemImage: "arrow.triangle.2.circlepath",
                                action: editWorkspace
                            )
                        } else {
                            Menu("Switch Server", systemImage: "arrow.triangle.2.circlepath") {
                                MacSavedServerButtons(
                                    savedServerURLStrings: viewModel.savedServerURLStrings,
                                    selectSavedServer: selectSavedServer
                                )

                                Divider()

                                Button("Use a Different Server", systemImage: "plus", action: editWorkspace)
                            }
                        }

                        Spacer()
                    }
                    .controlSize(.small)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("https://docs.example.com", text: $viewModel.workspaceURL)
                        .docmostlyTextInputAutocapitalization(.never)
                        .docmostlyKeyboardType(.url)
                        .docmostlyTextContentType(.url)
                        .autocorrectionDisabled()
                        .focused(focusedField, equals: .workspace)
                        .submitLabel(.continue)
                        .disabled(viewModel.isValidatingWorkspace)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
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

                    HStack {
                        Button(action: validateWorkspace) {
                            if viewModel.isValidatingWorkspace {
                                Label("Checking Workspace", systemImage: "checkmark.shield")
                            } else {
                                Label("Continue", systemImage: "checkmark.shield")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .disabled(viewModel.canValidateWorkspace == false || viewModel.isValidatingWorkspace)

                        if viewModel.savedServerURLStrings.isEmpty == false {
                            Menu("Saved Workspaces", systemImage: "clock.arrow.circlepath") {
                                MacSavedServerButtons(
                                    savedServerURLStrings: viewModel.savedServerURLStrings,
                                    selectSavedServer: selectSavedServer
                                )
                            }
                            .controlSize(.large)
                        }
                    }
                }
            }
        }
    }
}

private struct MacLoginAccountSection: View {
    @Bindable var viewModel: LoginViewModel
    var focusedField: FocusState<LoginField?>.Binding
    let login: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Account", systemImage: "person.crop.circle")
                .font(.headline)

            TextField("Email", text: $viewModel.email)
                .docmostlyTextContentType(.username)
                .docmostlyTextInputAutocapitalization(.never)
                .docmostlyKeyboardType(.emailAddress)
                .autocorrectionDisabled()
                .focused(focusedField, equals: .email)
                .submitLabel(.next)
                .disabled(viewModel.isLoggingIn)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .onSubmit {
                    focusedField.wrappedValue = .password
                }
                .onChange(of: viewModel.email) {
                    viewModel.clearError()
                }

            SecureField("Password", text: $viewModel.password)
                .docmostlyTextContentType(.password)
                .focused(focusedField, equals: .password)
                .submitLabel(.go)
                .disabled(viewModel.isLoggingIn)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
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

            Button(action: login) {
                if viewModel.isLoggingIn {
                    Label("Signing In", systemImage: "person.crop.circle.badge.checkmark")
                } else {
                    Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(viewModel.canSubmit == false || viewModel.isLoggingIn)

            if viewModel.isLoggingIn {
                ProgressView("Signing in")
            } else if let submitHint = viewModel.submitHint {
                Text(submitHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Docmostly stores the authenticated session securely on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MacSavedServerButtons: View {
    let savedServerURLStrings: [String]
    let selectSavedServer: (String) -> Void

    var body: some View {
        ForEach(savedServerURLStrings, id: \.self) { serverURLString in
            Button {
                selectSavedServer(serverURLString)
            } label: {
                Label(LoginServerDisplay.title(for: serverURLString), systemImage: "server.rack")
            }
        }
    }
}
#endif

private enum LoginField: Hashable {
    case workspace
    case email
    case password
}
