import Foundation

nonisolated struct DocmostPageExportFile: Equatable, Sendable {
    let data: Data
    let fileName: String
    let mimeType: String?
}
