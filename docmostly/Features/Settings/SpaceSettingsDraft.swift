import Foundation

nonisolated struct SpaceSettingsDraft: Equatable, Sendable {
    var name: String
    var slug: String
    var description: String
    var disablePublicSharing: Bool
    var allowViewerComments: Bool
    private var isSlugManuallyEdited: Bool

    init() {
        name = ""
        slug = ""
        description = ""
        disablePublicSharing = false
        allowViewerComments = false
        isSlugManuallyEdited = false
    }

    init(space: DocmostSpace) {
        name = space.name
        slug = space.slug
        description = space.description ?? ""
        disablePublicSharing = space.settings?.sharing?.disabled ?? false
        allowViewerComments = space.settings?.comments?.allowViewerComments ?? false
        isSlugManuallyEdited = true
    }

    static func computedSlug(from name: String) -> String {
        let alphanumericName = String(name.filter { character in
            character.isASCIIAlphaNumeric || character.isWhitespace
        })

        if alphanumericName.contains(where: \.isWhitespace) {
            return alphanumericName
                .split(whereSeparator: \.isWhitespace)
                .compactMap(\.first)
                .map(String.init)
                .joined()
                .uppercased()
        }

        return alphanumericName.lowercased()
    }

    var validationMessage: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.count < 2 {
            return "Space name must be at least 2 characters."
        }
        if trimmedName.count > 100 {
            return "Space name must be 100 characters or fewer."
        }
        if trimmedSlug.count < 2 {
            return "Space slug must be at least 2 characters."
        }
        if trimmedSlug.count > 100 {
            return "Space slug must be 100 characters or fewer."
        }
        if trimmedSlug.allSatisfy({ $0.isASCIIAlphaNumeric }) == false {
            return "Space slug must be alphanumeric."
        }
        if description.count > 500 {
            return "Space description must be 500 characters or fewer."
        }
        return nil
    }

    var canCreate: Bool {
        validationMessage == nil
    }

    var createName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var createSlug: String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var createDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    mutating func setName(_ value: String) {
        let previousGeneratedSlug = Self.computedSlug(from: name)
        let shouldUpdateSlug = isSlugManuallyEdited == false && (slug.isEmpty || slug == previousGeneratedSlug)
        name = value
        if shouldUpdateSlug {
            slug = Self.computedSlug(from: value)
        } else if slug != previousGeneratedSlug {
            isSlugManuallyEdited = true
        }
    }

    mutating func setSlug(_ value: String) {
        slug = value
        isSlugManuallyEdited = true
    }

    func hasChanges(comparedTo space: DocmostSpace) -> Bool {
        updateValues(comparedTo: space).hasChanges
    }

    func updateValues(comparedTo space: DocmostSpace) -> SpaceUpdate {
        let original = SpaceSettingsDraft(space: space)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return SpaceUpdate(
            name: trimmedName == original.name ? nil : trimmedName,
            description: trimmedDescription == original.description ? nil : trimmedDescription,
            slug: trimmedSlug == original.slug ? nil : trimmedSlug,
            disablePublicSharing: disablePublicSharing == original.disablePublicSharing ? nil : disablePublicSharing,
            allowViewerComments: allowViewerComments == original.allowViewerComments ? nil : allowViewerComments
        )
    }
}

nonisolated private extension Character {
    var isASCIIAlphaNumeric: Bool {
        guard let scalar = unicodeScalars.first, unicodeScalars.dropFirst().isEmpty else { return false }
        return scalar.isASCIIAlphaNumeric
    }
}

nonisolated private extension Unicode.Scalar {
    var isASCIIAlphaNumeric: Bool {
        (65...90).contains(value) || (97...122).contains(value) || (48...57).contains(value)
    }
}
