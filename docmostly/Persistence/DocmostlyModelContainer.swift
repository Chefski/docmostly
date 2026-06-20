import SwiftData

enum DocmostlyModelContainer {
    static func make(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        let schema = Schema([
            CachedSpace.self,
            CachedPageTreeItem.self,
            CachedPage.self,
            CachedAttachment.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Docmostly model container: \(error)")
        }
    }
}
