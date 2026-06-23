import Testing
@testable import docmostly

@MainActor
struct LoginViewModelTests {
    @Test func canSubmitRequiresValidatedWorkspaceEmailAndPassword() {
        let viewModel = LoginViewModel()

        #expect(viewModel.canSubmit == false)
        #expect(viewModel.workspaceSubmitHint == "Enter your workspace URL.")

        viewModel.workspaceURL = "https://docs.example.com"
        viewModel.validatedWorkspaceURLString = "https://docs.example.com"
        #expect(viewModel.submitHint == "Enter your email address.")

        viewModel.email = " chef@example.com "
        #expect(viewModel.canSubmit == false)
        #expect(viewModel.submitHint == "Enter your password.")

        viewModel.password = "secret"
        #expect(viewModel.canSubmit)
        #expect(viewModel.trimmedEmail == "chef@example.com")
        #expect(viewModel.submitHint == nil)
    }

    @Test func editingWorkspaceHidesAccountUntilValidationSucceedsAgain() {
        let viewModel = LoginViewModel()
        viewModel.workspaceURL = "https://docs.example.com"
        viewModel.validatedWorkspaceURLString = "https://docs.example.com"
        viewModel.password = "secret"

        viewModel.workspaceURL = "https://notes.example.com"
        viewModel.clearWorkspaceErrorAndInvalidateAccountIfNeeded()

        #expect(viewModel.canShowAccount == false)
        #expect(viewModel.password.isEmpty)
    }

    @Test func serverDisplayPrefersHostWithFullURLSubtitle() {
        #expect(LoginServerDisplay.title(for: "https://docs.example.com") == "docs.example.com")
        #expect(LoginServerDisplay.subtitle(for: "https://docs.example.com") == "https://docs.example.com")
    }
}
