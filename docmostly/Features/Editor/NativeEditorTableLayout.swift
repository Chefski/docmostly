import Foundation
import SwiftUI

enum NativeEditorTableLayout {
    static let minimumColumnWidth: CGFloat = 128
    static let defaultColumnWidth: CGFloat = 184
    static let compactColumnWidth: CGFloat = 176
    static let maximumColumnWidth: CGFloat = 480
    static let rowMinimumHeight: CGFloat = 48
    static let columnHandleHeight: CGFloat = 28
    static let rowHandleWidth: CGFloat = 30
    static let resizeHandleWidth: CGFloat = 14
    static let cellHorizontalPadding: CGFloat = 10
    static let cellVerticalPadding: CGFloat = 8

    static var borderStyle: Color {
        Color.secondary.opacity(0.24)
    }

    static func columnWidth(for table: NativeEditorTable, columnIndex: Int, isCompactWidth: Bool) -> CGFloat {
        if let storedWidth = table.columnWidth(at: columnIndex) {
            return min(max(CGFloat(storedWidth), minimumColumnWidth), maximumColumnWidth)
        }

        return isCompactWidth ? compactColumnWidth : defaultColumnWidth
    }

    static func cellBackground(for cell: NativeEditorTableCell) -> Color {
        if let backgroundColor = cell.backgroundColor,
           let cssBackground = cssBackgroundColor(from: backgroundColor) {
            return cssBackground
        }

        if let backgroundColorName = cell.backgroundColorName,
           let namedBackground = backgroundColor(for: backgroundColorName) {
            return namedBackground
        }

        return cell.isHeader ? Color.secondary.opacity(0.12) : Color.clear
    }

    private static func cssBackgroundColor(from value: String) -> Color? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let hexColor = Color(docmostlyHex: trimmedValue) {
            return hexColor
        }

        let lowercasedValue = trimmedValue.lowercased()
        guard lowercasedValue.hasPrefix("rgb(") || lowercasedValue.hasPrefix("rgba("),
              let openParen = trimmedValue.firstIndex(of: "("),
              let closeParen = trimmedValue.lastIndex(of: ")") else {
            return nil
        }

        let components = trimmedValue[trimmedValue.index(after: openParen)..<closeParen]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard components.count >= 3,
              let red = cssColorComponent(from: components[0]),
              let green = cssColorComponent(from: components[1]),
              let blue = cssColorComponent(from: components[2]) else {
            return nil
        }

        let opacity = components.indices.contains(3) ? cssAlphaComponent(from: components[3]) ?? 1 : 1
        return Color(
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            opacity: opacity
        )
    }

    private static func cssColorComponent(from value: String) -> Double? {
        guard let component = Double(value) else { return nil }
        return min(max(component, 0), 255)
    }

    private static func cssAlphaComponent(from value: String) -> Double? {
        if value.hasSuffix("%") {
            let percentageText = value.dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
            guard let percentage = Double(percentageText) else { return nil }
            return min(max(percentage / 100, 0), 1)
        }

        guard let alpha = Double(value) else { return nil }
        return min(max(alpha, 0), 1)
    }

    private static func backgroundColor(for name: String) -> Color? {
        switch name.lowercased() {
        case "blue":
            Color.blue.opacity(0.16)
        case "green":
            Color.green.opacity(0.16)
        case "yellow":
            Color.yellow.opacity(0.22)
        case "red":
            Color.red.opacity(0.16)
        case "pink":
            Color.pink.opacity(0.16)
        case "purple":
            Color.purple.opacity(0.16)
        case "gray", "grey":
            Color.secondary.opacity(0.10)
        default:
            nil
        }
    }
}
