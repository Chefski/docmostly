import Foundation

struct NativeEditorSearchMatch: Equatable, Identifiable, Sendable {
    var blockID: UUID
    var blockIndex: Int
    var lowerBound: Int
    var upperBound: Int
    var preview: String

    var id: String {
        "\(blockID.uuidString)-\(lowerBound)-\(upperBound)"
    }
}
