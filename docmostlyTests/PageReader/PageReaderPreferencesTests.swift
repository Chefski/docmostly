import Testing
@testable import docmostly

struct PageReaderPreferencesTests {
    @Test func defaultsToEditingWithConstrainedWidthAndToolbar() {
        let preferences = PageReaderPreferences(nil)

        #expect(preferences.defaultMode == .edit)
        #expect(preferences.usesFullWidth == false)
        #expect(preferences.showsEditorToolbar)
    }

    @Test func appliesReadModeAndLayoutPreferences() {
        let preferences = PageReaderPreferences(DocmostUserPreferences(
            fullPageWidth: true,
            pageEditMode: "read",
            editorToolbar: false
        ))

        #expect(preferences.defaultMode == .read)
        #expect(preferences.usesFullWidth)
        #expect(preferences.showsEditorToolbar == false)
    }

    @Test func treatsUnknownPageModeAsEdit() {
        let preferences = PageReaderPreferences(DocmostUserPreferences(
            fullPageWidth: nil,
            pageEditMode: "unexpected",
            editorToolbar: nil
        ))

        #expect(preferences.defaultMode == .edit)
    }
}
