import Foundation

enum PageSlugBuilder {
    static func slug(slugId: String, title: String) -> String {
        let prefix = title
            .lowercased()
            .unicodeScalars
            .map { scalar in
                CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
            }
            .reduce(into: "") { partialResult, character in
                if character == "-", partialResult.last == "-" {
                    return
                }
                partialResult.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let safePrefix = prefix.isEmpty ? "untitled" : String(prefix.prefix(70))
        return "\(safePrefix)-\(slugId)"
    }
}
