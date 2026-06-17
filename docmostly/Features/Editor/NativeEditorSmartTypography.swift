import Foundation

enum NativeEditorSmartTypography {
    static func transform(_ text: String) -> String {
        text.replacing("...", with: "…")
            .replacing(" -> ", with: " → ")
            .replacing(" <- ", with: " ← ")
            .replacing(" -- ", with: " – ")
            .replacing("(c)", with: "©")
            .replacing("(r)", with: "®")
    }
}
