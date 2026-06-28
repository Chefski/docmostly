import AppKit
import SwiftData
import SwiftUI

@MainActor
final class MacSettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: MacSettingsWindowController?

    static func show(
        tab: MacSettingsTab = .workspace,
        appState: AppState,
        modelContainer: ModelContainer
    ) {
        MacSettingsNavigation.shared.selectedTab = tab

        if shared == nil {
            shared = MacSettingsWindowController(
                appState: appState,
                modelContainer: modelContainer
            )
        }

        shared?.showWindow(nil)
    }

    private init(appState: AppState, modelContainer: ModelContainer) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 720, height: 540)),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .miniaturizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        configureWindow(appState: appState, modelContainer: modelContainer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        Self.shared = nil
    }

    private func configureWindow(appState: AppState, modelContainer: ModelContainer) {
        guard let window else { return }

        window.title = "Settings"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .automatic
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("DocmostlySettingsWindow")
        window.minSize = NSSize(width: 640, height: 460)
        window.center()
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: MacSettingsView()
                .environment(appState)
                .modelContainer(modelContainer)
        )
    }
}
