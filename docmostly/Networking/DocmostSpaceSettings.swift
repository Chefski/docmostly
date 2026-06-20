import Foundation

nonisolated struct DocmostSpaceSettings: Decodable, Hashable, Sendable {
    let sharing: DocmostSpaceSharingSettings?
    let comments: DocmostSpaceCommentsSettings?
}

nonisolated struct DocmostSpaceSharingSettings: Decodable, Hashable, Sendable {
    let disabled: Bool?
}

nonisolated struct DocmostSpaceCommentsSettings: Decodable, Hashable, Sendable {
    let allowViewerComments: Bool?
}
