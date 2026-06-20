import Foundation

struct PageCreationRequest: Identifiable {
    let id = UUID()
    let parent: PageTreeNode?
    let spaceName: String

    var parentPageId: String? {
        parent?.id
    }

    var destinationName: String {
        parent?.title ?? spaceName
    }
}
