nonisolated struct PageTreeNavigationState: Equatable, Sendable {
    var spaceSettingsSpaceID: String?

    mutating func showSpaceSettings(spaceID: String) {
        spaceSettingsSpaceID = spaceID
    }
}
