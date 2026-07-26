import SwiftUI
import Testing
@testable import docmostly

struct NativeEditorTextAlignmentTests {
    @Test func mapsDocumentAlignmentToReadModeTextAlignment() {
        #expect(NativeEditorTextAlignment.left.swiftUITextAlignment == .leading)
        #expect(NativeEditorTextAlignment.center.swiftUITextAlignment == .center)
        #expect(NativeEditorTextAlignment.right.swiftUITextAlignment == .trailing)
        #expect(NativeEditorTextAlignment.justify.swiftUITextAlignment == .leading)
    }

    @Test func mapsDocumentAlignmentToReadModeFrameAlignment() {
        #expect(NativeEditorTextAlignment.left.swiftUIFrameAlignment == .leading)
        #expect(NativeEditorTextAlignment.center.swiftUIFrameAlignment == .center)
        #expect(NativeEditorTextAlignment.right.swiftUIFrameAlignment == .trailing)
        #expect(NativeEditorTextAlignment.justify.swiftUIFrameAlignment == .leading)
    }
}
