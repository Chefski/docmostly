import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class MacDesktopCommandController {
    var sidebarReloadRequestID = UUID()
    var spaceSettingsPresentationRequestID: UUID?

    func requestSidebarReload() {
        sidebarReloadRequestID = UUID()
    }

    func requestSpaceSettingsPresentation() {
        spaceSettingsPresentationRequestID = UUID()
    }

    func clearSpaceSettingsPresentationRequest() {
        spaceSettingsPresentationRequestID = nil
    }
}

struct MacDesktopCommandActions {
    let canCreatePage: () -> Bool
    let selectedPageRoute: () -> MacPageWindowRoute?
    let presentCommandPalette: () -> Void
    let presentPageCreation: () -> Void
    let presentSpaceSettings: () -> Void
    let selectSidebarDestination: (SidebarDestination) -> Void
    let openSelectedPageInNewWindow: () -> Void
}

private struct MacDesktopCommandActionsKey: FocusedValueKey {
    typealias Value = MacDesktopCommandActions
}

private struct MacFocusedPageRouteKey: FocusedValueKey {
    typealias Value = MacPageWindowRoute
}

extension FocusedValues {
    var macDesktopCommandActions: MacDesktopCommandActions? {
        get { self[MacDesktopCommandActionsKey.self] }
        set { self[MacDesktopCommandActionsKey.self] = newValue }
    }

    var macFocusedPageRoute: MacPageWindowRoute? {
        get { self[MacFocusedPageRouteKey.self] }
        set { self[MacFocusedPageRouteKey.self] = newValue }
    }
}
