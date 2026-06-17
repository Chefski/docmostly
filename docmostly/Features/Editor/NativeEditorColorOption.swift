import SwiftUI

struct NativeEditorColorOption: Identifiable, Hashable {
    let name: String
    let hex: String
    let colorName: String?

    var id: String {
        hex
    }

    var color: Color {
        Color(docmostlyHex: hex) ?? .secondary
    }

    static let highlights: [NativeEditorColorOption] = [
        NativeEditorColorOption(name: "Yellow", hex: "#FEF3C7", colorName: "yellow"),
        NativeEditorColorOption(name: "Green", hex: "#DCFCE7", colorName: "green"),
        NativeEditorColorOption(name: "Blue", hex: "#DBEAFE", colorName: "blue"),
        NativeEditorColorOption(name: "Red", hex: "#FEE2E2", colorName: "red")
    ]

    static let textColors: [NativeEditorColorOption] = [
        NativeEditorColorOption(name: "Black", hex: "#111827", colorName: "black"),
        NativeEditorColorOption(name: "Gray", hex: "#6B7280", colorName: "gray"),
        NativeEditorColorOption(name: "Blue", hex: "#2563EB", colorName: "blue"),
        NativeEditorColorOption(name: "Red", hex: "#DC2626", colorName: "red")
    ]
}
