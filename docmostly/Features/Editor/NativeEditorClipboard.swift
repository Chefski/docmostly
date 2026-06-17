import Foundation

#if canImport(UIKit)
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
