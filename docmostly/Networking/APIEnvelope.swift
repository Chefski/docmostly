import Foundation

nonisolated struct APIEnvelope<T: Decodable>: Decodable {
    let data: T
    let success: Bool
    let status: Int
}
