import Foundation

extension NativeEditorMarkdownParser {
    static func proseMirrorAttrName(fromDocmostDataAttributeName name: String) -> String {
        let parts = name.split(separator: "-", omittingEmptySubsequences: true)
        guard let first = parts.first else { return name }

        return parts.dropFirst().reduce(String(first)) { result, part in
            result + part.prefix(1).uppercased() + part.dropFirst()
        }
    }

    static func docmostDataAttributeName(fromProseMirrorAttrName name: String) -> String {
        name.reduce(into: "") { result, character in
            if character.isUppercase {
                if result.isEmpty == false {
                    result.append("-")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
