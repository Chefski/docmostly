import Foundation

struct MacCommandPaletteItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let systemImage: String
    let keywords: [String]
    let isEnabled: Bool
    let action: @MainActor () -> Void

    init(
        id: String? = nil,
        title: String,
        subtitle: String?,
        systemImage: String,
        keywords: [String] = [],
        isEnabled: Bool = true,
        action: @escaping @MainActor () -> Void
    ) {
        self.id = id ?? [title, subtitle, systemImage].compactMap(\.self).joined(separator: "|")
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.keywords = keywords
        self.isEnabled = isEnabled
        self.action = action
    }

    func matches(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return true }

        if title.localizedStandardContains(trimmedQuery) {
            return true
        }

        if subtitle?.localizedStandardContains(trimmedQuery) == true {
            return true
        }

        return keywords.contains { keyword in
            keyword.localizedStandardContains(trimmedQuery)
        }
    }
}
