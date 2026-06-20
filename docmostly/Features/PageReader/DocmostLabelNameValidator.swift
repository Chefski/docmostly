import Foundation

nonisolated enum DocmostLabelNameValidator {
    static let maxLength = 100

    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: "-")
            .lowercased()
    }

    static func validationMessage(for normalizedName: String, existingLabels: [DocmostLabel]) -> String? {
        guard normalizedName.isEmpty == false else {
            return "Enter a label name."
        }

        guard normalizedName.count <= maxLength else {
            return "Labels must be 100 characters or fewer."
        }

        guard isValidPattern(normalizedName) else {
            return "Use lowercase letters, numbers, hyphens, underscores, and tildes. Labels cannot start with a tilde."
        }

        if existingLabels.contains(where: { $0.name == normalizedName }) {
            return "This label is already applied."
        }

        return nil
    }

    static func isValidPattern(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first else { return false }
        guard isAllowedFirstScalar(first) else { return false }

        return value.unicodeScalars.allSatisfy(isAllowedScalar)
    }

    private static func isAllowedFirstScalar(_ scalar: Unicode.Scalar) -> Bool {
        isLowercaseLetter(scalar) || isNumber(scalar) || scalar == "-" || scalar == "_"
    }

    private static func isAllowedScalar(_ scalar: Unicode.Scalar) -> Bool {
        isAllowedFirstScalar(scalar) || scalar == "~"
    }

    private static func isLowercaseLetter(_ scalar: Unicode.Scalar) -> Bool {
        (97...122).contains(Int(scalar.value))
    }

    private static func isNumber(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(Int(scalar.value))
    }
}
