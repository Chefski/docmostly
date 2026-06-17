import SwiftUI

extension Color {
    init?(docmostlyHex value: String) {
        var hex = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard hex.count == 6, let rawValue = Int(hex, radix: 16) else {
            return nil
        }

        let red = Double((rawValue >> 16) & 0xff) / 255.0
        let green = Double((rawValue >> 8) & 0xff) / 255.0
        let blue = Double(rawValue & 0xff) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
