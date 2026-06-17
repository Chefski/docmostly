import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var isLoggingIn = false
    var errorMessage: String?

    var canSubmit: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && password.isEmpty == false
    }

    func login(appState: AppState) async {
        guard canSubmit else { return }
        isLoggingIn = true
        errorMessage = nil
        defer { isLoggingIn = false }

        do {
            try await appState.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
