import Foundation

nonisolated struct SpaceUpdate: Equatable, Sendable {
    let name: String?
    let description: String?
    let slug: String?
    let disablePublicSharing: Bool?
    let allowViewerComments: Bool?

    var hasChanges: Bool {
        name != nil ||
        description != nil ||
        slug != nil ||
        disablePublicSharing != nil ||
        allowViewerComments != nil
    }
}
