import Foundation

struct PageBrowserTaskKey: Hashable {
    let spaceID: String
    let scope: PageBrowserScope
    let pageDiscoveryRevision: Int
    let favoriteRevision: Int
    let initializedSpaceID: String?
}
