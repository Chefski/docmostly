import Foundation

nonisolated struct DocumentCompactionPolicy: Equatable, Sendable {
    static let production = DocumentCompactionPolicy(updateCount: 100, byteCount: 1_000_000)

    let updateCount: Int
    let byteCount: Int

    func shouldCompact(_ metrics: DocumentStoreMetrics) -> Bool {
        metrics.uncompactedUpdateCount >= updateCount || metrics.uncompactedByteCount >= byteCount
    }
}

protocol DocumentCompactionFaultInjector: Sendable {
    func beforeCompactionCommit() async throws
}
