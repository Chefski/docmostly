import Foundation

nonisolated struct PageReaderPreferences: Equatable, Sendable {
    let defaultMode: PageReaderMode
    let usesFullWidth: Bool
    let showsEditorToolbar: Bool

    init(_ preferences: DocmostUserPreferences?) {
        defaultMode = preferences?.pageEditMode == PageReaderMode.read.rawValue ? .read : .edit
        usesFullWidth = preferences?.fullPageWidth ?? false
        showsEditorToolbar = preferences?.editorToolbar ?? true
    }
}
