import Foundation

extension AppState {
    func loadCachedPageTree(spaceId: String) async -> [DocmostPage] {
        guard let cacheScope else { return [] }

        if let cacheReader {
            return (try? await cacheReader.loadEntirePageTree(spaceId: spaceId, scope: cacheScope)) ?? []
        }
        return (try? cacheRepository?.loadEntirePageTree(spaceId: spaceId, scope: cacheScope)) ?? []
    }
}
