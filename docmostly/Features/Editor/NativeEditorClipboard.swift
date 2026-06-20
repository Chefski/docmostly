import Foundation

#if canImport(AppKit)
import AppKit

@MainActor
enum NativeEditorClipboard {
    static func write(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
#elseif canImport(UIKit)
import UIKit

@MainActor
enum NativeEditorClipboard {
    static func write(_ text: String) {
        UIPasteboard.general.string = text
    }
}
#else
@MainActor
enum NativeEditorClipboard {
    static func write(_ text: String) {}
}
#endif
