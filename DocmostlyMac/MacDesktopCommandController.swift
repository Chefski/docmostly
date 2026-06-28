import Foundation
import Observation

@MainActor
@Observable
final class MacDesktopCommandController {
    var isCommandPalettePresented = false
    var isPageCreationPresented = false
    var sidebarReloadRequestID = UUID()

    func presentCommandPalette() {
        isCommandPalettePresented = true
    }

    func presentPageCreation() {
        isPageCreationPresented = true
    }

    func requestSidebarReload() {
        sidebarReloadRequestID = UUID()
    }
}
