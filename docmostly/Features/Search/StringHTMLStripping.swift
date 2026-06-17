import Foundation

extension String {
    func removingHTMLTags() -> String {
        var output = ""
        var isInsideTag = false

        for character in self {
            if character == "<" {
                isInsideTag = true
                continue
            }

            if character == ">" {
                isInsideTag = false
                continue
            }

            if isInsideTag == false {
                output.append(character)
            }
        }

        return output
    }
}
