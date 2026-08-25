#if os(macOS)
import AppKit

@MainActor
final class NativeEditorNSTextView: NSTextView {
    var requestsFirstResponder = false
    var renderedRemotePresenceSegments: [NativeEditorRemotePresenceSegment] = []
    var remotePresenceHighlightRanges: [NSRange] = []
    var remotePresenceOverlayViews: [NSView] = []
    var remotePresenceRenderingIsInvalid = true

    override func layout() {
        super.layout()
        layoutRemotePresenceOverlays()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestFirstResponderIfPossible()
    }

    func requestFirstResponderIfPossible() {
        guard
            requestsFirstResponder,
            let window,
            window.firstResponder !== self
        else {
            return
        }
        window.makeFirstResponder(self)
    }
}
#endif
