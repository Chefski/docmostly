import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var workspaceURL = ""
    var validatedWorkspaceURLString: String?
    var savedServerURLStrings: [String] = []
    var isValidatingWorkspace = false
    var workspaceErrorMessage: String?
    var email = ""
    var password = ""
    var isLoggingIn = false
    var errorMessage: String?

    var trimmedWorkspaceURL: String {
        workspaceURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canValidateWorkspace: Bool {
        trimmedWorkspaceURL.isEmpty == false
    }

    var canShowAccount: Bool {
        validatedWorkspaceURLString?.isEmpty == false
    }

    var canSubmit: Bool {
        canShowAccount && trimmedEmail.isEmpty == false && password.isEmpty == false
    }

    var workspaceSubmitHint: String? {
        trimmedWorkspaceURL.isEmpty ? "Enter your workspace URL." : nil
    }

    var submitHint: String? {
        if trimmedEmail.isEmpty {
            return "Enter your email address."
        }

        if password.isEmpty {
            return "Enter your password."
        }

        return nil
    }

    func sync(appState: AppState) {
        savedServerURLStrings = appState.savedServerURLStrings

        if workspaceURL.isEmpty {
            workspaceURL = appState.serverURLString
        }

        if appState.phase == .unauthenticated,
           appState.apiClient != nil,
           appState.serverURLString.isEmpty == false {
            validatedWorkspaceURLString = appState.serverURLString
        }
    }

    func clearWorkspaceErrorAndInvalidateAccountIfNeeded() {
        workspaceErrorMessage = nil

        if workspaceURL != validatedWorkspaceURLString {
            validatedWorkspaceURLString = nil
            errorMessage = nil
            password = ""
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func editWorkspace() {
        validatedWorkspaceURLString = nil
        workspaceErrorMessage = nil
        errorMessage = nil
        password = ""
    }

    func validateWorkspace(appState: AppState) async {
        guard canValidateWorkspace else { return }
        isValidatingWorkspace = true
        workspaceErrorMessage = nil
        defer { isValidatingWorkspace = false }

        do {
            try await appState.validateAndSaveServerURL(workspaceURL)
            workspaceURL = appState.serverURLString
            validatedWorkspaceURLString = appState.serverURLString
            savedServerURLStrings = appState.savedServerURLStrings
            errorMessage = nil
        } catch {
            validatedWorkspaceURLString = nil
            workspaceErrorMessage = error.localizedDescription
        }
    }

    func selectSavedServer(_ serverURLString: String, appState: AppState) async {
        workspaceURL = serverURLString
        await validateWorkspace(appState: appState)
    }

    func login(appState: AppState) async {
        guard canSubmit else { return }
        isLoggingIn = true
        errorMessage = nil
        defer { isLoggingIn = false }

        do {
            try await appState.login(email: trimmedEmail, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
