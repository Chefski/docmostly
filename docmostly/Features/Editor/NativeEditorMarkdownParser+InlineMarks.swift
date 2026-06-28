import Foundation

extension NativeEditorMarkdownParser {
    static func inlineRunMarkdown(from run: AttributedString.Runs.Run, text: String) -> String {
        var output = text
        let intent = run.inlinePresentationIntent ?? []

        if intent.contains(.code) {
            output = codeMarkdown(from: output)
        } else {
            if intent.contains(.stronglyEmphasized) {
                output = "**\(output)**"
            }

            if intent.contains(.emphasized) {
                output = "*\(output)*"
            }

            if intent.contains(.strikethrough) {
                output = "~~\(output)~~"
            }
        }

        if let href = run.link?.absoluteString {
            output = "[\(escapedMarkdownLinkLabel(output))](\(href))"
        }

        return output
    }

    private static func codeMarkdown(from text: String) -> String {
        let delimiter = text.contains("`") ? "``" : "`"
        return "\(delimiter)\(text)\(delimiter)"
    }

    private static func escapedMarkdownLinkLabel(_ text: String) -> String {
        text
            .replacing("\\", with: "\\\\")
            .replacing("[", with: "\\[")
            .replacing("]", with: "\\]")
    }
}
