import Foundation
import Observation

@MainActor
@Observable
final class ServerSetupViewModel {
    var serverURL: String
    var isValidating = false
    var errorMessage: String?

    init(serverURL: String = AppConfig.defaultServerURLString) {
        self.serverURL = serverURL
    }

    func validate(appState: AppState) async {
        isValidating = true
        errorMessage = nil
        defer { isValidating = false }

        do {
            try await appState.validateAndSaveServerURL(serverURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
