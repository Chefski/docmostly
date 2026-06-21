import Foundation

nonisolated enum NativeEditorTextAlignment: String, Equatable, Sendable {
    case left
    case center
    case right
    case justify

    init(attrs: [String: ProseMirrorJSONValue]?) {
        let value = attrs?["textAlign"]?.stringValue ?? Self.left.rawValue
        self = Self(rawValue: value) ?? .left
    }

    var proseMirrorValue: ProseMirrorJSONValue? {
        self == .left ? nil : .string(rawValue)
    }
}
